import AppKit
import AVFoundation
import CoreAudio
import AudioToolbox
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
    
    private init() {
        self.volume = Self.getMacSystemVolume()
    }
    
    /// Отримати поточну реальну системну гучність macOS (0.0 - 1.0)
    static func getMacSystemVolume() -> Float {
        var defaultOutputDeviceID = AudioDeviceID(0)
        var defaultOutputDeviceIDSize = UInt32(MemoryLayout.size(ofValue: defaultOutputDeviceID))
        var getDefaultOutputDevicePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status1 = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &getDefaultOutputDevicePropertyAddress,
            0,
            nil,
            &defaultOutputDeviceIDSize,
            &defaultOutputDeviceID
        )
        if status1 == noErr {
            var volumePropertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )

            var vol: Float32 = 0
            var volSize = UInt32(MemoryLayout.size(ofValue: vol))
            let status2 = AudioObjectGetPropertyData(
                defaultOutputDeviceID,
                &volumePropertyAddress,
                0,
                nil,
                &volSize,
                &vol
            )
            if status2 == noErr {
                return max(0, min(1, Float(vol)))
            }
        }
        
        // Fallback: AppleScript
        let script = NSAppleScript(source: "output volume of (get volume settings)")
        var error: NSDictionary?
        if let result = script?.executeAndReturnError(&error) {
            let val = result.int32Value
            return max(0, min(1, Float(val) / 100.0))
        }
        return 0.5
    }
    
    /// Змінити реальну СИСТЕМНУ гучність macOS (CoreAudio + AppleScript fallback)
    static func setMacSystemVolume(_ volume: Float) {
        let clamped = max(0, min(1, volume))
        
        // 1. Надшвидкий нативний CoreAudio (0 мікросекунд, без затримок)
        var defaultOutputDeviceID = AudioDeviceID(0)
        var defaultOutputDeviceIDSize = UInt32(MemoryLayout.size(ofValue: defaultOutputDeviceID))
        var getDefaultOutputDevicePropertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status1 = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &getDefaultOutputDevicePropertyAddress,
            0,
            nil,
            &defaultOutputDeviceIDSize,
            &defaultOutputDeviceID
        )
        if status1 == noErr {
            var volumePropertyAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
                mScope: kAudioDevicePropertyScopeOutput,
                mElement: kAudioObjectPropertyElementMain
            )

            var vol: Float32 = clamped
            let volSize = UInt32(MemoryLayout.size(ofValue: vol))
            let status2 = AudioObjectSetPropertyData(
                defaultOutputDeviceID,
                &volumePropertyAddress,
                0,
                nil,
                volSize,
                &vol
            )
            if status2 == noErr {
                return
            }
        }
        
        // 2. Fallback через AppleScript якщо пристрій не підтримує VirtualMainVolume
        let intVolume = Int(clamped * 100)
        DispatchQueue.global(qos: .userInteractive).async {
            let script = NSAppleScript(source: "set volume output volume \(intVolume)")
            var error: NSDictionary?
            script?.executeAndReturnError(&error)
            if let error {
                print("[MacAudioPlayer] AppleScript volume error: \(error)")
            }
        }
    }
    
    private var fadeTask: Task<Void, Never>?
    
    func setVolume(_ newVolume: Float) {
        cancelFadeIn()
        let clamped = max(0, min(1, newVolume))
        self.volume = clamped
        player?.volume = 1.0
        Self.setMacSystemVolume(clamped)
    }
    
    /// Відтворення аудіо на Mac із можливим софтверним fade-in під капотом
    func play(url: URL, targetVolume: Float, fadeInDuration: Double = 0) {
        stop()
        
        let clampedTarget = max(0, min(1, targetVolume))
        self.volume = clampedTarget
        
        // Синхронізуємо системну апаратну гучність безпосередньо із заданим рівнем
        Self.setMacSystemVolume(clampedTarget)
        
        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: playerItem)
        
        if fadeInDuration > 0.05 {
            newPlayer.volume = 0.0
            self.player = newPlayer
            startFadeIn(duration: fadeInDuration)
        } else {
            newPlayer.volume = 1.0
            self.player = newPlayer
        }
        
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
                MacReceiverService.shared.notifyTrackEnded()
            }
        }
        
        newPlayer.play()
        self.isPlaying = true
    }
    
    private func startFadeIn(duration: Double) {
        fadeTask?.cancel()
        let steps = max(10, Int(duration * 30))
        let interval = UInt64((duration / Double(steps)) * 1_000_000_000)
        
        fadeTask = Task { @MainActor in
            for step in 1...steps {
                guard !Task.isCancelled else { break }
                let progress = Float(step) / Float(steps)
                self.player?.volume = progress
                try? await Task.sleep(nanoseconds: interval)
            }
            self.player?.volume = 1.0
        }
    }
    
    func cancelFadeIn() {
        fadeTask?.cancel()
        fadeTask = nil
        player?.volume = 1.0
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
    
    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: time)
        currentTime = seconds
    }
    
    func stop() {
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
