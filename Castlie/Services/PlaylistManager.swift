import Foundation
import Observation

@Observable
@MainActor
class PlaylistManager {
    static let shared = PlaylistManager()
    
    var playlists: [Playlist] = []
    var likedTracks: [Track] = [] {
        didSet {
            likedTrackIds = Set(likedTracks.map(\.id))
        }
    }
    private(set) var likedTrackIds: Set<String> = []
    
    private let playlistsKey = "Castlie_Playlists"
    private let likedTracksKey = "Castlie_LikedTracks"
    
    private init() {
        loadData()
        ensureInitialData()
    }
    
    // MARK: - Likes / Favorites
    
    /// Перевіряє, чи трек вподобаний (O(1) швидкий пошук через Set)
    func isLiked(track: Track) -> Bool {
        likedTrackIds.contains(track.id)
    }
    
    /// Додати або прибрати трек з улюблених
    func toggleLike(track: Track) {
        if let index = likedTracks.firstIndex(where: { $0.id == track.id }) {
            likedTracks.remove(at: index)
        } else {
            likedTracks.insert(track, at: 0)
        }
        saveLikedTracks()
        HapticFeedbackService.light()
    }
    
    // MARK: - Playlist Operations
    
    /// Створити новий плейлист
    @discardableResult
    func createPlaylist(name: String, icon: String = "music.note.list") -> Playlist {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = trimmed.isEmpty ? "Новий плейлист" : trimmed
        let playlist = Playlist(name: finalName, tracks: [], customIcon: icon)
        playlists.insert(playlist, at: 0)
        savePlaylists()
        HapticFeedbackService.success()
        return playlist
    }
    
    /// Видалити плейлист
    func deletePlaylist(id: UUID) {
        playlists.removeAll(where: { $0.id == id })
        savePlaylists()
        HapticFeedbackService.medium()
    }
    
    /// Додати трек до плейлиста
    func addTrack(_ track: Track, to playlistId: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else { return }
        if !playlists[index].tracks.contains(where: { $0.id == track.id }) {
            playlists[index].tracks.append(track)
            savePlaylists()
            HapticFeedbackService.success()
        }
    }
    
    /// Видалити трек з плейлиста
    func removeTrack(trackId: String, from playlistId: UUID) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else { return }
        playlists[index].tracks.removeAll(where: { $0.id == trackId })
        savePlaylists()
        HapticFeedbackService.light()
    }
    
    // MARK: - Persistence
    
    private func savePlaylists() {
        if let data = try? JSONEncoder().encode(playlists) {
            UserDefaults.standard.set(data, forKey: playlistsKey)
        }
    }
    
    private func saveLikedTracks() {
        if let data = try? JSONEncoder().encode(likedTracks) {
            UserDefaults.standard.set(data, forKey: likedTracksKey)
        }
    }
    
    private func loadData() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: playlistsKey),
           let saved = try? decoder.decode([Playlist].self, from: data) {
            playlists = saved
        }
        
        if let data = UserDefaults.standard.data(forKey: likedTracksKey),
           let saved = try? decoder.decode([Track].self, from: data) {
            likedTracks = saved
        }
    }
    
    private func ensureInitialData() {
        // Якщо плейлистів ще немає, створюємо стартовий "Мій мікс"
        if playlists.isEmpty {
            playlists = [
                Playlist(name: "Мій мікс", tracks: [], customIcon: "sparkles")
            ]
            savePlaylists()
        }
    }
}
