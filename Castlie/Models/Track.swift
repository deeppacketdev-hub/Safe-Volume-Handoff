import Foundation

struct Track: Identifiable, Codable, Hashable {
    let id: String                    // Spotify track ID
    let name: String                  // Назва треку
    let artistName: String            // Ім'я виконавця
    let albumName: String             // Назва альбому
    let albumImageURL: URL?           // URL обкладинки (від Spotify)
    let previewURL: URL?              // URL 30-секундного прев'ю (від Spotify)
    let durationMs: Int               // Тривалість в мілісекундах
    let popularity: Int               // Популярність (0-100)
    
    /// Тривалість у секундах
    var durationSeconds: Double {
        Double(durationMs) / 1000.0
    }
    
    /// Форматована тривалість "3:24"
    var formattedDuration: String {
        let totalSeconds = Int(durationSeconds)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
