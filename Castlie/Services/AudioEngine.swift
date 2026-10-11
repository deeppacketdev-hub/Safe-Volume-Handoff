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
    private(set) var volume: Float = 0.5            // Поточна системна апаратна гучність 0.0 - 1.0
    private(set) var softwareGain: Float = 1.0      // Програмне підсилення для fade-in під капотом
    private(set) var currentAudioURL: URL?          // Поточне активне аудіо-посилання
    
    // MARK: - Shuffle & Repeat
    enum RepeatMode: Int, CaseIterable {
        case off = 0
        case all = 1
        case one = 2
        
        var sfSymbol: String {
            switch self {
            case .off, .all: return "repeat"
            case .one: return "repeat.1"
            }
        }
    }
    
    private(set) var isShuffled: Bool = false
    private(set) var repeatMode: RepeatMode = .off
    
    var queue: [Track] = []                         // Черга треків
    private(set) var currentIndex: Int = 0
    
    // MARK: - Private
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var isReceivingRemoteVolumeUpdate: Bool = false
    private var lastAutoAdvanceTime: Date = .distantPast
    
    private init() {
        setupAudioSession()
        setupRemoteCommandCenter()
        setupInterruptionHandling()
        
        // Ініціалізуємо слухач системної гучності та синхронізуємо початковий рівень
        _ = SystemVolumeController.shared
        self.volume = AVAudioSession.sharedInstance().outputVolume
    }
    
    // MARK: - Audio Session Setup
    
    /// Налаштування аудіо-сесії для безперервного фонового відтворення (Lock Screen, AirPlay, Mac, Bluetooth)
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, policy: .longFormAudio)
            try session.setActive(true)
        } catch {
            print("AudioSession setup error: \(error)")
        }
    }
    
    /// Обробка дзвінків, переривань та відключення навушників
    private func setupInterruptionHandling() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else { return }
            
            let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt
            
            Task { @MainActor in
                guard let self else { return }
                switch type {
                case .began:
                    if self.isPlaying {
                        self.player?.pause()
                        self.isPlaying = false
                        self.updateNowPlayingInfo()
                    }
                case .ended:
                    if let optionsValue {
                        let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                        if options.contains(.shouldResume) {
                            try? AVAudioSession.sharedInstance().setActive(true)
                            self.player?.play()
                            self.isPlaying = true
                            self.updateNowPlayingInfo()
                        }
                    }
                @unknown default:
                    break
                }
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let userInfo = notification.userInfo,
                  let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else { return }
            
            // Якщо навушники або колонка відключились — ставимо на паузу, щоб не грати раптово з динаміка
            if reason == .oldDeviceUnavailable {
                Task { @MainActor in
                    if self?.isPlaying == true {
                        self?.togglePlayPause()
                    }
                }
            }
        }
    }
    
    /// Налаштування системних команд (екран блокування, Dynamic Island, навушники, Mac)
    private func setupRemoteCommandCenter() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                if self?.isPlaying == false {
                    self?.togglePlayPause()
                }
            }
            return .success
        }
        
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                if self?.isPlaying == true {
                    self?.togglePlayPause()
                }
            }
            return .success
        }
        
        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.togglePlayPause()
            }
            return .success
        }
        
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.playNext()
            }
            return .success
        }
        
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.playPrevious()
            }
            return .success
        }
        
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in
                self?.seek(to: event.positionTime)
            }
            return .success
        }
        
        UIApplication.shared.beginReceivingRemoteControlEvents()
    }
    
    // MARK: - Audio Preview Resolver
    
    private var previewCache: [String: URL] = [:]
    private var playTask: Task<Void, Never>?
    
    /// Автоматичний пошук офіційного 30-секундного прев'ю саме цієї пісні та виконавця
    func resolveAudioURL(for track: Track) async -> URL? {
        // 1. Кеш
        if let cached = previewCache[track.id] {
            return cached
        }
        
        // 2. Якщо вже є прямий previewURL від Spotify
        if let existing = track.previewURL, !existing.absoluteString.contains("soundhelix") {
            previewCache[track.id] = existing
            return existing
        }
        
        // 3. Apple iTunes Search API (офіційні 30-секундні прев'ю від Apple Music / iTunes CDN)
        let query = "\(track.artistName) \(track.name)"
        if let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let itunesURL = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=song&limit=1") {
            do {
                var request = URLRequest(url: itunesURL)
                request.timeoutInterval = 4
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    struct ITunesResult: Codable {
                        let previewUrl: String?
                    }
                    struct ITunesResponse: Codable {
                        let results: [ITunesResult]
                    }
                    let res = try JSONDecoder().decode(ITunesResponse.self, from: data)
                    if let first = res.results.first?.previewUrl, let url = URL(string: first) {
                        previewCache[track.id] = url
                        return url
                    }
                }
            } catch {
                // Fallback до Deezer
            }
        }
        
        // 4. Deezer Search API (офіційні 30-секундні MP3 прев'ю)
        let cleanQuery = "\(track.artistName) \(track.name)"
        if let cleanEncoded = cleanQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let deezerURL = URL(string: "https://api.deezer.com/search?q=\(cleanEncoded)&limit=1") {
            do {
                var request = URLRequest(url: deezerURL)
                request.timeoutInterval = 4
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    struct DeezerItem: Codable {
                        let preview: String?
                    }
                    struct DeezerResponse: Codable {
                        let data: [DeezerItem]?
                    }
                    let res = try JSONDecoder().decode(DeezerResponse.self, from: data)
                    if let preview = res.data?.first?.preview, let url = URL(string: preview) {
                        previewCache[track.id] = url
                        return url
                    }
                }
            } catch {
                // Прев'ю не знайдено
            }
        }
        
        return track.previewURL
    }
    
    // MARK: - Playback Controls
    
    /// Почати відтворення треку
    func play(track: Track) {
        // Зупиняємо попередній таск і трек
        playTask?.cancel()
        stop()
        
        currentTrack = track
        isPlaying = true
        updateNowPlayingInfo()
        loadArtworkForNowPlaying(track: track)
        
        // Запитуємо фоновий час у iOS, щоб додаток не заснув у фоні під час пошуку посилання
        var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
        backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "CastlieResolveAudio") {
            if backgroundTaskId != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTaskId)
                backgroundTaskId = .invalid
            }
        }
        
        playTask = Task { @MainActor [weak self] in
            defer {
                if backgroundTaskId != .invalid {
                    UIApplication.shared.endBackgroundTask(backgroundTaskId)
                    backgroundTaskId = .invalid
                }
            }
            
            guard let self else { return }
            guard let previewURL = await self.resolveAudioURL(for: track) else {
                print("No preview URL found for track: \(track.name)")
                if self.currentTrack?.id == track.id {
                    self.isPlaying = false
                    self.updateNowPlayingInfo()
                }
                return
            }
            
            // Якщо користувач перемкнув трек або таск скасовано
            guard !Task.isCancelled, self.currentTrack?.id == track.id else { return }
            
            // Активація аудіо-сесії перед запуском гравця
            do {
                try AVAudioSession.sharedInstance().setActive(true)
            } catch {
                print("AudioSession activation error: \(error)")
            }
            
            self.currentAudioURL = previewURL
            
            // ПЕРЕВІРКА: Якщо ми підключені до віддаленого Mac (Castlie Connect)
            if let remote = CastlieConnectService.shared.activeRemoteDevice {
                print("[AudioEngine] 📡 Persistent session active: Routing \(track.name) to Mac (\(remote.name))")
                CastlieConnectService.shared.sendHandoff(
                    to: remote.id,
                    track: track,
                    previewURL: previewURL,
                    targetVolume: remote.volume,
                    fadeInDuration: 0 // Системна гучність Mac уже налаштована й синхронізована, без скидання
                )
                // Запускаємо локальний приглушений плеєр (volume = 0)
                // Це дозволяє перехоплювати фізичні кнопки гучності iPhone,
                // синхронізувати таймлайн, скраббер і автоперемикання
                self.setupPlayerItem(url: previewURL, isMutedForRemote: true)
                self.prefetchNextTrack()
                return
            }
            
            // Звичайне локальне відтворення на динаміках iPhone
            self.setupPlayerItem(url: previewURL, isMutedForRemote: false)
            self.prefetchNextTrack()
        }
    }
    
    /// Налаштування AVPlayer для локального або фонового/дистанційного відтворення
    private func setupPlayerItem(url: URL, isMutedForRemote: Bool) {
        // Гарантуємо відсутність витоку спостерігачів від попереднього треку
        if let existingTimeObserver = self.timeObserver {
            self.player?.removeTimeObserver(existingTimeObserver)
            self.timeObserver = nil
        }
        if let existingEndObserver = self.endObserver {
            NotificationCenter.default.removeObserver(existingEndObserver)
            self.endObserver = nil
        }

        let playerItem = AVPlayerItem(url: url)
        let newPlayer = AVPlayer(playerItem: playerItem)
        
        if isMutedForRemote {
            newPlayer.volume = 0.0
            self.softwareGain = 0.0
        } else {
            if SafeVolumeManager.shared.config.isFadeInEnabled {
                newPlayer.volume = 0.0
                self.softwareGain = 0.0
                FadeInEngine.shared.startFadeIn(
                    duration: SafeVolumeManager.shared.config.fadeInDuration,
                    audioEngine: self
                )
            } else {
                newPlayer.volume = 1.0
                self.softwareGain = 1.0
            }
        }
        self.player = newPlayer
        
        // Підписка на закінчення треку
        self.endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if self.repeatMode == .one {
                    self.seek(to: 0)
                    self.player?.play()
                    self.isPlaying = true
                    if let remote = CastlieConnectService.shared.activeRemoteDevice {
                        CastlieConnectService.shared.sendPlaybackCommand(deviceId: remote.id, action: "seek", value: 0)
                        CastlieConnectService.shared.sendPlaybackCommand(deviceId: remote.id, action: "play")
                    }
                    self.updateNowPlayingInfo()
                } else {
                    self.playNext(autoAdvance: true)
                }
            }
        }
        
        // Підписка на оновлення прогресу (кожні 0.1 секунди для маслянисто плавної анімації треку)
        self.timeObserver = newPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.10, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.currentTime = time.seconds
                if let itemDuration = self.player?.currentItem?.duration.seconds,
                   !itemDuration.isNaN && itemDuration > 0 && abs(self.duration - itemDuration) > 0.5 {
                    self.duration = itemDuration
                    self.updateNowPlayingInfo()
                }
            }
        }
        
        newPlayer.play()
        self.updateNowPlayingInfo()
    }
    
    /// Фонове кешування наступного треку, щоб у фоні при блокуванні екрана треки перемикалися без затримок
    private func prefetchNextTrack() {
        guard !queue.isEmpty else { return }
        let nextIndex = (currentIndex + 1) % queue.count
        let nextTrack = queue[nextIndex]
        guard previewCache[nextTrack.id] == nil else { return }
        
        Task { [weak self] in
            _ = await self?.resolveAudioURL(for: nextTrack)
        }
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
        if let remote = CastlieConnectService.shared.activeRemoteDevice {
            if isPlaying {
                player?.pause()
                isPlaying = false
                CastlieConnectService.shared.sendPlaybackCommand(deviceId: remote.id, action: "pause")
            } else {
                try? AVAudioSession.sharedInstance().setActive(true)
                player?.play()
                isPlaying = true
                CastlieConnectService.shared.sendPlaybackCommand(deviceId: remote.id, action: "play")
            }
            updateNowPlayingInfo()
            return
        }
        
        guard let player else { return }
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            try? AVAudioSession.sharedInstance().setActive(true)
            player.play()
            isPlaying = true
        }
        updateNowPlayingInfo()
    }
    
    /// Перемикання режиму перемішування (Shuffle)
    func toggleShuffle() {
        isShuffled.toggle()
    }
    
    /// Перемикання режиму повтору: вимкнено -> повторити всі -> повторити один -> вимкнено
    func toggleRepeat() {
        switch repeatMode {
        case .off:
            repeatMode = .all
        case .all:
            repeatMode = .one
        case .one:
            repeatMode = .off
        }
    }
    
    /// Зупинити відтворення повністю
    func stop() {
        playTask?.cancel()
        playTask = nil
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
    func playNext(autoAdvance: Bool = false) {
        guard !queue.isEmpty else { return }
        
        if autoAdvance {
            let now = Date()
            guard now.timeIntervalSince(lastAutoAdvanceTime) > 1.2 else { return }
            lastAutoAdvanceTime = now
        }
        
        // Режим Shuffle: обираємо випадковий інший трек
        if isShuffled && queue.count > 1 {
            var nextIndex: Int
            repeat {
                nextIndex = Int.random(in: 0..<queue.count)
            } while nextIndex == currentIndex
            currentIndex = nextIndex
            play(track: queue[currentIndex])
            return
        }
        
        let nextIndex = currentIndex + 1
        if nextIndex < queue.count {
            currentIndex = nextIndex
            play(track: queue[currentIndex])
        } else {
            // Дійшли до кінця списку
            if repeatMode == .all || !autoAdvance {
                currentIndex = 0
                play(track: queue[currentIndex])
            } else {
                // Якщо повтор вимкнено і трек закінчився сам — зупиняємо
                stop()
            }
        }
    }
    
    /// Попередній трек
    func playPrevious() {
        guard !queue.isEmpty else { return }
        // Якщо пройшло більше 3 секунд — перемотати на початок поточного треку
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
        currentTime = seconds
        if let remote = CastlieConnectService.shared.activeRemoteDevice {
            CastlieConnectService.shared.sendPlaybackCommand(deviceId: remote.id, action: "seek", value: seconds)
        }
        updateNowPlayingInfo()
    }
    
    /// Встановити гучність (0.0 - 1.0)
    func setVolume(_ newVolume: Float) {
        // Миттєве скасування активного fade-in при ручному керуванні користувачем
        FadeInEngine.shared.cancelFadeIn()
        
        let clamped = max(0, min(1, newVolume))
        volume = clamped
        
        if let remote = CastlieConnectService.shared.activeRemoteDevice {
            player?.volume = 0
            CastlieConnectService.shared.setRemoteVolume(deviceId: remote.id, volume: clamped)
            SafeVolumeManager.shared.updateDeviceVolume(
                deviceId: remote.id,
                deviceName: remote.name,
                volume: clamped
            )
            isReceivingRemoteVolumeUpdate = true
            SystemVolumeController.shared.setSystemVolume(clamped)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.isReceivingRemoteVolumeUpdate = false
            }
        } else {
            SystemVolumeController.shared.setSystemVolume(clamped)
            if let cur = DeviceDiscoveryService.shared.currentDevice {
                SafeVolumeManager.shared.updateDeviceVolume(
                    deviceId: cur.id,
                    deviceName: cur.name,
                    volume: clamped
                )
            }
        }
    }
    
    /// Синхронізація зі змінами апаратної системної гучності (фізичні кнопки iPhone, Mac тощо)
    func syncSystemVolume(_ sysVolume: Float) {
        guard !isReceivingRemoteVolumeUpdate, !DeviceDiscoveryService.shared.isHandoffSwitching else { return }
        let clamped = max(0, min(1, sysVolume))
        volume = clamped
        
        if let remote = CastlieConnectService.shared.activeRemoteDevice {
            // REMOTE IS ACTIVE: Звук на динаміку iPhone приглушений (0), гучність передається на Mac в реальному часі!
            player?.volume = 0
            CastlieConnectService.shared.setRemoteVolume(deviceId: remote.id, volume: clamped)
            SafeVolumeManager.shared.updateDeviceVolume(
                deviceId: remote.id,
                deviceName: remote.name,
                volume: clamped
            )
        } else {
            if let cur = DeviceDiscoveryService.shared.currentDevice {
                SafeVolumeManager.shared.updateDeviceVolume(
                    deviceId: cur.id,
                    deviceName: cur.name,
                    volume: clamped
                )
            }
        }
    }
    
    /// Встановити софтверний рівень AVPlayer для fade-in під капотом (не рухає системну гучність та UI)
    func setSoftwareGain(_ gain: Float) {
        let clamped = max(0, min(1, gain))
        softwareGain = clamped
        if CastlieConnectService.shared.activeRemoteDevice == nil {
            player?.volume = clamped
        }
    }
    
    /// Безпечне оновлення гучності від віддаленого Mac без нескінченного циклу KVO
    func updateVolumeFromRemote(_ newVolume: Float) {
        let clamped = max(0, min(1, newVolume))
        volume = clamped
        isReceivingRemoteVolumeUpdate = true
        SystemVolumeController.shared.setSystemVolume(clamped)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.isReceivingRemoteVolumeUpdate = false
        }
    }
    
    /// Відновлення нормальної локальної гучності після відключення Mac
    func handleRemoteDisconnected() {
        player?.volume = 1.0
        SystemVolumeController.shared.setSystemVolume(volume)
    }
    
    /// Оновлення стану відтворення від віддаленого пристрою
    func updatePlaybackState(isPlaying: Bool) {
        self.isPlaying = isPlaying
        updateNowPlayingInfo()
    }
    
    // MARK: - Now Playing Info (Lock Screen & Dynamic Island)
    
    /// Оновити інформацію на екрані блокування
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [String: Any]()
        info[MPMediaItemPropertyTitle] = track.name
        info[MPMediaItemPropertyArtist] = track.artistName
        info[MPMediaItemPropertyAlbumTitle] = track.albumName
        info[MPMediaItemPropertyPlaybackDuration] = duration > 0 ? duration : track.durationSeconds
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    /// Асинхронне завантаження обкладинки для екрана блокування та Dynamic Island
    private func loadArtworkForNowPlaying(track: Track) {
        guard let artworkURL = track.albumImageURL else { return }
        
        Task.detached(priority: .utility) {
            guard let (data, _) = try? await URLSession.shared.data(from: artworkURL),
                  let image = UIImage(data: data) else { return }
            
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            await MainActor.run {
                guard AudioEngine.shared.currentTrack?.id == track.id else { return }
                var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
                info[MPMediaItemPropertyArtwork] = artwork
                MPNowPlayingInfoCenter.default().nowPlayingInfo = info
            }
        }
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
