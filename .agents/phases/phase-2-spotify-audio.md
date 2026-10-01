# Фаза 2: Spotify API та Аудіо-движок

## Мета
Реалізувати інтеграцію з Spotify Web API (автентифікація, пошук, отримання треків) та аудіо-движок для відтворення 30-секундних прев'ю. Після цієї фази додаток повинен вміти отримувати треки з Spotify та програвати їхні прев'ю.

---

## КРИТИЧНО ВАЖЛИВО: Spotify API

### Як працює Spotify Web API
Spotify Web API — це REST API, яке працює по HTTP. Ми використовуємо **Client Credentials Flow** — це найпростіший спосіб автентифікації, який НЕ вимагає логіну користувача Spotify.

### Client Credentials Flow (покроково):
1. Ми надсилаємо POST-запит на `https://accounts.spotify.com/api/token`
2. В тілі запиту передаємо `client_id` і `client_secret` (отримуємо з Spotify Developer Dashboard)
3. У відповідь отримуємо `access_token` (дійсний 1 годину)
4. Цей `access_token` додаємо в заголовок `Authorization: Bearer {token}` до кожного API-запиту

### Обмеження Client Credentials Flow:
- НЕ можна отримати персональні дані користувача
- НЕ можна керувати відтворенням у додатку Spotify
- МОЖНА: шукати треки, отримувати метадані, прев'ю, обкладинки, рекомендації, нові релізи

### Як отримати Client ID та Client Secret:
1. Зайти на https://developer.spotify.com/dashboard
2. Натиснути "Create app"
3. Назва: "Castlie", Redirect URI: `http://localhost` (не використовуємо, але поле обов'язкове)
4. Зберегти Client ID та Client Secret

---

## Таск 2.1: Spotify Models

### Файл: `Models/SpotifyModels.swift`

Ці моделі відображають JSON-відповіді Spotify API. Вони потрібні для декодування через `JSONDecoder`.

**УВАГА**: Назви полів ПОВИННІ точно збігатися з ключами в JSON від Spotify, або використовувати `CodingKeys`. Spotify використовує `snake_case`, а Swift — `camelCase`, тому потрібен `keyDecodingStrategy = .convertFromSnakeCase`.

```swift
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
```

---

## Таск 2.2: SpotifyAuthService — Автентифікація

### Файл: `Services/SpotifyAuthService.swift`

**УВАГА**:
- Токен дійсний 1 годину (`expiresIn: 3600`)
- Потрібно кешувати токен і оновлювати його коли він протухне
- `client_id` та `client_secret` зберігати в коді (для лабораторної це ОК, для продакшну — KeyChain)
- Заголовок `Content-Type` ОБОВ'ЯЗКОВО має бути `application/x-www-form-urlencoded` (НЕ JSON!)
- Заголовок `Authorization` для token-запиту — це Base64-кодований рядок `client_id:client_secret`

```swift
import Foundation

@Observable
@MainActor
class SpotifyAuthService {
    static let shared = SpotifyAuthService()
    
    // ЗАМІНИТИ НА СВОЇ ЗНАЧЕННЯ з https://developer.spotify.com/dashboard
    private let clientId = "YOUR_CLIENT_ID"
    private let clientSecret = "YOUR_CLIENT_SECRET"
    
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
```

---

## Таск 2.3: SpotifyAPIService — Запити до API

### Файл: `Services/SpotifyAPIService.swift`

**УВАГА**:
- Кожен запит до API ПОТРЕБУЄ заголовок `Authorization: Bearer {access_token}`
- Якщо отримуємо 401 — токен протух, потрібно оновити
- `keyDecodingStrategy = .convertFromSnakeCase` потрібен для ВСІХ decoder'ів
- Spotify API повертає максимум 50 результатів за запит (параметр `limit`)

```swift
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
        
        // Фільтруємо треки без прев'ю (вони нам не потрібні)
        return response.tracks?.items
            .filter { $0.previewUrl != nil }
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
            .filter { $0.previewUrl != nil }
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
    /// Доступні жанри: pop, rock, hip-hop, electronic, jazz, classical, r-n-b, indie, metal, latin
    func getRecommendations(genres: [String], limit: Int = 20) async throws -> [Track] {
        let genresString = genres.joined(separator: ",")
        let urlString = "\(baseURL)/recommendations?seed_genres=\(genresString)&limit=\(limit)"
        
        let data = try await makeRequest(urlString: urlString)
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(SpotifyRecommendationsResponse.self, from: data)
        
        return response.tracks
            .filter { $0.previewUrl != nil }
            .map { $0.toTrack() }
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
```

---

## Таск 2.4: AudioEngine — Аудіо-движок

### Файл: `Services/AudioEngine.swift`

**УВАГА: КРИТИЧНІ ПРАВИЛА для аудіо на iOS**:
1. Використовувати `AVPlayer` (НЕ `AVAudioPlayer`) для стрімінгу URL-файлів (Spotify прев'ю)
2. `AVAudioPlayer` працює ТІЛЬКИ з локальними файлами, а наші треки — це URL з інтернету
3. Налаштувати `AVAudioSession` категорію `.playback` щоб звук грав у фоні та через зовнішні пристрої
4. Підписатися на `.AVPlayerItemDidPlayToEndTime` щоб знати коли трек закінчився
5. Використовувати `addPeriodicTimeObserver` для оновлення прогресу
6. Для fade-in: змінювати `player.volume` поступово через Timer або async/await

```swift
import AVFoundation
import MediaPlayer
import Observation

@Observable
@MainActor
class AudioEngine {
    static let shared = AudioEngine()
    
    // MARK: - State
    private(set) var isPlaying = false
    private(set) var currentTrack: Track?
    private(set) var currentTime: Double = 0       // Поточна позиція в секундах
    private(set) var duration: Double = 0           // Тривалість в секундах
    private(set) var volume: Float = 0.5            // Поточна гучність 0.0 - 1.0
    
    var queue: [Track] = []                         // Черга треків
    private(set) var currentIndex: Int = 0
    
    // MARK: - Private
    private var player: AVPlayer?
    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?
    
    private init() {
        setupAudioSession()
    }
    
    // MARK: - Audio Session Setup
    
    /// Налаштування аудіо-сесії — ОБОВ'ЯЗКОВО для відтворення через зовнішні пристрої
    private func setupAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            // .playback — звук грає навіть коли екран заблокований
            // та правильно маршрутизується на AirPlay/Bluetooth
            try session.setCategory(.playback, mode: .default, options: [])
            try session.setActive(true)
        } catch {
            print("AudioSession setup error: \(error)")
        }
    }
    
    // MARK: - Playback Controls
    
    /// Почати відтворення треку
    func play(track: Track) {
        guard let previewURL = track.previewURL else {
            print("No preview URL for track: \(track.name)")
            return
        }
        
        // Зупиняємо попередній трек
        stop()
        
        currentTrack = track
        let playerItem = AVPlayerItem(url: previewURL)
        player = AVPlayer(playerItem: playerItem)
        player?.volume = volume
        
        // Підписка на закінчення треку
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.playNext()
            }
        }
        
        // Підписка на оновлення прогресу (кожні 0.1 секунди)
        timeObserver = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds
                if let duration = self?.player?.currentItem?.duration.seconds,
                   !duration.isNaN {
                    self?.duration = duration
                }
            }
        }
        
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }
    
    /// Відтворити список треків починаючи з індексу
    func play(tracks: [Track], startIndex: Int = 0) {
        queue = tracks
        currentIndex = startIndex
        if startIndex < tracks.count {
            play(track: tracks[startIndex])
        }
    }
    
    /// Пауза / Продовження
    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }
    
    /// Зупинити відтворення повністю
    func stop() {
        player?.pause()
        
        if let timeObserver {
            player?.removeTimeObserver(timeObserver)
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        
        timeObserver = nil
        endObserver = nil
        player = nil
        isPlaying = false
        currentTime = 0
        duration = 0
    }
    
    /// Наступний трек
    func playNext() {
        guard !queue.isEmpty else { return }
        currentIndex = (currentIndex + 1) % queue.count
        play(track: queue[currentIndex])
    }
    
    /// Попередній трек
    func playPrevious() {
        guard !queue.isEmpty else { return }
        // Якщо пройшло більше 3 секунд — перемотати на початок
        if currentTime > 3 {
            seek(to: 0)
        } else {
            currentIndex = (currentIndex - 1 + queue.count) % queue.count
            play(track: queue[currentIndex])
        }
    }
    
    /// Перемотка на позицію (секунди)
    func seek(to seconds: Double) {
        let time = CMTime(seconds: seconds, preferredTimescale: 600)
        player?.seek(to: time)
    }
    
    /// Встановити гучність (0.0 - 1.0)
    func setVolume(_ newVolume: Float) {
        volume = max(0, min(1, newVolume))
        player?.volume = volume
    }
    
    // MARK: - Now Playing Info (Lock Screen)
    
    /// Оновити інформацію на екрані блокування
    private func updateNowPlayingInfo() {
        guard let track = currentTrack else { return }
        
        var info = [String: Any]()
        info[MPMediaItemPropertyTitle] = track.name
        info[MPMediaItemPropertyArtist] = track.artistName
        info[MPMediaItemPropertyAlbumTitle] = track.albumName
        info[MPMediaItemPropertyPlaybackDuration] = track.durationSeconds
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        info[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }
    
    /// Прогрес відтворення (0.0 - 1.0)
    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }
    
    /// Форматований час "0:15 / 0:30"
    var formattedTime: String {
        let current = formatTime(currentTime)
        let total = formatTime(duration)
        return "\(current) / \(total)"
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
```

---

## Таск 2.5: FadeInEngine — Плавне наростання гучності

### Файл: `Services/FadeInEngine.swift`

**Як працює Fade-in**:
1. При підключенні до нового пристрою гучність встановлюється на 0
2. Поступово підвищується до цільового рівня за вказаний час
3. Використовується `Task` з `Task.sleep` для плавної зміни

```swift
import Foundation

@Observable
@MainActor
class FadeInEngine {
    static let shared = FadeInEngine()
    
    private(set) var isFadingIn = false
    private(set) var fadeProgress: Float = 0  // 0.0 - 1.0
    private var fadeTask: Task<Void, Never>?
    
    private init() {}
    
    /// Запустити fade-in від 0 до targetVolume за duration секунд
    /// - Parameters:
    ///   - targetVolume: Цільова гучність (0.0 - 1.0)
    ///   - duration: Тривалість fade-in у секундах
    ///   - audioEngine: Посилання на аудіо-движок
    func startFadeIn(targetVolume: Float, duration: Double, audioEngine: AudioEngine) {
        // Скасувати попередній fade-in якщо він ще йде
        cancelFadeIn()
        
        isFadingIn = true
        fadeProgress = 0
        
        let steps = Int(duration * 20)  // 20 кроків на секунду — плавно
        let volumeStep = targetVolume / Float(steps)
        let intervalNanoseconds = UInt64(duration / Double(steps) * 1_000_000_000)
        
        audioEngine.setVolume(0)
        
        fadeTask = Task {
            for step in 1...steps {
                guard !Task.isCancelled else { break }
                
                let newVolume = volumeStep * Float(step)
                audioEngine.setVolume(min(newVolume, targetVolume))
                fadeProgress = Float(step) / Float(steps)
                
                try? await Task.sleep(nanoseconds: intervalNanoseconds)
            }
            
            // Гарантуємо що кінцева гучність точна
            audioEngine.setVolume(targetVolume)
            fadeProgress = 1.0
            isFadingIn = false
        }
    }
    
    /// Скасувати fade-in
    func cancelFadeIn() {
        fadeTask?.cancel()
        fadeTask = nil
        isFadingIn = false
        fadeProgress = 0
    }
}
```

---

## Таск 2.6: SafeVolumeManager — Логіка безпечного перемикання

### Файл: `Services/SafeVolumeManager.swift`

**Це КЛЮЧОВИЙ сервіс додатку** — він вирішує ту саму проблему, яку описано в дослідженні.

```swift
import Foundation
import SwiftUI

@Observable
@MainActor
class SafeVolumeManager {
    static let shared = SafeVolumeManager()
    
    var config = SafeVolumeConfig()
    private(set) var deviceHistories: [DeviceHistoryEntry] = []
    
    private let storageKey = "SafeVolumeConfig"
    private let historyKey = "DeviceHistories"
    
    private init() {
        loadConfig()
        loadHistories()
    }
    
    // MARK: - Volume Safety
    
    enum SafetyLevel {
        case safe       // Зелений — гучність ≤ 50%
        case warning    // Жовтий — гучність 50-75%
        case danger     // Червоний — гучність > 75%
        
        var color: Color {
            switch self {
            case .safe: return ThemeManager.shared.safeColor
            case .warning: return ThemeManager.shared.warningColor
            case .danger: return ThemeManager.shared.dangerColor
            }
        }
        
        var sfSymbol: String {
            switch self {
            case .safe: return "checkmark.shield.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .danger: return "xmark.shield.fill"
            }
        }
        
        var label: String {
            switch self {
            case .safe: return "Безпечний рівень"
            case .warning: return "Підвищена гучність"
            case .danger: return "Небезпечна гучність"
            }
        }
    }
    
    /// Визначити рівень безпеки для заданої гучності
    func safetyLevel(for volume: Float) -> SafetyLevel {
        let effectiveMax = config.effectiveMaxVolume
        if volume <= effectiveMax * 0.7 {
            return .safe
        } else if volume <= effectiveMax {
            return .warning
        } else {
            return .danger
        }
    }
    
    /// Обмежити гучність з урахуванням налаштувань
    func clampVolume(_ volume: Float) -> Float {
        return min(volume, config.effectiveMaxVolume)
    }
    
    /// Отримати рекомендовану початкову гучність для пристрою
    func recommendedVolume(for device: AudioDevice) -> Float {
        // Шукаємо в історії останнє підключення до цього пристрою
        if let lastEntry = deviceHistories
            .filter({ $0.deviceId == device.id })
            .sorted(by: { $0.timestamp > $1.timestamp })
            .first {
            return clampVolume(lastEntry.volume)
        }
        
        // Якщо історії немає — повертаємо безпечне значення
        return clampVolume(0.3) // 30% за замовчуванням
    }
    
    // MARK: - Device History
    
    /// Зберегти запис про підключення
    func recordConnection(deviceId: String, deviceName: String, volume: Float) {
        let entry = DeviceHistoryEntry(
            deviceId: deviceId,
            deviceName: deviceName,
            volume: volume,
            wasNightMode: config.isNightModeActive
        )
        deviceHistories.append(entry)
        
        // Тримаємо максимум 100 записів
        if deviceHistories.count > 100 {
            deviceHistories = Array(deviceHistories.suffix(100))
        }
        
        saveHistories()
    }
    
    /// Отримати останню відому гучність для пристрою
    func lastKnownVolume(for deviceId: String) -> Float? {
        deviceHistories
            .filter { $0.deviceId == deviceId }
            .sorted { $0.timestamp > $1.timestamp }
            .first?.volume
    }
    
    // MARK: - Persistence
    
    func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
    
    private func loadConfig() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(SafeVolumeConfig.self, from: data) {
            config = saved
        }
    }
    
    private func saveHistories() {
        if let data = try? JSONEncoder().encode(deviceHistories) {
            UserDefaults.standard.set(data, forKey: historyKey)
        }
    }
    
    private func loadHistories() {
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let saved = try? JSONDecoder().decode([DeviceHistoryEntry].self, from: data) {
            deviceHistories = saved
        }
    }
}
```

---

## Таск 2.7: HapticFeedbackService

### Файл: `Services/HapticFeedbackService.swift`

```swift
import UIKit

enum HapticFeedbackService {
    /// Легкий тактильний відгук (для натискання кнопок)
    static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    /// Середній тактильний відгук (для підключення пристрою)
    static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    /// Важкий тактильний відгук (для попередження про гучність)
    static func heavy() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }
    
    /// Успіх (для успішного підключення)
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    /// Попередження (для високої гучності)
    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
    
    /// Помилка
    static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
}
```

---

## Чеклист Фази 2

- [ ] `SpotifyModels.swift` — всі моделі для API відповідей
- [ ] `SpotifyAuthService.swift` — Client Credentials flow працює
- [ ] `SpotifyAPIService.swift` — пошук треків повертає результати
- [ ] `SpotifyAPIService.swift` — нові релізи завантажуються
- [ ] `SpotifyAPIService.swift` — рекомендації працюють
- [ ] `AudioEngine.swift` — може відтворити трек по URL
- [ ] `AudioEngine.swift` — play/pause/stop працюють
- [ ] `AudioEngine.swift` — next/previous працюють
- [ ] `AudioEngine.swift` — прогрес оновлюється в реальному часі
- [ ] `AudioEngine.swift` — гучність змінюється
- [ ] `FadeInEngine.swift` — плавне наростання працює
- [ ] `SafeVolumeManager.swift` — safetyLevel повертає правильні рівні
- [ ] `SafeVolumeManager.swift` — історія зберігається/завантажується
- [ ] `SafeVolumeManager.swift` — Night Mode визначає час правильно
- [ ] `HapticFeedbackService.swift` — компілюється
- [ ] Всі файли компілюються без помилок
