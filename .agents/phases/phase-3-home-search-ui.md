# Фаза 3: UI — Головна та Пошук

## Мета
Реалізувати два основні таби: Головна (нові релізи, рекомендації) та Пошук (пошук треків по Spotify). Після цієї фази додаток показує реальний контент з Spotify з обкладинками альбомів.

---

## ВАЖЛИВІ ПРАВИЛА ДЛЯ ВСІХ VIEW

### 1. Кожен View ОБОВ'ЯЗКОВО має мати `#Preview {}` в кінці файлу
```swift
#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
```

### 2. Кольори ТІЛЬКИ з ThemeManager
```swift
// ПРАВИЛЬНО:
ThemeManager.shared.accent
ThemeManager.shared.primaryBackground

// НЕПРАВИЛЬНО:
Color.red
Color(hex: "FF6B35")
Color.orange
```

### 3. Іконки ТІЛЬКИ SF Symbols
```swift
// ПРАВИЛЬНО:
Image(systemName: "magnifyingglass")
Label("Пошук", systemImage: "magnifyingglass")

// НЕПРАВИЛЬНО:
Text("🔍")
Text("🎵")
```

### 4. Фон ЗАВЖДИ темний
```swift
// В кожному основному View:
.background(ThemeManager.shared.primaryBackground.ignoresSafeArea())
```

### 5. AsyncImage для обкладинок Spotify
Обкладинки — це URL-зображення з Spotify. Використовувати `AsyncImage`:
```swift
AsyncImage(url: track.albumImageURL) { image in
    image
        .resizable()
        .aspectRatio(contentMode: .fill)
} placeholder: {
    RoundedRectangle(cornerRadius: 8)
        .fill(ThemeManager.shared.cardBackground)
        .overlay {
            Image(systemName: "music.note")
                .foregroundStyle(ThemeManager.shared.secondaryText)
        }
}
```

### 6. Навігація через NavigationStack (НЕ NavigationView)
`NavigationView` — DEPRECATED починаючи з iOS 16. Завжди використовувати `NavigationStack`.

---

## Таск 3.1: HomeViewModel

### Файл: `ViewModels/HomeViewModel.swift`

```swift
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
```

---

## Таск 3.2: HomeView — Головний екран

### Файл: `Views/Home/HomeView.swift`

Головна сторінка з горизонтальним скролом нових релізів та вертикальним списком рекомендацій.

```swift
import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var audioEngine = AudioEngine.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Нові релізи — горизонтальний скрол
                    if !viewModel.newReleases.isEmpty {
                        NewReleasesSection(
                            albums: viewModel.newReleases
                        )
                    }
                    
                    // Рекомендації — вертикальний список
                    if !viewModel.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Рекомендації")
                                .font(AppFonts.title2)
                                .foregroundStyle(ThemeManager.shared.primaryText)
                                .padding(.horizontal)
                            
                            LazyVStack(spacing: 4) {
                                ForEach(viewModel.recommendations) { track in
                                    SpotifyTrackRow(track: track) {
                                        audioEngine.play(
                                            tracks: viewModel.recommendations,
                                            startIndex: viewModel.recommendations.firstIndex(of: track) ?? 0
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(ThemeManager.shared.primaryBackground.ignoresSafeArea())
            .navigationTitle("Castlie")
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(ThemeManager.shared.accent)
                        .scaleEffect(1.5)
                }
                
                if let error = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                        Text(error)
                            .font(AppFonts.subheadline)
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                            .multilineTextAlignment(.center)
                        Button("Повторити") {
                            Task { await viewModel.loadContent() }
                        }
                        .foregroundStyle(ThemeManager.shared.accent)
                    }
                    .padding()
                }
            }
            .task {
                // .task автоматично запускає async код при появі View
                // і скасовує при зникненні
                if viewModel.newReleases.isEmpty {
                    await viewModel.loadContent()
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
```

---

## Таск 3.3: NewReleasesSection — Нові релізи

### Файл: `Views/Home/NewReleasesSection.swift`

Горизонтальний скрол з обкладинками нових альбомів.

```swift
import SwiftUI

struct NewReleasesSection: View {
    let albums: [SpotifyAlbum]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Нові релізи")
                .font(AppFonts.title2)
                .foregroundStyle(ThemeManager.shared.primaryText)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(albums) { album in
                        AlbumCardView(album: album)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Album Card

struct AlbumCardView: View {
    let album: SpotifyAlbum
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Обкладинка
            AsyncImage(url: album.images.first.flatMap { URL(string: $0.url) }) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    albumPlaceholder
                case .empty:
                    albumPlaceholder
                        .overlay {
                            ProgressView()
                                .tint(ThemeManager.shared.accent)
                        }
                @unknown default:
                    albumPlaceholder
                }
            }
            .frame(width: 160, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Назва альбому
            Text(album.name)
                .font(AppFonts.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(ThemeManager.shared.primaryText)
                .lineLimit(1)
            
            // Дата релізу
            if let releaseDate = album.releaseDate {
                Text(releaseDate)
                    .font(AppFonts.caption)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
            }
        }
        .frame(width: 160)
    }
    
    private var albumPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(ThemeManager.shared.cardBackground)
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 30))
                    .foregroundStyle(ThemeManager.shared.secondaryText)
            }
    }
}

#Preview {
    NewReleasesSection(albums: [])
        .preferredColorScheme(.dark)
        .background(ThemeManager.shared.primaryBackground)
}
```

---

## Таск 3.4: SpotifyTrackRow — Рядок треку

### Файл: `Views/Search/SpotifyTrackRow.swift`

Компонент, який використовується і на Головній, і в Пошуку.

```swift
import SwiftUI

struct SpotifyTrackRow: View {
    let track: Track
    let onTap: () -> Void
    
    @State private var audioEngine = AudioEngine.shared
    
    /// Чи цей трек зараз грає
    private var isCurrentlyPlaying: Bool {
        audioEngine.currentTrack?.id == track.id && audioEngine.isPlaying
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Обкладинка (маленька)
                AsyncImage(url: track.albumImageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ThemeManager.shared.cardBackground)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.caption)
                                .foregroundStyle(ThemeManager.shared.secondaryText)
                        }
                }
                .frame(width: 48, height: 48)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                
                // Інформація
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name)
                        .font(AppFonts.body)
                        .foregroundStyle(
                            isCurrentlyPlaying
                            ? ThemeManager.shared.accent
                            : ThemeManager.shared.primaryText
                        )
                        .lineLimit(1)
                    
                    Text(track.artistName)
                        .font(AppFonts.caption)
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Тривалість
                Text(track.formattedDuration)
                    .font(AppFonts.caption)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
                
                // Індикатор "зараз грає"
                if isCurrentlyPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundStyle(ThemeManager.shared.accent)
                        .symbolEffect(.variableColor.iterative)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SpotifyTrackRow(
        track: Track(
            id: "preview",
            name: "Bohemian Rhapsody",
            artistName: "Queen",
            albumName: "A Night at the Opera",
            albumImageURL: nil,
            previewURL: nil,
            durationMs: 354000,
            popularity: 95
        ),
        onTap: {}
    )
    .preferredColorScheme(.dark)
    .background(ThemeManager.shared.primaryBackground)
}
```

---

## Таск 3.5: SearchViewModel

### Файл: `ViewModels/SearchViewModel.swift`

**УВАГА**: Використовувати debounce для пошуку — не надсилати запит на кожну літеру, а чекати 0.5 секунди після останнього вводу.

```swift
import Foundation
import Observation
import Combine

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
```

---

## Таск 3.6: SearchView — Екран пошуку

### Файл: `Views/Search/SearchView.swift`

```swift
import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @State private var audioEngine = AudioEngine.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Поле пошуку
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                    
                    TextField("Пошук треків...", text: $viewModel.searchText)
                        .foregroundStyle(ThemeManager.shared.primaryText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: viewModel.searchText) { _, _ in
                            viewModel.performSearch()
                        }
                    
                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.searchText = ""
                            viewModel.results = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(ThemeManager.shared.secondaryText)
                        }
                    }
                }
                .padding(12)
                .background(ThemeManager.shared.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Результати
                if viewModel.isSearching {
                    Spacer()
                    ProgressView()
                        .tint(ThemeManager.shared.accent)
                    Spacer()
                } else if viewModel.results.isEmpty && !viewModel.searchText.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 40))
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                        Text("Нічого не знайдено")
                            .font(AppFonts.body)
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                    }
                    Spacer()
                } else if viewModel.results.isEmpty {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                        Text("Введіть назву треку або виконавця")
                            .font(AppFonts.body)
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(viewModel.results) { track in
                                SpotifyTrackRow(track: track) {
                                    audioEngine.play(
                                        tracks: viewModel.results,
                                        startIndex: viewModel.results.firstIndex(of: track) ?? 0
                                    )
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .background(ThemeManager.shared.primaryBackground.ignoresSafeArea())
            .navigationTitle("Пошук")
        }
    }
}

#Preview {
    SearchView()
        .preferredColorScheme(.dark)
}
```

---

## Таск 3.7: TrackCardView — Картка треку (для Головної)

### Файл: `Views/Home/TrackCardView.swift`

Більша картка треку для горизонтальних секцій на головній.

```swift
import SwiftUI

struct TrackCardView: View {
    let track: Track
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Обкладинка
                AsyncImage(url: track.albumImageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ThemeManager.shared.cardBackground)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.title2)
                                .foregroundStyle(ThemeManager.shared.secondaryText)
                        }
                }
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                Text(track.name)
                    .font(AppFonts.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(ThemeManager.shared.primaryText)
                    .lineLimit(1)
                
                Text(track.artistName)
                    .font(AppFonts.caption)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
                    .lineLimit(1)
            }
            .frame(width: 140)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TrackCardView(
        track: Track(
            id: "preview",
            name: "Sample Track",
            artistName: "Sample Artist",
            albumName: "Sample Album",
            albumImageURL: nil,
            previewURL: nil,
            durationMs: 200000,
            popularity: 80
        ),
        onTap: {}
    )
    .preferredColorScheme(.dark)
    .padding()
    .background(ThemeManager.shared.primaryBackground)
}
```

---

## Чеклист Фази 3

- [ ] `HomeViewModel.swift` — завантажує нові релізи та рекомендації
- [ ] `HomeView.swift` — показує реальний контент з Spotify
- [ ] `NewReleasesSection.swift` — горизонтальний скрол обкладинок
- [ ] `AlbumCardView` — обкладинка з AsyncImage працює
- [ ] `SpotifyTrackRow.swift` — показує трек з обкладинкою, виконавцем, тривалістю
- [ ] `SpotifyTrackRow` — підсвічує поточний трек акцентним кольором
- [ ] `SearchViewModel.swift` — пошук з debounce працює
- [ ] `SearchView.swift` — поле вводу, результати, empty state
- [ ] `TrackCardView.swift` — картка треку для горизонтальних секцій
- [ ] Натискання на трек запускає відтворення
- [ ] Всі View мають `#Preview {}` блок
- [ ] Canvas Preview працює
- [ ] Жодних емоджі — тільки SF Symbols
- [ ] Кольори тільки з ThemeManager
