import Foundation
import SwiftUI

@Observable
@MainActor
class SafeVolumeManager {
    static let shared = SafeVolumeManager()
    
    var config = SafeVolumeConfig()
    private(set) var deviceHistories: [DeviceHistoryEntry] = []
    
    private let storageKey = "SafeVolumeConfig"
    private let historyKey = "DeviceHistories"
    
    private init() {
        loadConfig()
        loadHistories()
    }
    
    // MARK: - Volume Safety
    
    enum SafetyLevel {
        case safe       // Зелений — гучність ≤ 50%
        case warning    // Жовтий — гучність 50-75%
        case danger     // Червоний — гучність > 75%
        
        var color: Color {
            switch self {
            case .safe: return Color(hex: "34C759")
            case .warning: return Color(hex: "FFD60A")
            case .danger: return Color(hex: "FF3B30")
            }
        }
        
        var sfSymbol: String {
            switch self {
            case .safe: return "checkmark.shield.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .danger: return "xmark.shield.fill"
            }
        }
        
        var label: String {
            switch self {
            case .safe: return "Безпечний рівень"
            case .warning: return "Підвищена гучність"
            case .danger: return "Небезпечна гучність"
            }
        }
    }
    
    /// Визначити рівень безпеки для заданої гучності (фіксовані пороги)
    func safetyLevel(for volume: Float) -> SafetyLevel {
        if volume <= 0.5 {
            return .safe
        } else if volume <= 0.75 {
            return .warning
        } else {
            return .danger
        }
    }
    
    /// Отримати рекомендовану початкову гучність для пристрою
    func recommendedVolume(for device: AudioDevice) -> Float {
        let cleanName = device.name.trimmingCharacters(in: .whitespaces).lowercased()
        // Шукаємо в історії останнє підключення до цього пристрою (за ID або за назвою)
        if let lastEntry = deviceHistories
            .filter({ $0.deviceId == device.id || $0.deviceName.lowercased() == cleanName })
            .sorted(by: { $0.timestamp > $1.timestamp })
            .first {
            var vol = lastEntry.volume
            if config.isNightModeActive {
                vol = min(vol, config.nightModeMaxVolume)
            }
            return vol
        }
        
        // Безпечні дефолти якщо історії немає
        var defVol: Float = 0.30
        if device.type == .headphones {
            defVol = 0.25
        } else if device.type == .iPhone {
            defVol = 0.35
        } else if device.type == .mac {
            defVol = 0.40
        }
        
        if config.isNightModeActive {
            defVol = min(defVol, config.nightModeMaxVolume)
        }
        return defVol
    }
    
    // MARK: - Device History
    
    /// Оновити збережену гучність для поточного пристрою
    func updateDeviceVolume(deviceId: String, deviceName: String, volume: Float) {
        let cleanName = deviceName.trimmingCharacters(in: .whitespaces)
        guard !cleanName.isEmpty else { return }
        let clamped = max(0, min(1, volume))
        
        if let idx = deviceHistories.firstIndex(where: {
            $0.deviceId == deviceId || $0.deviceName.lowercased() == cleanName.lowercased()
        }) {
            let old = deviceHistories[idx]
            deviceHistories[idx] = DeviceHistoryEntry(
                deviceId: deviceId.isEmpty ? old.deviceId : deviceId,
                deviceName: cleanName,
                volume: clamped,
                wasNightMode: config.isNightModeActive
            )
            saveHistories()
        } else {
            recordConnection(deviceId: deviceId, deviceName: cleanName, volume: clamped)
        }
    }
    
    /// Зберегти запис про підключення без дублювання
    func recordConnection(deviceId: String, deviceName: String, volume: Float) {
        let cleanName = deviceName.trimmingCharacters(in: .whitespaces)
        guard !cleanName.isEmpty else { return }
        let clamped = max(0, min(1, volume))
        
        // Видаляємо всі попередні записи для цього ж пристрою (за ID або за назвою)
        deviceHistories.removeAll {
            $0.deviceId == deviceId || $0.deviceName.lowercased() == cleanName.lowercased()
        }
        
        let entry = DeviceHistoryEntry(
            deviceId: deviceId,
            deviceName: cleanName,
            volume: clamped,
            wasNightMode: config.isNightModeActive
        )
        // Вставляємо оновлений запис на початок
        deviceHistories.insert(entry, at: 0)
        
        // Тримаємо максимум 50 записів
        if deviceHistories.count > 50 {
            deviceHistories = Array(deviceHistories.prefix(50))
        }
        
        saveHistories()
    }
    
    /// Видалити збережений пристрій з історії
    func removeDevice(deviceId: String) {
        deviceHistories.removeAll { $0.deviceId == deviceId }
        saveHistories()
        HapticFeedbackService.light()
    }
    
    /// Отримати останню відому гучність для пристрою
    func lastKnownVolume(for deviceId: String) -> Float? {
        deviceHistories
            .filter { $0.deviceId == deviceId }
            .sorted { $0.timestamp > $1.timestamp }
            .first?.volume
    }
    
    /// Отримати останню відому гучність за назвою пристрою
    func lastKnownVolume(forDeviceName name: String) -> Float? {
        let clean = name.trimmingCharacters(in: .whitespaces).lowercased()
        return deviceHistories
            .filter { $0.deviceName.lowercased() == clean }
            .sorted { $0.timestamp > $1.timestamp }
            .first?.volume
    }
    
    /// Отримати останню відому гучність для моделі AudioDevice
    func lastKnownVolume(for device: AudioDevice) -> Float? {
        if let byId = lastKnownVolume(for: device.id) {
            return byId
        }
        return lastKnownVolume(forDeviceName: device.name)
    }
    
    // MARK: - Persistence
    
    func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func loadConfig() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(SafeVolumeConfig.self, from: data) {
            config = saved
        }
    }
    
    private func saveHistories() {
        if let data = try? JSONEncoder().encode(deviceHistories) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }
    
    private func loadHistories() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let saved = try? JSONDecoder().decode([DeviceHistoryEntry].self, from: data) {
            // Очищення старих дублікатів за назвою пристрою
            var seen = Set<String>()
            var clean: [DeviceHistoryEntry] = []
            for entry in saved.sorted(by: { $0.timestamp > $1.timestamp }) {
                let key = entry.deviceName.trimmingCharacters(in: .whitespaces).lowercased()
                if !seen.contains(key) {
                    seen.insert(key)
                    clean.append(entry)
                }
            }
            deviceHistories = clean
            saveHistories()
        }
    }
}
