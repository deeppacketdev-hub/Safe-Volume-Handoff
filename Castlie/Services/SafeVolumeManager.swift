import SwiftUI

/// Правила безпечної гучності: пороги, нічний ліміт, пам'ять гучності для кожного пристрою.
@Observable
@MainActor
final class SafeVolumeManager {
    static let shared = SafeVolumeManager()

    var config: SafeVolumeConfig {
        didSet {
            guard config != oldValue else { return }
            saveConfig()
            refreshNightMode()
        }
    }

    /// Чи діє зараз нічний ліміт (оновлюється щохвилини).
    private(set) var isNightModeActive = false

    /// Відомі пристрої, від останнього використаного до найстарішого.
    private(set) var knownDevices: [KnownDevice] = []

    private let configKey = "SafeVolumeConfig"
    private let devicesKey = "Castlie.KnownDevices"
    private var saveTask: Task<Void, Never>?
    private var nightTimer: Timer?

    private init() {
        config = Self.loadConfig(key: configKey)
        knownDevices = loadDevices()
        isNightModeActive = config.isNightTime()
        nightTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task { @MainActor in SafeVolumeManager.shared.refreshNightMode() }
        }
    }

    // MARK: - Safety levels

    enum SafetyLevel: Equatable {
        case safe, warning, danger

        var color: Color {
            switch self {
            case .safe: Color(hex: "30D158")
            case .warning: Color(hex: "FFD60A")
            case .danger: Color(hex: "FF453A")
            }
        }

        var symbol: String {
            switch self {
            case .safe: "checkmark.shield.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .danger: "exclamationmark.shield.fill"
            }
        }

        var label: String {
            switch self {
            case .safe: "Безпечно"
            case .warning: "Підвищена гучність"
            case .danger: "Небезпечно для слуху"
            }
        }
    }

    /// Межі зон: для навушників суворіші, бо звук іде прямо у вухо.
    func thresholds(for type: DeviceType) -> (safe: Float, warning: Float) {
        type == .headphones ? (0.4, 0.6) : (0.5, 0.75)
    }

    func safetyLevel(for volume: Float, type: DeviceType) -> SafetyLevel {
        let limits = thresholds(for: type)
        if volume <= limits.safe + 0.001 { return .safe }
        if volume <= limits.warning + 0.001 { return .warning }
        return .danger
    }

    /// Максимум, який зараз дозволено виставити (нічний ліміт або 100%).
    var maxAllowedVolume: Float {
        isNightModeActive ? config.nightModeMaxVolume : 1
    }

    func clampToLimit(_ volume: Float) -> Float {
        min(max(0, volume), maxAllowedVolume)
    }

    // MARK: - Volume memory

    func defaultVolume(for type: DeviceType) -> Float {
        switch type {
        case .headphones: 0.25
        case .iPhone: 0.35
        case .mac: 0.4
        default: 0.3
        }
    }

    func knownDevice(for device: AudioDevice) -> KnownDevice? {
        knownDevices.first { $0.id == device.id } ?? knownDevices.first { $0.device.matchKey == device.matchKey }
    }

    func savedVolume(for device: AudioDevice) -> Float? {
        knownDevice(for: device)?.volume
    }

    /// Гучність, з якою безпечно почати на пристрої без підтвердження користувача:
    /// остання збережена, але не вище жовтої зони та нічного ліміту.
    func safeStartVolume(for device: AudioDevice) -> Float {
        let base = savedVolume(for: device) ?? defaultVolume(for: device.type)
        return min(base, thresholds(for: device.type).warning, maxAllowedVolume)
    }

    /// Запам'ятати гучність пристрою. Запис на диск відкладається, щоб не писати на кожен рух повзунка.
    func remember(_ device: AudioDevice, volume: Float) {
        guard device.connection != .castlieConnect else { return }
        let clamped = min(max(0, volume), 1)
        if let index = knownDevices.firstIndex(where: { $0.id == device.id }) {
            var entry = knownDevices[index]
            entry.volume = clamped
            entry.name = device.name
            entry.lastUsed = Date()
            knownDevices[index] = entry
            if index != 0 {
                knownDevices.remove(at: index)
                knownDevices.insert(entry, at: 0)
            }
        } else {
            knownDevices.removeAll { $0.device.matchKey == device.matchKey }
            knownDevices.insert(KnownDevice(device: device, volume: clamped), at: 0)
            if knownDevices.count > 30 { knownDevices.removeLast(knownDevices.count - 30) }
        }
        scheduleSave()
    }

    /// Позначити пристрій як щойно використаний, не змінюючи збережену гучність.
    func markUsed(_ device: AudioDevice, currentVolume: Float) {
        remember(device, volume: savedVolume(for: device) ?? currentVolume)
    }

    func forget(_ deviceId: String) {
        knownDevices.removeAll { $0.id == deviceId }
        scheduleSave()
    }

    func forgetAll() {
        knownDevices.removeAll()
        scheduleSave()
    }

    // MARK: - Night mode

    func refreshNightMode() {
        let active = config.isNightTime()
        guard active != isNightModeActive else {
            if active { AudioEngine.shared.enforceVolumeLimit() }
            return
        }
        isNightModeActive = active
        if active { AudioEngine.shared.enforceVolumeLimit() }
    }

    // MARK: - Persistence

    private func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: configKey)
        }
    }

    private static func loadConfig(key: String) -> SafeVolumeConfig {
        guard let data = UserDefaults.standard.data(forKey: key),
              let saved = try? JSONDecoder().decode(SafeVolumeConfig.self, from: data) else {
            return SafeVolumeConfig()
        }
        return saved
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled, let self else { return }
            if let data = try? JSONEncoder().encode(self.knownDevices) {
                UserDefaults.standard.set(data, forKey: self.devicesKey)
            }
        }
    }

    private func loadDevices() -> [KnownDevice] {
        if let data = UserDefaults.standard.data(forKey: devicesKey),
           let saved = try? JSONDecoder().decode([KnownDevice].self, from: data) {
            return saved.sorted { $0.lastUsed > $1.lastUsed }
        }
        return migrateLegacyHistory()
    }

    /// Переносить історію зі старого формату (до перероблення) та прибирає зайві ключі.
    private func migrateLegacyHistory() -> [KnownDevice] {
        struct LegacyEntry: Decodable {
            let deviceId: String
            let deviceName: String
            let volume: Float
            let timestamp: Date
        }
        let defaults = UserDefaults.standard
        defer {
            defaults.removeObject(forKey: "DeviceHistories")
            defaults.removeObject(forKey: "Castlie_LastConnectedBluetoothDevice")
        }
        guard let data = defaults.data(forKey: "DeviceHistories"),
              let legacy = try? JSONDecoder().decode([LegacyEntry].self, from: data) else {
            return []
        }

        let iPhoneNames: Set<String> = ["iphone", "цей iphone", "speaker", "динамік", "receiver"]
        var result: [KnownDevice] = []
        for entry in legacy.sorted(by: { $0.timestamp > $1.timestamp }) {
            if entry.deviceId.hasPrefix("mac_") || entry.deviceId.hasPrefix("iphone_") { continue }
            let key = AudioDevice.matchKey(entry.deviceName)
            let device: AudioDevice
            if entry.deviceId == AudioDevice.iPhone.id || iPhoneNames.contains(key) {
                device = .iPhone
            } else {
                device = AudioDevice(
                    id: entry.deviceId,
                    name: entry.deviceName,
                    type: AudioDevice.guessType(fromName: entry.deviceName, isAirPlay: false),
                    connection: .bluetooth
                )
            }
            guard !result.contains(where: { $0.id == device.id || $0.device.matchKey == device.matchKey }) else { continue }
            result.append(KnownDevice(device: device, volume: entry.volume, lastUsed: entry.timestamp))
        }
        if let data = try? JSONEncoder().encode(result) {
            defaults.set(data, forKey: devicesKey)
        }
        return result
    }
}
