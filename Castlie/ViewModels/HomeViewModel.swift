import Foundation
import Observation

@Observable
@MainActor
final class HomeViewModel {
    private(set) var newReleases: [SpotifyAlbum] = []
    private(set) var recommendations: [Track] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let api = SpotifyAPIService.shared

    var hasContent: Bool { !newReleases.isEmpty || !recommendations.isEmpty }

    /// Розділи вантажаться незалежно: збій одного не ховає інший.
    func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil

        async let releasesResult = Self.capture { try await SpotifyAPIService.shared.getNewReleases(limit: 12) }
        async let tracksResult = Self.capture { try await SpotifyAPIService.shared.getRecommendations(genres: ["pop", "rock"], limit: 20) }

        let (releases, tracks) = await (releasesResult, tracksResult)
        if case .success(let albums) = releases { newReleases = albums }
        if case .success(let items) = tracks { recommendations = items }

        if !hasContent {
            if case .failure(let error) = releases {
                errorMessage = SpotifyError.message(for: error)
            } else if case .failure(let error) = tracks {
                errorMessage = SpotifyError.message(for: error)
            }
        }
        isLoading = false
    }

    private static func capture<T: Sendable>(_ work: @MainActor () async throws -> T) async -> Result<T, Error> {
        do { return .success(try await work()) } catch { return .failure(error) }
    }
}
