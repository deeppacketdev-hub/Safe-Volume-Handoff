import AVFoundation
import Observation

/// Стежить за аудіовиходом iPhone та виконує Safe Volume Handoff при кожній зміні.
///
/// iOS не дозволяє сторонньому додатку вибрати конкретну Bluetooth-колонку чи навушники,
/// тому перемикання відбувається через системне меню AirPlay/Bluetooth. Castlie заздалегідь
/// "озброює" вибрану гучність і застосовує її в момент, коли iOS реально перемикає звук.
@Observable
@MainActor
final class DeviceDiscoveryService {
    static let shared = DeviceDiscoveryService()

    /// Очікуваний перехід: користувач вибрав гучність і зараз обирає пристрій у системному меню.
    struct PendingHandoff: Equatable {
        let device: AudioDevice
        let volume: Float
        let createdAt: Date
    }

    /// Остання подія переходу — для банера "Підключено до … · 30%".
    struct HandoffEvent: Identifiable, Equatable {
        let id = UUID()
        let device: AudioDevice
        let volume: Float
    }

    private(set) var currentDevice: AudioDevice
    private(set) var pendingHandoff: PendingHandoff?
    private(set) var lastHandoff: HandoffEvent?

    private var routeObserver: NSObjectProtocol?
    private var expiryTask: Task<Void, Never>?
    private let pendingLifetime: TimeInterval = 120

    private init() {
        currentDevice = Self.readCurrentRoute()
        SafeVolumeManager.shared.markUsed(currentDevice, currentVolume: AVAudioSession.sharedInstance().outputVolume)

        routeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { notification in
            let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            let reason = reasonValue.flatMap(AVAudioSession.RouteChangeReason.init)
            MainActor.assumeIsolated {
                DeviceDiscoveryService.shared.handleRouteChange(reason: reason)
            }
        }
    }

    /// Чи відповідає `currentDevice` реальному маршруту прямо зараз.
    var isRouteSettled: Bool {
        Self.currentRouteID() == currentDevice.id
    }

    // MARK: - Route changes

    private func handleRouteChange(reason: AVAudioSession.RouteChangeReason?) {
        let newDevice = Self.readCurrentRoute()
        guard newDevice.id != currentDevice.id else {
            if newDevice != currentDevice { currentDevice = newDevice }
            return
        }
        currentDevice = newDevice

        let engine = AudioEngine.shared
        let safe = SafeVolumeManager.shared

        // Вийняли навушники чи вимкнули колонку — пауза, щоб музика раптово не заграла з динаміка.
        // Якщо звук іде на Mac, локальний вихід ні на що не впливає.
        if reason == .oldDeviceUnavailable, CastlieConnectService.shared.activeRemoteDevice == nil {
            engine.pauseForRouteLoss()
        }

        let matchedPending = pendingHandoff.flatMap { pending in
            pending.device.matches(newDevice) && Date().timeIntervalSince(pending.createdAt) < pendingLifetime
                ? pending : nil
        }
        if matchedPending != nil { cancelPendingHandoff() }

        if CastlieConnectService.shared.activeRemoteDevice != nil {
            guard let pending = matchedPending else {
                // Звук іде на Mac, а вихід iPhone змінився сам — лише запам'ятовуємо пристрій.
                safe.markUsed(newDevice, currentVolume: SystemVolumeController.shared.currentVolume)
                return
            }
            // Користувач вибрав цей пристрій у Castlie — повертаємо звук з Mac сюди.
            let target = safe.clampToLimit(pending.volume)
            CastlieConnectService.shared.disconnectActiveRemote(continueLocally: true, volume: target)
            lastHandoff = HandoffEvent(device: newDevice, volume: target)
            HapticFeedbackService.success()
            return
        }

        let target = matchedPending.map { safe.clampToLimit($0.volume) } ?? safe.safeStartVolume(for: newDevice)
        engine.performSafeHandoff(to: newDevice, volume: target)
        lastHandoff = HandoffEvent(device: newDevice, volume: target)
        HapticFeedbackService.success()
    }

    // MARK: - Pending handoff

    /// Запам'ятати гучність для пристрою, який користувач зараз обере в системному меню.
    func armHandoff(to device: AudioDevice, volume: Float) {
        pendingHandoff = PendingHandoff(device: device, volume: volume, createdAt: Date())
        expiryTask?.cancel()
        let lifetime = pendingLifetime
        expiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(lifetime))
            guard !Task.isCancelled else { return }
            self?.pendingHandoff = nil
        }
    }

    func cancelPendingHandoff() {
        expiryTask?.cancel()
        expiryTask = nil
        pendingHandoff = nil
    }

    // MARK: - Route reading

    private static func currentRouteID() -> String? {
        guard let output = AVAudioSession.sharedInstance().currentRoute.outputs.first else {
            return AudioDevice.iPhone.id
        }
        return device(for: output).id
    }

    static func readCurrentRoute() -> AudioDevice {
        guard let output = AVAudioSession.sharedInstance().currentRoute.outputs.first else {
            return .iPhone
        }
        return device(for: output)
    }

    private static func device(for output: AVAudioSessionPortDescription) -> AudioDevice {
        let name = output.portName
        switch output.portType {
        case .builtInSpeaker, .builtInReceiver:
            return .iPhone
        case .headphones:
            return AudioDevice(id: output.uid, name: name, type: .headphones, connection: .wired)
        case .bluetoothA2DP, .bluetoothLE, .bluetoothHFP:
            return AudioDevice(
                id: output.uid,
                name: name,
                type: AudioDevice.guessType(fromName: name, isAirPlay: false),
                connection: .bluetooth
            )
        case .airPlay:
            return AudioDevice(
                id: output.uid,
                name: name,
                type: AudioDevice.guessType(fromName: name, isAirPlay: true),
                connection: .airPlay
            )
        case .carAudio:
            return AudioDevice(id: output.uid, name: name, type: .car, connection: .carPlay)
        case .HDMI:
            return AudioDevice(id: output.uid, name: name, type: .tv, connection: .wired)
        default:
            return AudioDevice(id: output.uid, name: name, type: .speaker, connection: .wired)
        }
    }
}
