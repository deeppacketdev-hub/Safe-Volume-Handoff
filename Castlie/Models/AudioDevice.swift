import Foundation

enum DeviceType: String, Codable, CaseIterable, Sendable {
    case iPhone = "iphone"
    case headphones
    case speaker
    case tv
    case mac
    case car

    var displayName: String {
        switch self {
        case .iPhone: "iPhone"
        case .headphones: "Навушники"
        case .speaker: "Колонка"
        case .tv: "Телевізор"
        case .mac: "Mac"
        case .car: "Автомобіль"
        }
    }
}

/// Аудіовихід: вбудований динамік, Bluetooth, AirPlay, дротовий або Mac через Castlie Connect.
struct AudioDevice: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let name: String
    let type: DeviceType
    let connection: Connection

    enum Connection: String, Codable, Sendable {
        case builtIn
        case bluetooth
        case airPlay
        case wired
        case carPlay
        case castlieConnect

        var label: String {
            switch self {
            case .builtIn: "Вбудований динамік"
            case .bluetooth: "Bluetooth"
            case .airPlay: "AirPlay"
            case .wired: "Дротове"
            case .carPlay: "CarPlay"
            case .castlieConnect: "Castlie Connect"
            }
        }
    }

    static let iPhone = AudioDevice(id: "builtin-speaker", name: "iPhone", type: .iPhone, connection: .builtIn)

    var isBuiltIn: Bool { id == AudioDevice.iPhone.id }

    /// Нормалізована назва для порівняння пристроїв без урахування регістру та пробілів.
    var matchKey: String { AudioDevice.matchKey(name) }

    static func matchKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    func matches(_ other: AudioDevice) -> Bool {
        id == other.id || (!matchKey.isEmpty && matchKey == other.matchKey)
    }

    var symbol: String { AudioDevice.symbol(for: type, name: name) }

    static func symbol(for type: DeviceType, name: String) -> String {
        let lower = name.lowercased()
        switch type {
        case .iPhone:
            return "iphone"
        case .headphones:
            if lower.contains("airpods max") { return "airpods.max" }
            if lower.contains("airpods pro") { return "airpods.pro" }
            if lower.contains("airpods") { return "airpods.gen3" }
            if lower.contains("beats") { return "beats.headphones" }
            if lower.contains("buds") { return "earbuds" }
            return "headphones"
        case .speaker:
            return lower.contains("homepod") ? "homepod.fill" : "hifispeaker.fill"
        case .tv:
            return "tv"
        case .mac:
            return "laptopcomputer"
        case .car:
            return "car.fill"
        }
    }

    /// Визначає тип Bluetooth/AirPlay-пристрою за назвою — iOS не повідомляє клас пристрою.
    static func guessType(fromName name: String, isAirPlay: Bool) -> DeviceType {
        let lower = name.lowercased()
        if isAirPlay {
            if lower.contains("mac") { return .mac }
            if lower.contains("tv") || lower.contains("телевізор") { return .tv }
            return .speaker
        }
        let headphoneHints = [
            "airpod", "headphone", "headset", "buds", "beats", "earphone",
            "wh-", "wf-", "quietcomfort", "freebuds", "jabra", "навушн"
        ]
        return headphoneHints.contains(where: lower.contains) ? .headphones : .speaker
    }
}
