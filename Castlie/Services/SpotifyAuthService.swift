import Foundation

@Observable
@MainActor
class SpotifyAuthService {
    static let shared = SpotifyAuthService()
    
    private let clientId = "1cbe4690e8b943798c9cffef250c1f23"
    private let clientSecret = "9febd0d9ced94176a800a279bfdcaabe"
    
    private(set) var accessToken: String?
    private var tokenExpirationDate: Date?
    
    private init() {}
    
    /// Чи дійсний поточний токен
    var isTokenValid: Bool {
        guard let token = accessToken, let expiration = tokenExpirationDate else {
            return false
        }
        // Оновлюємо за 60 секунд до закінчення
        return !token.isEmpty && Date() < expiration.addingTimeInterval(-60)
    }
    
    /// Отримати валідний токен (з кешу або новий)
    func getValidToken() async throws -> String {
        if isTokenValid, let token = accessToken {
            return token
        }
        return try await fetchNewToken()
    }
    
    /// Запросити новий токен у Spotify
    private func fetchNewToken() async throws -> String {
        let url = URL(string: "https://accounts.spotify.com/api/token")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        // Content-Type ОБОВ'ЯЗКОВО x-www-form-urlencoded
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Authorization: Basic base64(client_id:client_secret)
        let credentials = "\(clientId):\(clientSecret)"
        let credentialsData = credentials.data(using: .utf8)!
        let base64Credentials = credentialsData.base64EncodedString()
        request.setValue("Basic \(base64Credentials)", forHTTPHeaderField: "Authorization")
        
        // Body
        request.httpBody = "grant_type=client_credentials".data(using: .utf8)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw SpotifyError.authenticationFailed
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let authResponse = try decoder.decode(SpotifyAuthResponse.self, from: data)
        
        self.accessToken = authResponse.accessToken
        self.tokenExpirationDate = Date().addingTimeInterval(TimeInterval(authResponse.expiresIn))
        
        return authResponse.accessToken
    }
}

// MARK: - Errors
enum SpotifyError: LocalizedError {
    case authenticationFailed
    case requestFailed(statusCode: Int)
    case noPreviewAvailable
    case decodingFailed
    
    var errorDescription: String? {
        switch self {
        case .authenticationFailed:
            return "Не вдалося авторизуватися в Spotify"
        case .requestFailed(let code):
            return "Помилка запиту: \(code)"
        case .noPreviewAvailable:
            return "Прев'ю недоступне для цього треку"
        case .decodingFailed:
            return "Помилка обробки даних"
        }
    }
}
