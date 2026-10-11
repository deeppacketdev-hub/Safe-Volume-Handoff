import Foundation

/// Пристрій, до якого вже підключалися, разом з останньою гучністю.
struct KnownDevice: Identifiable, Codable, Hashable, Sendable {
    let id: String
    var name: String
    var type: DeviceType
    var connection: AudioDevice.Connection
    var volume: Float
    var lastUsed: Date

    init(device: AudioDevice, volume: Float, lastUsed: Date = Date()) {
        self.id = device.id
        self.name = device.name
        self.type = device.type
        self.connection = device.connection
        self.volume = volume
        self.lastUsed = lastUsed
    }

    var device: AudioDevice {
        AudioDevice(id: id, name: name, type: type, connection: connection)
    }
}
