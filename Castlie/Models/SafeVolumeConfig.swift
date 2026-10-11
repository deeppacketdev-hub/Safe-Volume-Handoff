import Foundation

struct SafeVolumeConfig: Codable, Equatable, Sendable {
    var isFadeInEnabled: Bool = true
    var fadeInDuration: Double = 2.0        // секунди (0.5 – 5.0)
    var isNightModeEnabled: Bool = false
    var nightModeStartHour: Int = 22
    var nightModeEndHour: Int = 8
    var nightModeMaxVolume: Float = 0.3
    var requireConfirmation: Bool = true

    /// Чи потрапляє вказаний момент у нічний інтервал (з підтримкою переходу через північ).
    func isNightTime(_ date: Date = Date()) -> Bool {
        guard isNightModeEnabled else { return false }
        let hour = Calendar.current.component(.hour, from: date)
        if nightModeStartHour == nightModeEndHour { return true }
        if nightModeStartHour > nightModeEndHour {
            return hour >= nightModeStartHour || hour < nightModeEndHour
        }
        return hour >= nightModeStartHour && hour < nightModeEndHour
    }
}
