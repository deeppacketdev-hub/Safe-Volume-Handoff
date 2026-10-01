import AppKit
import AVFoundation
import Foundation
import Observation

@Observable
@MainActor
final class MacAudioPlayer {
    static let shared = MacAudioPlayer()
    
    private(set) var isPlaying: Bool = false
    private(set) var volume: Float = 0.5
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var fadeTask: Task<Void, Never>?
    
    private init() {
        // Default initial volume
        self.volume = 0.5
    }
    
    /// Play a track preview URL with Safe Fade-In
    func play(url: URL, targetVolume: Float, fadeInDuration: Double) {
        fadeTask?.cancel()
        stop()
        
        let clampedTarget = max(0, min(1, targetVolume))
        
        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: playerItem)
        
        // Start muted for instant Safe Volume Protection
        newPlayer.volume = 0
        self.volume = 0
        self.player = newPlayer
        
        // Periodic time observer
        timeObserver = newPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.25, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                guard let self else { return }
                self.currentTime = time.seconds
                if let dur = self.player?.currentItem?.duration.seconds, !dur.isNaN && dur > 0 {
                    self.duration = dur
                }
            }
        }
        
        // End of track observer
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
                self?.currentTime = 0
            }
        }
        
        newPlayer.play()
        self.isPlaying = true
        
        // Execute smooth local fade-in
        if fadeInDuration > 0 {
            startFadeIn(to: clampedTarget, duration: fadeInDuration)
        } else {
            setVolume(clampedTarget)
        }
    }
    
    /// Smooth hardware/software level fade-in on Mac
    private func startFadeIn(to target: Float, duration: Double) {
        fadeTask?.cancel()
        
        let steps = max(10, Int(duration * 25)) // 25 steps per second
        let intervalNs = UInt64((duration / Double(steps)) * 1_000_000_000)
        let stepDelta = target / Float(steps)
        
        fadeTask = Task { @MainActor in
            for step in 1...steps {
                guard !Task.isCancelled else { break }
                let current = min(target, stepDelta * Float(step))
                self.setVolume(current)
                try? await Task.sleep(nanoseconds: intervalNs)
            }
            self.setVolume(target)
        }
    }
    
    func setVolume(_ newVolume: Float) {
        let clamped = max(0, min(1, newVolume))
        self.volume = clamped
        player?.volume = clamped
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func resume() {
        player?.play()
        isPlaying = true
    }
    
    func togglePlayPause() {
        if isPlaying {
            pause()
        } else {
            resume()
        }
    }
    
    func stop() {
        fadeTask?.cancel()
        fadeTask = nil
        
        player?.pause()
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        
        timeObserver = nil
        endObserver = nil
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
    }
}
