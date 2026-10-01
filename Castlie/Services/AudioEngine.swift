import AVFoundation
import MediaPlayer
import Observation

@Observable
@MainActor
class AudioEngine {
    static let shared = AudioEngine()
    
    // MARK: - State
    private(set) var isPlaying = false
    private(set) var currentTrack: Track?
    private(set) var currentTime: Double = 0       // Поточна позиція в секундах
    private(set) var duration: Double = 0           // Тривалість в секундах
    private(set) var volume: Float = 0.5            // Поточна гучність 0.0 - 1.0
    
    var queue: [Track] = []                         // Черга треків
    private(set) var currentIndex: Int = 0
    
    // MARK: - Private
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    
    private init() {
        setupAudioSession()
    }
    
    // MARK: - Audio Session Setup
    
    /// Налаштування аудіо-сесії — ОБОВ'ЯЗКОВО для відтворення через зовнішні пристрої
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // .playback — звук грає навіть коли екран заблокований
            // та правильно маршрутизується на AirPlay/Bluetooth
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("AudioSession setup error: \(error)")
        }
    }
    
    // MARK: - Playback Controls
    
    /// Почати відтворення треку
    func play(track: Track) {
        guard let previewURL = track.previewURL else {
            print("No preview URL for track: \(track.name)")
            return
        }
        
        // Зупиняємо попередній трек
        stop()
        
        currentTrack = track
        let playerItem = AVPlayerItem(url: previewURL)
        player = AVPlayer(playerItem: playerItem)
        player?.volume = volume
        
        // Підписка на закінчення треку
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.playNext()
            }
        }
        
        // Підписка на оновлення прогресу (кожні 0.1 секунди)
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
                if let duration = self?.player?.currentItem?.duration.seconds,
                   !duration.isNaN {
                    self?.duration = duration
                }
            }
        }
        
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    /// Відтворити список треків починаючи з індексу
    func play(tracks: [Track], startIndex: Int = 0) {
        queue = tracks
        currentIndex = startIndex
        if startIndex < tracks.count {
            play(track: tracks[startIndex])
        }
    }
    
    /// Пауза / Продовження
    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    /// Зупинити відтворення повністю
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
    
    /// Наступний трек
    func playNext() {
        guard !queue.isEmpty else { return }
        currentIndex = (currentIndex + 1) % queue.count
        play(track: queue[currentIndex])
    }
    
    /// Попередній трек
    func playPrevious() {
        guard !queue.isEmpty else { return }
        // Якщо пройшло більше 3 секунд — перемотати на початок
        if currentTime > 3 {
            seek(to: 0)
        } else {
            currentIndex = (currentIndex - 1 + queue.count) % queue.count
            play(track: queue[currentIndex])
        }
    }
    
    /// Перемотка на позицію (секунди)
    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: time)
    }
    
    /// Встановити гучність (0.0 - 1.0)
    func setVolume(_ newVolume: Float) {
        volume = max(0, min(1, newVolume))
        player?.volume = volume
    }
    
    // MARK: - Now Playing Info (Lock Screen)
    
    /// Оновити інформацію на екрані блокування
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else { return }
        
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = track.name
        info[MPMediaItemPropertyArtist] = track.artistName
        info[MPMediaItemPropertyAlbumTitle] = track.albumName
        info[MPMediaItemPropertyPlaybackDuration] = track.durationSeconds
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    /// Прогрес відтворення (0.0 - 1.0)
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    /// Форматований час "0:15 / 0:30"
    var formattedTime: String {
        let current = formatTime(currentTime)
        let total = formatTime(duration)
        return "\(current) / \(total)"
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
