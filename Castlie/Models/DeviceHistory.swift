import Foundation

struct DeviceHistoryEntry: Identifiable, Codable {
    let id: UUID
    let deviceId: String
    let deviceName: String
    let volume: Float              // 0.0 - 1.0
    let timestamp: Date
    let wasNightMode: Bool
    
    init(deviceId: String, deviceName: String, volume: Float, wasNightMode: Bool = false) {
        self.id = UUID()
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.volume = volume
        self.timestamp = Date()
        self.wasNightMode = wasNightMode
    }
}
