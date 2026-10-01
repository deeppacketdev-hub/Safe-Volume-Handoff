import Foundation
import Observation

@Observable
@MainActor
class HomeViewModel {
    var newReleases: [SpotifyAlbum] = []
    var recommendations: [Track] = []
    var isLoading = false
    var errorMessage: String?
    
    private let api = SpotifyAPIService.shared
    
    /// Завантажити весь контент для головної
    func loadContent() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // Завантажуємо паралельно через async let
            async let releasesTask = api.getNewReleases(limit: 10)
            async let recsTask = api.getRecommendations(genres: ["pop", "rock"], limit: 20)
            
            newReleases = try await releasesTask
            recommendations = try await recsTask
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}
