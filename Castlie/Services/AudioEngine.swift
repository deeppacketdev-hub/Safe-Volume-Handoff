import AVFoundation
import MediaPlayer
import UIKit

/// Відтворення 30-секундних прев'ю, черга, гучність та безпечні переходи між аудіовиходами.
@Observable
@MainActor
final class AudioEngine {
    static let shared = AudioEngine()

    enum RepeatMode: Int, CaseIterable {
        case off, all, one

        var symbol: String { self == .one ? "repeat.1" : "repeat" }

        var accessibilityLabel: String {
            switch self {
            case .off: "Повтор вимкнено"
            case .all: "Повторювати все"
            case .one: "Повторювати трек"
            }
        }
    }

    /// Коротке повідомлення для користувача (показується як банер).
    struct Notice: Identifiable, Equatable {
        let id = UUID()
        let message: String
        let symbol: String
    }

    // MARK: - State

    private(set) var currentTrack: Track?
    /// Намір відтворення: true також під час завантаження прев'ю.
    private(set) var isPlaying = false
    private(set) var isBuffering = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    /// Апаратна гучність поточного виходу (або гучність Mac, якщо підключено Castlie Connect).
    private(set) var volume: Float
    private(set) var isShuffled = false
    private(set) var repeatMode: RepeatMode = .off
    private(set) var queue: [Track] = []
    private(set) var currentIndex = 0
    private(set) var notice: Notice?

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, currentTime / duration))
    }

    // MARK: - Private

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    private var statusObservation: NSKeyValueObservation?
    private var itemObservation: NSKeyValueObservation?
    private var playTask: Task<Void, Never>?
    private var fadeTask: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?
    private var previewCache: [String: URL] = [:]
    private var currentAudioURL: URL?
    private var lastAutoAdvance = Date.distantPast
    private var isSeeking = false

    /// Програмне підсилення для fade-in (0…1), не чіпає системну гучність.
    private var gain: Float = 1
    /// Обмеження підсилення, якщо iOS не дала змінити апаратну гучність (додаток у фоні).
    private var softwareCap: Float = 1
    private var needsFadeOnResume = false
    private var handoffGuardUntil = Date.distantPast
    private var lastNoticeDate = Date.distantPast
    private var lastHandoffSent = Date.distantPast
    private var lastHardwareVolume: Float = 0
    private var fadeOnNextSetup = false
    private var resumeAfterInterruption = false
    private var rememberTask: Task<Void, Never>?

    private var safe: SafeVolumeManager { .shared }
    private var connect: CastlieConnectService { .shared }
    private var isRemote: Bool { connect.activeRemoteDevice != nil }

    private init() {
        volume = AVAudioSession.sharedInstance().outputVolume
        lastHardwareVolume = volume
        configureSession()
        configureRemoteCommands()
        observeInterruptions()
        _ = SystemVolumeController.shared
    }

    // MARK: - Session

    private func configureSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, policy: .longFormAudio)
        try? session.setActive(true)
    }

    private func observeInterruptions() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let info = notification.userInfo
            let type = (info?[AVAudioSessionInterruptionTypeKey] as? UInt).flatMap(AVAudioSession.InterruptionType.init)
            let options = (info?[AVAudioSessionInterruptionOptionKey] as? UInt).map(AVAudioSession.InterruptionOptions.init)
            MainActor.assumeIsolated {
                guard let self, let type else { return }
                switch type {
                case .began:
                    self.resumeAfterInterruption = self.isPlaying
                    self.pause()
                case .ended:
                    // Продовжуємо лише якщо музика грала до дзвінка, а не стояла на паузі.
                    if options?.contains(.shouldResume) == true, self.resumeAfterInterruption {
                        self.needsFadeOnResume = true
                        self.resume()
                    }
                    self.resumeAfterInterruption = false
                @unknown default:
                    break
                }
            }
        }
    }

    private func configureRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { _ in
            Task { @MainActor in AudioEngine.shared.resume() }
            return .success
        }
        center.pauseCommand.addTarget { _ in
            Task { @MainActor in AudioEngine.shared.pause() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget { _ in
            Task { @MainActor in AudioEngine.shared.togglePlayPause() }
            return .success
        }
        center.nextTrackCommand.addTarget { _ in
            Task { @MainActor in AudioEngine.shared.playNext() }
            return .success
        }
        center.previousTrackCommand.addTarget { _ in
            Task { @MainActor in AudioEngine.shared.playPrevious() }
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            let position = event.positionTime
            Task { @MainActor in AudioEngine.shared.seek(to: position) }
            return .success
        }
    }

    // MARK: - Playback

    func play(tracks: [Track], startIndex: Int = 0) {
        guard tracks.indices.contains(startIndex) else { return }
        let wasAudible = isPlaying
        queue = tracks
        currentIndex = startIndex
        startPlayback(of: tracks[startIndex], fade: !wasAudible)
    }

    func playShuffled(_ tracks: [Track]) {
        guard !tracks.isEmpty else { return }
        isShuffled = true
        play(tracks: tracks, startIndex: Int.random(in: tracks.indices))
    }

    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    func pause() {
        guard isPlaying else { return }
        fadeTask?.cancel()
        fadeTask = nil
        if player == nil {
            playTask?.cancel()
            playTask = nil
        }
        player?.pause()
        isPlaying = false
        isBuffering = false
        if let remote = connect.activeRemoteDevice {
            connect.sendPlaybackCommand(deviceId: remote.id, action: "pause")
        }
        updateNowPlayingInfo()
    }

    func resume() {
        guard !isPlaying, let track = currentTrack else { return }
        guard let player else {
            startPlayback(of: track, fade: true)
            return
        }
        try? AVAudioSession.sharedInstance().setActive(true)
        if !isRemote {
            // Якщо поки стояли на паузі гучність не вдалося застосувати — приглушуємо різницю.
            updateSoftwareCap(desired: volume, hardware: SystemVolumeController.shared.currentVolume)
        }

        let shouldFade = needsFadeOnResume && safe.config.isFadeInEnabled && !isRemote
        needsFadeOnResume = false
        gain = shouldFade ? 0 : 1
        applyGain()
        player.play()
        isPlaying = true
        if shouldFade { startFade(duration: safe.config.fadeInDuration) }

        if let remote = connect.activeRemoteDevice {
            connect.sendPlaybackCommand(deviceId: remote.id, action: "play")
        }
        updateNowPlayingInfo()
    }

    func playNext(autoAdvance: Bool = false) {
        guard !queue.isEmpty else { return }
        if autoAdvance {
            guard Date().timeIntervalSince(lastAutoAdvance) > 1.2 else { return }
            lastAutoAdvance = Date()
        }
        let wasAudible = isPlaying

        if isShuffled && queue.count > 1 {
            var next = currentIndex
            while next == currentIndex { next = Int.random(in: 0..<queue.count) }
            currentIndex = next
        } else if currentIndex + 1 < queue.count {
            currentIndex += 1
        } else if repeatMode == .all || !autoAdvance {
            currentIndex = 0
        } else {
            finishQueue()
            return
        }
        startPlayback(of: queue[currentIndex], fade: !wasAudible)
    }

    func playPrevious() {
        guard !queue.isEmpty else { return }
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        let wasAudible = isPlaying
        currentIndex = (currentIndex - 1 + queue.count) % queue.count
        startPlayback(of: queue[currentIndex], fade: !wasAudible)
    }

    func seek(to seconds: Double) {
        let target = max(0, min(seconds, duration > 0 ? duration : seconds))
        currentTime = target
        if let player {
            isSeeking = true
            player.seek(to: CMTime(seconds: target, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero) { [weak self] _ in
                Task { @MainActor in self?.isSeeking = false }
            }
        }
        if let remote = connect.activeRemoteDevice {
            connect.sendPlaybackCommand(deviceId: remote.id, action: "seek", value: target)
        }
        updateNowPlayingInfo()
    }

    func toggleShuffle() { isShuffled.toggle() }

    func toggleRepeat() {
        repeatMode = RepeatMode(rawValue: (repeatMode.rawValue + 1) % RepeatMode.allCases.count) ?? .off
    }

    private func startPlayback(of track: Track, fade: Bool) {
        playTask?.cancel()
        teardownPlayer()

        currentTrack = track
        currentTime = 0
        duration = 0
        isPlaying = true
        isBuffering = true
        updateNowPlayingInfo()
        loadNowPlayingArtwork(for: track)

        let shouldFade = fade && safe.config.isFadeInEnabled
        let backgroundTask = BackgroundTask(name: "CastlieResolveAudio")

        playTask = Task { [weak self] in
            defer { backgroundTask.end() }
            guard let self else { return }
            let url = await self.resolveAudioURL(for: track)
            guard !Task.isCancelled, self.currentTrack?.id == track.id else { return }

            guard let url else {
                self.isPlaying = false
                self.isBuffering = false
                self.playTask = nil
                self.updateNowPlayingInfo()
                self.showNotice("Для цього треку немає прев'ю", symbol: "speaker.slash.fill")
                return
            }

            self.currentAudioURL = url
            try? AVAudioSession.sharedInstance().setActive(true)
            if let remote = self.connect.activeRemoteDevice {
                self.markHandoffSent()
                self.connect.sendHandoff(
                    to: remote.id,
                    track: track,
                    previewURL: url,
                    targetVolume: remote.volume,
                    fadeInDuration: self.remoteFadeDuration,
                    startTime: 0
                )
            }
            self.setupPlayer(url: url, fade: shouldFade)
            self.playTask = nil
            self.prefetchNextTrack()
        }
    }

    private func setupPlayer(url: URL, fade requestedFade: Bool) {
        let fade = requestedFade || (fadeOnNextSetup && !isRemote)
        fadeOnNextSetup = false
        let item = AVPlayerItem(url: url)
        let player = AVPlayer(playerItem: item)
        self.player = player
        gain = fade ? 0 : 1
        applyGain()

        endObserver = NotificationCenter.default.addObserver(
            forName: AVPlayerItem.didPlayToEndTimeNotification,
            object: item,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.handleTrackEnded() }
        }

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 10),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated { self?.handleTick(time) }
        }

        statusObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let waiting = player.timeControlStatus == .waitingToPlayAtSpecifiedRate
            Task { @MainActor in
                guard let self, self.player === player else { return }
                self.isBuffering = waiting && self.isPlaying
            }
        }

        itemObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            let failed = item.status == .failed
            Task { @MainActor in
                guard failed, let self, self.player?.currentItem === item else { return }
                self.teardownPlayer()
                self.isPlaying = false
                self.isBuffering = false
                self.updateNowPlayingInfo()
                self.showNotice("Не вдалося відтворити трек", symbol: "exclamationmark.triangle.fill")
            }
        }

        player.play()
        if fade { startFade(duration: safe.config.isFadeInEnabled ? safe.config.fadeInDuration : 0.3) }
        updateNowPlayingInfo()
    }

    private func handleTick(_ time: CMTime) {
        guard !isSeeking, time.isNumeric else { return }
        currentTime = time.seconds
        if let itemDuration = player?.currentItem?.duration.seconds,
           itemDuration.isFinite, itemDuration > 0, abs(duration - itemDuration) > 0.5 {
            duration = itemDuration
            updateNowPlayingInfo()
        }
    }

    private func handleTrackEnded() {
        if repeatMode == .one {
            seek(to: 0)
            player?.play()
            if let remote = connect.activeRemoteDevice {
                connect.sendPlaybackCommand(deviceId: remote.id, action: "play")
            }
        } else {
            playNext(autoAdvance: true)
        }
    }

    /// Mac повідомив, що трек закінчився.
    func handleRemoteTrackEnded() {
        // Щойно надіслали новий трек — подія стосується попереднього.
        guard Date().timeIntervalSince(lastHandoffSent) > 3 else { return }
        handleTrackEnded()
    }

    /// Mac змінив стан відтворення (наприклад, паузу натиснули в меню на Mac).
    func handleRemotePlaybackState(isPlaying remotePlaying: Bool) {
        guard isRemote, remotePlaying != isPlaying, playTask == nil else { return }
        // Щойно надіслали новий трек — "не граю" від Mac стосується попереднього.
        if !remotePlaying, Date().timeIntervalSince(lastHandoffSent) < 3 { return }
        isPlaying = remotePlaying
        remotePlaying ? player?.play() : player?.pause()
        updateNowPlayingInfo()
    }

    private func finishQueue() {
        teardownPlayer()
        isPlaying = false
        isBuffering = false
        currentTime = 0
        updateNowPlayingInfo()
    }

    private func teardownPlayer() {
        fadeTask?.cancel()
        fadeTask = nil
        player?.pause()
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        timeObserver = nil
        endObserver = nil
        statusObservation = nil
        itemObservation = nil
        player = nil
        isSeeking = false
    }

    // MARK: - Fade & gain

    private var remoteFadeDuration: Double {
        safe.config.isFadeInEnabled ? safe.config.fadeInDuration : 0
    }

    private func applyGain() {
        player?.volume = isRemote ? 0 : gain * softwareCap
    }

    /// Плавне наростання з квадратичною кривою — на слух рівномірніше за лінійну.
    private func startFade(delay: Double = 0, duration: Double) {
        fadeTask?.cancel()
        fadeTask = Task { [weak self] in
            if delay > 0 { try? await Task.sleep(for: .seconds(delay)) }
            let steps = max(1, Int(duration * 60))
            let interval = duration / Double(steps)
            for step in 1...steps {
                guard !Task.isCancelled, let self else { return }
                let progress = Float(step) / Float(steps)
                self.gain = progress * progress
                self.applyGain()
                try? await Task.sleep(for: .seconds(interval))
            }
            guard !Task.isCancelled, let self else { return }
            self.gain = 1
            self.applyGain()
            self.fadeTask = nil
        }
    }

    // MARK: - Volume

    /// Користувач змінює гучність у додатку.
    func setVolume(_ newValue: Float) {
        let clamped = safe.clampToLimit(newValue)
        if let remote = connect.activeRemoteDevice {
            volume = clamped
            SystemVolumeController.shared.setVolume(clamped)
            connect.setRemoteVolume(deviceId: remote.id, volume: clamped)
        } else {
            setEffectiveVolume(clamped)
            rememberSoon(clamped, for: DeviceDiscoveryService.shared.currentDevice)
        }
    }

    /// Запам'ятати гучність, коли користувач перестане її крутити (а не на кожен кадр жесту).
    private func rememberSoon(_ value: Float, for device: AudioDevice) {
        rememberTask?.cancel()
        rememberTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            self?.safe.remember(device, volume: value)
        }
    }

    /// Застосувати гучність до поточного локального виходу та запам'ятати її для пристрою.
    func applyVolume(_ value: Float, for device: AudioDevice) {
        rememberTask?.cancel()
        let clamped = safe.clampToLimit(value)
        setEffectiveVolume(clamped)
        safe.remember(device, volume: clamped)
    }

    /// Ефективна гучність локального виходу: просимо iOS змінити апаратну, а поки вона не підтвердить
    /// (або якщо не дасть зовсім — додаток у фоні), різницю приглушуємо програмно.
    private func setEffectiveVolume(_ desired: Float) {
        volume = desired
        SystemVolumeController.shared.setVolume(desired)
        updateSoftwareCap(desired: desired, hardware: SystemVolumeController.shared.currentVolume)
    }

    private func updateSoftwareCap(desired: Float, hardware: Float) {
        lastHardwareVolume = hardware
        let cap: Float = hardware > desired + 0.02 && hardware > 0
            ? max(0.03, pow(desired / hardware, 2))
            : 1
        guard abs(cap - softwareCap) > 0.001 else { return }
        softwareCap = cap
        applyGain()
    }

    /// Апаратна гучність змінилась (кнопки, Пункт керування, iOS або наш власний запис).
    func handleHardwareVolumeChange(_ value: Float, isEcho: Bool) {
        let limit = safe.maxAllowedVolume

        if let remote = connect.activeRemoteDevice {
            guard !isEcho, Date() >= handoffGuardUntil else { return }
            let desired = min(value, limit)
            if value > limit + 0.01 {
                SystemVolumeController.shared.setVolume(limit)
                showNotice("Нічний ліміт \(Format.percent(limit))", symbol: "moon.fill", throttle: true)
            }
            volume = desired
            connect.setRemoteVolume(deviceId: remote.id, volume: desired)
            return
        }

        // Наш власний запис дійшов до системи — програмне приглушення більше не потрібне.
        if isEcho {
            updateSoftwareCap(desired: volume, hardware: value)
            return
        }

        // Під час перемикання виходу iOS відновлює гучність маршруту — тримаємо вибрану нами.
        if Date() < handoffGuardUntil {
            if value > volume + 0.02 { SystemVolumeController.shared.setVolume(volume) }
            updateSoftwareCap(desired: volume, hardware: value)
            return
        }

        // Кнопки гучності. Якщо діє приглушення, змінюємо відносно, щоб не було стрибка.
        var desired = softwareCap < 1 ? volume + (value - lastHardwareVolume) : value
        desired = min(max(desired, 0), limit)
        if value > limit + 0.01 {
            showNotice("Нічний ліміт \(Format.percent(limit))", symbol: "moon.fill", throttle: true)
        }
        volume = desired
        if value > desired + 0.02 { SystemVolumeController.shared.setVolume(desired) }
        updateSoftwareCap(desired: desired, hardware: value)

        if DeviceDiscoveryService.shared.isRouteSettled {
            rememberSoon(desired, for: DeviceDiscoveryService.shared.currentDevice)
        }
    }

    /// Знизити гучність, якщо вона вища за нічний ліміт.
    func enforceVolumeLimit() {
        let limit = safe.maxAllowedVolume
        guard volume > limit + 0.01 else { return }
        if let remote = connect.activeRemoteDevice {
            volume = limit
            SystemVolumeController.shared.setVolume(limit)
            connect.setRemoteVolume(deviceId: remote.id, volume: limit)
        } else {
            setEffectiveVolume(limit)
        }
        showNotice("Нічний режим: гучність \(Format.percent(limit))", symbol: "moon.fill", throttle: true)
    }

    // MARK: - Safe handoff

    /// Безпечний перехід на новий вихід: тиша → потрібна гучність → плавне наростання.
    func performSafeHandoff(to device: AudioDevice, volume target: Float) {
        handoffGuardUntil = Date().addingTimeInterval(1.2)
        let audible = isPlaying && player != nil && !isRemote
        let resolving = isPlaying && player == nil && !isRemote

        fadeTask?.cancel()
        fadeTask = nil
        if audible {
            gain = 0
            applyGain()
        }
        applyVolume(target, for: device)

        if audible {
            let fadeDuration = safe.config.isFadeInEnabled ? safe.config.fadeInDuration : 0.3
            startFade(delay: 0.3, duration: fadeDuration)
        } else if resolving {
            fadeOnNextSetup = true
        } else {
            needsFadeOnResume = true
        }
    }

    /// Додаток повернувся на передній план: просимо iOS виставити гучність, яку зараз імітує приглушення.
    func reconcileVolumeAfterForeground() {
        guard softwareCap < 1, !isRemote else { return }
        SystemVolumeController.shared.setVolume(volume)
    }

    /// Пристрій відключився (наприклад, вийняли навушники) — ставимо на паузу, як системні плеєри.
    func pauseForRouteLoss() {
        pause()
    }

    // MARK: - Castlie Connect

    /// Mac підключено: звук іде на Mac, локальний плеєр грає беззвучно для таймлайну та кнопок гучності.
    func didConnectRemote(_ remote: CastlieRemoteDevice) {
        fadeTask?.cancel()
        fadeTask = nil
        softwareCap = 1
        applyGain()
        handoffGuardUntil = Date().addingTimeInterval(1)
        volume = remote.volume
        SystemVolumeController.shared.setVolume(remote.volume)

        guard let track = currentTrack ?? queue.first else { return }
        if let url = currentAudioURL, currentTrack != nil, player != nil {
            markHandoffSent()
            connect.sendHandoff(
                to: remote.id,
                track: track,
                previewURL: url,
                targetVolume: remote.volume,
                fadeInDuration: remoteFadeDuration,
                startTime: currentTime
            )
            if !isPlaying {
                player?.play()
                isPlaying = true
                updateNowPlayingInfo()
            }
        } else if playTask == nil || !isPlaying {
            startPlayback(of: track, fade: false)
        }
        // Інакше прев'ю ще шукається — коли знайдеться, startPlayback сам надішле його на Mac.
    }

    /// Гучність змінили на самому Mac — синхронізуємо, щоб кнопки iPhone продовжували з того ж рівня.
    func didReceiveRemoteVolume(_ value: Float) {
        volume = value
        SystemVolumeController.shared.setVolume(value)
    }

    /// Mac відключено. Якщо `continueLocally` — продовжуємо на iPhone з безпечною гучністю,
    /// інакше (зв'язок втрачено) ставимо на паузу, щоб звук раптово не пішов з телефона.
    func didDisconnectRemote(continueLocally: Bool, volume target: Float? = nil) {
        let device = DeviceDiscoveryService.shared.currentDevice
        let localVolume = target ?? safe.safeStartVolume(for: device)

        guard continueLocally else {
            pause()
            gain = 0
            applyGain()
            needsFadeOnResume = true
            handoffGuardUntil = Date().addingTimeInterval(1)
            applyVolume(localVolume, for: device)
            showNotice("Зв'язок з Mac втрачено", symbol: "laptopcomputer.slash")
            return
        }
        performSafeHandoff(to: device, volume: localVolume)
        updateNowPlayingInfo()
    }

    private func markHandoffSent() {
        lastHandoffSent = Date()
    }

    // MARK: - Notices

    func showNotice(_ message: String, symbol: String, throttle: Bool = false) {
        if throttle, Date().timeIntervalSince(lastNoticeDate) < 3 { return }
        lastNoticeDate = Date()
        notice = Notice(message: message, symbol: symbol)
        noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }

    func dismissNotice() {
        noticeTask?.cancel()
        notice = nil
    }

    // MARK: - Preview resolving

    /// Офіційне прев'ю Spotify або пошук того ж треку в iTunes / Deezer.
    private func resolveAudioURL(for track: Track) async -> URL? {
        if let cached = previewCache[track.id] { return cached }
        if let url = track.previewURL {
            previewCache[track.id] = url
            return url
        }

        let query = "\(track.artistName) \(track.name)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }

        struct ITunesResponse: Decodable {
            struct Item: Decodable { let previewUrl: String? }
            let results: [Item]
        }
        struct DeezerResponse: Decodable {
            struct Item: Decodable { let preview: String? }
            let data: [Item]?
        }

        if let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=song&limit=1"),
           let response: ITunesResponse = await fetchJSON(url),
           let preview = response.results.first?.previewUrl.flatMap(URL.init(string:)) {
            previewCache[track.id] = preview
            return preview
        }
        guard !Task.isCancelled else { return nil }
        if let url = URL(string: "https://api.deezer.com/search?q=\(encoded)&limit=1"),
           let response: DeezerResponse = await fetchJSON(url),
           let preview = response.data?.first?.preview.flatMap(URL.init(string:)) {
            previewCache[track.id] = preview
            return preview
        }
        return nil
    }

    private func fetchJSON<T: Decodable>(_ url: URL) async -> T? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200 else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    private func prefetchNextTrack() {
        guard queue.count > 1 else { return }
        let next = queue[(currentIndex + 1) % queue.count]
        guard previewCache[next.id] == nil else { return }
        Task { [weak self] in _ = await self?.resolveAudioURL(for: next) }
    }

    // MARK: - Now Playing (екран блокування, Dynamic Island)

    private func updateNowPlayingInfo() {
        guard let track = currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }
        var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        info[MPMediaItemPropertyTitle] = track.name
        info[MPMediaItemPropertyArtist] = track.artistName
        info[MPMediaItemPropertyAlbumTitle] = track.albumName
        info[MPMediaItemPropertyPlaybackDuration] = duration > 0 ? duration : 30
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying && !isBuffering ? 1.0 : 0.0
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func loadNowPlayingArtwork(for track: Track) {
        guard let url = track.albumImageURL else { return }
        Task { [weak self] in
            guard let image = await ArtworkStore.shared.image(for: url, pixels: 512),
                  let self, self.currentTrack?.id == track.id else { return }
            var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            info[MPMediaItemPropertyArtwork] = Self.makeArtwork(image)
            MPNowPlayingInfoCenter.default().nowPlayingInfo = info
        }
    }

    /// MediaPlayer викликає обробник з фонового потоку, тому він не має бути прив'язаний до MainActor.
    nonisolated private static func makeArtwork(_ image: UIImage) -> MPMediaItemArtwork {
        MPMediaItemArtwork(boundsSize: image.size) { _ in image }
    }
}

/// Фоновий час, щоб iOS не приспала додаток, поки шукається посилання на наступний трек.
@MainActor
private final class BackgroundTask {
    private var identifier: UIBackgroundTaskIdentifier = .invalid

    init(name: String) {
        identifier = UIApplication.shared.beginBackgroundTask(withName: name) { [weak self] in
            MainActor.assumeIsolated { self?.end() }
        }
    }

    func end() {
        guard identifier != .invalid else { return }
        UIApplication.shared.endBackgroundTask(identifier)
        identifier = .invalid
    }
}
