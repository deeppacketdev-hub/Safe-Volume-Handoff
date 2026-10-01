import Foundation
import Observation

@Observable
@MainActor
class SearchViewModel {
    var searchText = ""
    var results: [Track] = []
    var isSearching = false
    var errorMessage: String?
    
    private let api = SpotifyAPIService.shared
    private var searchTask: Task<Void, Never>?
    
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
