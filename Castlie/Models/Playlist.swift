import Foundation

struct Playlist: Identifiable, Codable, Hashable, Equatable {
    let id: UUID
    var name: String
    var tracks: [Track]
    let createdAt: Date
    var customIcon: String?
    
    init(id: UUID = UUID(), name: String, tracks: [Track] = [], createdAt: Date = Date(), customIcon: String? = nil) {
        self.id = id
        self.name = name
        self.tracks = tracks
        self.createdAt = createdAt
        self.customIcon = customIcon
    }
    
    var trackCount: Int { tracks.count }
    
    /// Загальна тривалість плейлиста
    var totalDuration: String {
        let total = tracks.reduce(0) { $0 + $1.durationSeconds }
        let minutes = Int(total) / 60
        return "\(minutes) хв"
    }
}
