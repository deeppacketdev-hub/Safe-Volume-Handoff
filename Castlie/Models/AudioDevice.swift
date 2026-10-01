import Foundation

enum DeviceType: String, Codable, CaseIterable {
    case iPhone = "iphone"
    case mac = "laptopcomputer"
    case speaker = "hifispeaker.fill"
    case tv = "tv.fill"
    case headphones = "headphones"
    case airplay = "airplayaudio"
    case bluetooth = "wave.3.right"
    
    /// SF Symbol для іконки пристрою
    var sfSymbol: String { rawValue }
    
    /// Назва типу українською
    var displayName: String {
        switch self {
        case .iPhone: return "iPhone"
        case .mac: return "Mac"
        case .speaker: return "Колонка"
        case .tv: return "Телевізор"
        case .headphones: return "Навушники"
        case .airplay: return "AirPlay"
        case .bluetooth: return "Bluetooth"
        }
    }
}

struct AudioDevice: Identifiable, Codable, Hashable {
    let id: String                       // Унікальний ідентифікатор
    let name: String                     // Назва пристрою ("JBL Flip 6")
    let type: DeviceType                 // Тип пристрою
    let connectionType: ConnectionType   // AirPlay / Bluetooth
    var roomName: String?                // Кімната (якщо задано)
    var lastKnownVolume: Float?          // Остання відома гучність (0.0 - 1.0)
    var isConnected: Bool = false        // Чи підключений зараз
    
    enum ConnectionType: String, Codable {
        case airplay = "AirPlay"
        case bluetooth = "Bluetooth"
        case wired = "Дротове"
        case builtIn = "Вбудований"
    }
}
