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
    
    /// Визначити рівень безпеки для заданої гучності
    func safetyLevel(for volume: Float) -> SafetyLevel {
        let effectiveMax = config.effectiveMaxVolume
        if volume <= effectiveMax * 0.7 {
            return .safe
        } else if volume <= effectiveMax {
            return .warning
        } else {
            return .danger
        }
    }
    
    /// Обмежити гучність з урахуванням налаштувань
    func clampVolume(_ volume: Float) -> Float {
        return min(volume, config.effectiveMaxVolume)
    }
    
    /// Отримати рекомендовану початкову гучність для пристрою
    func recommendedVolume(for device: AudioDevice) -> Float {
        // Шукаємо в історії останнє підключення до цього пристрою
        if let lastEntry = deviceHistories
            .filter({ $0.deviceId == device.id })
            .sorted(by: { $0.timestamp > $1.timestamp })
            .first {
            return clampVolume(lastEntry.volume)
        }
        
        // Якщо історії немає — повертаємо безпечне значення
        return clampVolume(0.3) // 30% за замовчуванням
    }
    
    // MARK: - Device History
    
    /// Зберегти запис про підключення
    func recordConnection(deviceId: String, deviceName: String, volume: Float) {
        let entry = DeviceHistoryEntry(
            deviceId: deviceId,
            deviceName: deviceName,
            volume: volume,
            wasNightMode: config.isNightModeActive
        )
        deviceHistories.append(entry)
        
        // Тримаємо максимум 100 записів
        if deviceHistories.count > 100 {
            deviceHistories = Array(deviceHistories.suffix(100))
        }
        
        saveHistories()
    }
    
    /// Отримати останню відому гучність для пристрою
    func lastKnownVolume(for deviceId: String) -> Float? {
        deviceHistories
            .filter { $0.deviceId == deviceId }
            .sorted { $0.timestamp > $1.timestamp }
            .first?.volume
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
            deviceHistories = saved
        }
    }
}
