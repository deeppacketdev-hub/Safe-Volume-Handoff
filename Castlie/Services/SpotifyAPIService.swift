import Foundation

@Observable
@MainActor
class SpotifyAPIService {
    static let shared = SpotifyAPIService()
    
    private let baseURL = "https://api.spotify.com/v1"
    private let auth = SpotifyAuthService.shared
    
    private init() {}
    
    // MARK: - Search
    
    /// Пошук треків за запитом
    /// - Parameters:
    ///   - query: Текст пошуку (назва треку, виконавець)
    ///   - limit: Кількість результатів (макс. 50)
    /// - Returns: Масив Track
    func searchTracks(query: String, limit: Int = 20) async throws -> [Track] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return [] }
        
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let urlString = "\(baseURL)/search?q=\(encodedQuery)&type=track&limit=\(limit)"
        
        let data = try await makeRequest(urlString: urlString)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(SpotifySearchResponse.self, from: data)
        
        return response.tracks?.items
            .map { $0.toTrack() } ?? []
    }
    
    // MARK: - New Releases
    
    /// Отримати нові релізи
    func getNewReleases(limit: Int = 20) async throws -> [SpotifyAlbum] {
        let urlString = "\(baseURL)/browse/new-releases?limit=\(limit)"
        let data = try await makeRequest(urlString: urlString)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(SpotifyNewReleasesResponse.self, from: data)
        
        return response.albums.items
    }
    
    // MARK: - Album Tracks
    
    /// Отримати треки альбому
    func getAlbumTracks(albumId: String) async throws -> [Track] {
        // Спочатку отримуємо деталі альбому для обкладинки
        let albumURL = "\(baseURL)/albums/\(albumId)"
        let albumData = try await makeRequest(urlString: albumURL)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        
        // Spotify API для album tracks не включає album info в кожному треку,
        // тому отримуємо повний album з треками
        struct AlbumFull: Codable {
            let id: String
            let name: String
            let images: [SpotifyImage]
            let tracks: AlbumTracksContainer
        }
        struct AlbumTracksContainer: Codable {
            let items: [AlbumTrackItem]
        }
        struct AlbumTrackItem: Codable {
            let id: String
            let name: String
            let previewUrl: String?
            let durationMs: Int
            let artists: [SpotifyArtist]
        }
        
        let albumFull = try decoder.decode(AlbumFull.self, from: albumData)
        let albumImageURL = albumFull.images.first.flatMap { URL(string: $0.url) }
        
        return albumFull.tracks.items
            .map { item in
                Track(
                    id: item.id,
                    name: item.name,
                    artistName: item.artists.map(\.name).joined(separator: ", "),
                    albumName: albumFull.name,
                    albumImageURL: albumImageURL,
                    previewURL: item.previewUrl.flatMap { URL(string: $0) },
                    durationMs: item.durationMs,
                    popularity: 0
                )
            }
    }
    
    // MARK: - Recommendations
    
    /// Отримати рекомендації за жанрами
    func getRecommendations(genres: [String], limit: Int = 20) async throws -> [Track] {
        // Spotify API закрив ендпоінт /recommendations (повертає 404),
        // тому отримуємо актуальні топові треки через пошуковий запит
        let query = genres.joined(separator: " OR ")
        return try await searchTracks(query: query.isEmpty ? "top hits" : query, limit: limit)
    }
    
    // MARK: - Private: Make Request
    
    /// Виконати HTTP-запит до Spotify API з авторизацією
    private func makeRequest(urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else {
            throw SpotifyError.requestFailed(statusCode: 0)
        }
        
        let token = try await auth.getValidToken()
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SpotifyError.requestFailed(statusCode: 0)
        }
        
        switch httpResponse.statusCode {
        case 200:
            return data
        case 401:
            // Токен протух — оновлюємо і пробуємо ще раз
            let newToken = try await auth.getValidToken()
            var retryRequest = URLRequest(url: url)
            retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
            let (retryData, retryResponse) = try await URLSession.shared.data(for: retryRequest)
            guard let retryHttp = retryResponse as? HTTPURLResponse, retryHttp.statusCode == 200 else {
                throw SpotifyError.authenticationFailed
            }
            return retryData
        default:
            throw SpotifyError.requestFailed(statusCode: httpResponse.statusCode)
        }
    }
}
