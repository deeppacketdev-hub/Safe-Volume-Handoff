import Foundation
import Observation

/// Логіка екрана пристроїв і діалогу безпечної гучності.
@Observable
@MainActor
final class DeviceManagerViewModel {
    enum Target: Identifiable, Equatable {
        case local(AudioDevice)
        case remote(CastlieRemoteDevice)

        var id: String {
            switch self {
            case .local(let device): "local-\(device.id)"
            case .remote(let remote): "remote-\(remote.id)"
            }
        }

        var device: AudioDevice {
            switch self {
            case .local(let device): device
            case .remote(let remote): remote.audioDevice
            }
        }
    }

    /// Пристрій, для якого відкрито діалог гучності.
    var target: Target?
    var draftVolume: Float = 0.3

    /// Гучність Mac до відкриття діалогу — повертаємо, якщо підключення не підтвердили.
    private var remoteOriginal: (id: String, volume: Float)?

    private let discovery = DeviceDiscoveryService.shared
    private let safe = SafeVolumeManager.shared
    private let engine = AudioEngine.shared
    private let connect = CastlieConnectService.shared

    // MARK: - Lists

    /// Локальний вихід, на якому зараз грає iPhone.
    var currentLocalDevice: AudioDevice { discovery.currentDevice }

    var activeRemote: CastlieRemoteDevice? { connect.activeRemoteDevice }

    /// Пристрій, на якому зараз звучить музика (Mac або локальний вихід).
    var activeOutput: AudioDevice { activeRemote?.audioDevice ?? discovery.currentDevice }

    /// Відомі пристрої, крім того, що грає зараз.
    var otherKnownDevices: [KnownDevice] {
        safe.knownDevices.filter { !$0.device.matches(discovery.currentDevice) || activeRemote != nil }
    }

    var receivers: [CastlieRemoteDevice] {
        connect.availableReceivers.filter { $0.id != activeRemote?.id }
    }

    /// Пристрій зараз грає (і звук не перенесено на Mac).
    func isCurrent(_ device: AudioDevice) -> Bool {
        activeRemote == nil && isLocalRoute(device)
    }

    /// Пристрій — поточний вихід iPhone (навіть якщо звук зараз іде на Mac).
    func isLocalRoute(_ device: AudioDevice) -> Bool {
        device.matches(discovery.currentDevice)
    }

    // MARK: - Selection

    func select(_ device: AudioDevice) {
        draftVolume = isCurrent(device) ? engine.volume : safe.safeStartVolume(for: device)
        remoteOriginal = nil
        target = .local(device)
    }

    func select(_ remote: CastlieRemoteDevice) {
        draftVolume = safe.clampToLimit(remote.volume)
        remoteOriginal = (remote.id, remote.volume)
        target = .remote(remote)
    }

    /// Повзунок у діалозі. Для Mac гучність змінюється наживо — так її чути ще до підключення.
    func draftChanged(_ volume: Float) {
        draftVolume = safe.clampToLimit(volume)
        if case .remote(let remote) = target {
            connect.setRemoteVolume(deviceId: remote.id, volume: draftVolume)
        }
    }

    func resetDraftToRecommended() {
        guard let target else { return }
        draftChanged(safe.safeStartVolume(for: target.device))
    }

    // MARK: - Actions

    /// Пристрій уже активний або це повернення з Mac на поточний вихід iPhone.
    func confirmLocalCurrent() {
        guard case .local(let device) = target else { return }
        if activeRemote != nil {
            connect.disconnectActiveRemote(continueLocally: true, volume: draftVolume)
        } else {
            engine.applyVolume(draftVolume, for: device)
        }
        finish()
    }

    /// Користувач відкриває системне меню — запам'ятовуємо гучність для пристрою, який він обере.
    func armForSystemPicker() {
        guard case .local(let device) = target else { return }
        discovery.armHandoff(to: device, volume: draftVolume)
    }

    /// Швидке підключення без діалогу (коли підтвердження вимкнено в налаштуваннях).
    func armWithoutConfirmation(_ device: AudioDevice) {
        discovery.armHandoff(to: device, volume: safe.safeStartVolume(for: device))
    }

    func confirmRemote() {
        guard case .remote(let remote) = target else { return }
        var device = remote
        device.volume = draftVolume
        remoteOriginal = nil
        connect.connectToRemote(device)
        HapticFeedbackService.success()
        finish()
    }

    func cancel() {
        restoreRemoteVolumeIfNeeded()
        finish()
    }

    /// Діалог закрили свайпом — так само, як "Скасувати".
    func sheetDismissed() {
        restoreRemoteVolumeIfNeeded()
    }

    private func restoreRemoteVolumeIfNeeded() {
        guard let original = remoteOriginal else { return }
        remoteOriginal = nil
        connect.setRemoteVolume(deviceId: original.id, volume: original.volume)
    }

    /// Викликається, коли iOS перемкнула вихід на пристрій із діалогу.
    func handoffCompleted() {
        HapticFeedbackService.success()
        finish()
    }

    func disconnectRemote() {
        connect.disconnectActiveRemote(continueLocally: true)
        HapticFeedbackService.light()
    }

    func forget(_ device: KnownDevice) {
        safe.forget(device.id)
    }

    private func finish() {
        remoteOriginal = nil
        target = nil
    }
}
