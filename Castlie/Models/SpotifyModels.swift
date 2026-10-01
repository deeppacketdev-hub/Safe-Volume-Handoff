import Foundation

// MARK: - Auth Response
struct SpotifyAuthResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
}

// MARK: - Search Response
struct SpotifySearchResponse: Codable {
    let tracks: SpotifyTracksContainer?
}

struct SpotifyTracksContainer: Codable {
    let items: [SpotifyTrack]
    let total: Int
    let limit: Int
    let offset: Int
}

// MARK: - Track
struct SpotifyTrack: Codable, Identifiable {
    let id: String
    let name: String
    let previewUrl: String?
    let durationMs: Int
    let popularity: Int
    let artists: [SpotifyArtist]
    let album: SpotifyAlbum
    
    /// Конвертує Spotify-трек у нашу уніфіковану модель Track
    func toTrack() -> Track {
        Track(
            id: id,
            name: name,
            artistName: artists.map(\.name).joined(separator: ", "),
            albumName: album.name,
            albumImageURL: album.images.first.flatMap { URL(string: $0.url) },
            previewURL: previewUrl.flatMap { URL(string: $0) },
            durationMs: durationMs,
            popularity: popularity
        )
    }
}

// MARK: - Artist
struct SpotifyArtist: Codable, Identifiable {
    let id: String
    let name: String
}

// MARK: - Album
struct SpotifyAlbum: Codable, Identifiable {
    let id: String
    let name: String
    let images: [SpotifyImage]
    let releaseDate: String?
    var artists: [SpotifyArtist]? = nil
}

// MARK: - Image
struct SpotifyImage: Codable {
    let url: String
    let height: Int?
    let width: Int?
}

// MARK: - New Releases Response
struct SpotifyNewReleasesResponse: Codable {
    let albums: SpotifyAlbumsContainer
}

struct SpotifyAlbumsContainer: Codable {
    let items: [SpotifyAlbum]
}

// MARK: - Categories Response
struct SpotifyCategoriesResponse: Codable {
    let categories: SpotifyCategoriesContainer
}

struct SpotifyCategoriesContainer: Codable {
    let items: [SpotifyCategory]
}

struct SpotifyCategory: Codable, Identifiable {
    let id: String
    let name: String
    let icons: [SpotifyImage]
}

// MARK: - Recommendations Response
struct SpotifyRecommendationsResponse: Codable {
    let tracks: [SpotifyTrack]
}
