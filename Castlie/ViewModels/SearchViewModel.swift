import Foundation
import Observation

@Observable
@MainActor
class SearchViewModel {
    var searchText = ""
    var results: [Track] = []
    var recentTracks: [Track] = []
    var isSearching = false
    var errorMessage: String?
    
    private let api = SpotifyAPIService.shared
    private var searchTask: Task<Void, Never>?
    private let recentSearchesKey = "RecentSearchesTracks"
    
    init() {
        loadRecentTracks()
    }
    
    /// Завантажити історію останніх треків з пошуку
    func loadRecentTracks() {
        guard let data = UserDefaults.standard.data(forKey: recentSearchesKey),
              let tracks = try? JSONDecoder().decode([Track].self, from: data) else {
            return
        }
        self.recentTracks = tracks
    }
    
    /// Додати трек в історію останнього пошуку
    func addRecentTrack(_ track: Track) {
        var updated = recentTracks.filter { $0.id != track.id }
        updated.insert(track, at: 0)
        if updated.count > 30 {
            updated = Array(updated.prefix(30))
        }
        recentTracks = updated
        saveRecentTracks()
    }
    
    /// Видалити конкретний трек з останнього пошуку
    func removeRecentTrack(_ track: Track) {
        recentTracks.removeAll { $0.id == track.id }
        saveRecentTracks()
        HapticFeedbackService.light()
    }
    
    /// Очистити всю історію останнього пошуку
    func clearRecentTracks() {
        recentTracks.removeAll()
        saveRecentTracks()
        HapticFeedbackService.light()
    }
    
    private func saveRecentTracks() {
        if let data = try? JSONEncoder().encode(recentTracks) {
            UserDefaults.standard.set(data, forKey: recentSearchesKey)
        }
    }
    
    /// Виконати пошук з debounce
    func performSearch() {
        // Скасувати попередній пошук
        searchTask?.cancel()
        
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else {
            results = []
            return
        }
        
        // Debounce: чекаємо 0.5 секунди
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000)  // 0.5с
            
            guard !Task.isCancelled else { return }
            
            isSearching = true
            errorMessage = nil
            
            do {
                results = try await api.searchTracks(query: query)
            } catch {
                if !Task.isCancelled {
                    errorMessage = error.localizedDescription
                }
            }
            
            isSearching = false
        }
    }
}
