import SwiftUI
import Observation

@Observable
@MainActor
class ThemeManager {
    // MARK: - Singleton
    static let shared = ThemeManager()
    
    // MARK: - Background Colors
    var primaryBackground = Color(hex: "0A0A0F")
    var secondaryBackground = Color(hex: "1A1A24")
    var cardBackground = Color(hex: "242430")
    
    // MARK: - Text Colors
    var primaryText = Color(hex: "F5F5F7")
    var secondaryText = Color(hex: "8E8E93")
    
    // MARK: - Accent Colors
    var accent = Color(hex: "FF6B35")        // Червоно-оранжевий
    var accentHover = Color(hex: "FF8C42")   // Яскравий оранж
    
    // MARK: - Safety Colors
    var safeColor = Color(hex: "34C759")     // Зелений — безпечний рівень
    var warningColor = Color(hex: "FFD60A")  // Жовтий — увага
    var dangerColor = Color(hex: "FF3B30")   // Червоний — небезпечний
    
    private init() {}
    
    // MARK: - Safety Level
    /// Повертає колір на основі рівня гучності (0.0 — 1.0)
    func colorForVolume(_ volume: Float) -> Color {
        switch volume {
        case 0..<0.5:
            return safeColor
        case 0.5..<0.75:
            return warningColor
        default:
            return dangerColor
        }
    }
}
