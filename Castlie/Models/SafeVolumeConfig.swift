import Foundation

struct SafeVolumeConfig: Codable, Equatable {
    var isFadeInEnabled: Bool = true
    var fadeInDuration: Double = 2.0        // Секунди (0.5 - 5.0)
    var maxVolumeThreshold: Float = 0.4     // 40% максимальний поріг при підключенні
    var isNightModeEnabled: Bool = false
    var nightModeStartHour: Int = 22        // 22:00
    var nightModeEndHour: Int = 8           // 08:00
    var nightModeMaxVolume: Float = 0.3     // 30% максимум у нічному режимі
    var requireConfirmation: Bool = true    // Показувати діалог підтвердження
    
    /// Перевіряє, чи зараз активний нічний режим
    var isNightModeActive: Bool {
        guard isNightModeEnabled else { return false }
        let hour = Calendar.current.component(.hour, from: Date())
        if nightModeStartHour > nightModeEndHour {
            // Переходить через опівніч: наприклад 22:00 - 08:00
            return hour >= nightModeStartHour || hour < nightModeEndHour
        } else {
            return hour >= nightModeStartHour && hour < nightModeEndHour
        }
    }
    
    /// Максимальна дозволена гучність з урахуванням усіх налаштувань
    var effectiveMaxVolume: Float {
        if isNightModeActive {
            return min(maxVolumeThreshold, nightModeMaxVolume)
        }
        return maxVolumeThreshold
    }
}
