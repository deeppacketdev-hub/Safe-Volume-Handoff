# Фаза 4: Плеєр (Міні-плеєр + Повноекранний)

## Мета
Реалізувати міні-плеєр (завжди видимий внизу екрану поверх TabView) та повноекранний плеєр з обкладинкою, адаптивним фоном, прогрес-баром та контролем гучності. Міні-плеєр розгортається у повноекранний плавною анімацією.

---

## КРИТИЧНІ ПРАВИЛА ДЛЯ ПЛЕЄРА

### 1. Міні-плеєр
- Міні-плеєр — це overlay поверх TabView в `ContentView.swift`
- Він з'являється ТІЛЬКИ коли є `currentTrack` в `AudioEngine`
- Розташований прямо над табами
- Натискання → відкриває повноекранний плеєр через `.sheet` або `.fullScreenCover`

### 2. Адаптивний фон
- Фон повноекранного плеєра змінює колір на основі домінантного кольору обкладинки
- Для витягування кольору потрібен extension `Color+DominantColor`
- Використовує `UIImage` → аналіз пікселів → середній колір

### 3. Прогрес-бар
- Spotify прев'ю = 30 секунд максимум
- Прогрес-бар має бути draggable (можна перемотувати)
- Показувати час: "0:15 / 0:30"

### 4. `#Preview {}` — ОБОВ'ЯЗКОВО для кожного View

---

## Таск 4.1: Color+DominantColor Extension

### Файл: `Extensions/Color+DominantColor.swift`

**УВАГА**: Цей extension витягує середній колір з `UIImage`. Працює через `CGImage` і `CGContext`.

```swift
import SwiftUI
import UIKit

extension UIImage {
    /// Витягує домінантний (середній) колір з зображення
    /// Алгоритм: зменшуємо зображення до 1x1 піксель і читаємо колір
    var dominantColor: Color {
        // Зменшуємо зображення до 1x1 для швидкості
        let size = CGSize(width: 1, height: 1)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        draw(in: CGRect(origin: .zero, size: size))
        
        guard let context = UIGraphicsGetCurrentContext(),
              let cgImage = context.makeImage(),
              let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return Color(hex: "1A1A24") // Fallback
        }
        
        let r = Double(bytes[0]) / 255.0
        let g = Double(bytes[1]) / 255.0
        let b = Double(bytes[2]) / 255.0
        
        // Затемнюємо колір щоб він був придатний для фону тексту
        return Color(red: r * 0.4, green: g * 0.4, blue: b * 0.4)
    }
}
```

---

## Таск 4.2: Оновити ContentView для міні-плеєра

### Файл: `ContentView.swift` (ОНОВИТИ, НЕ СТВОРИТИ НОВИЙ)

**УВАГА**: Міні-плеєр знаходиться ВСЕРЕДИНІ `ZStack` поверх `TabView`. Він має `padding(.bottom)` щоб не перекривати таби.

```swift
import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @State private var audioEngine = AudioEngine.shared
    @State private var showFullPlayer = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // TabView
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Label("Головна", systemImage: "music.note.house.fill")
                    }
                    .tag(AppTab.home)
                
                SearchView()
                    .tabItem {
                        Label("Пошук", systemImage: "magnifyingglass")
                    }
                    .tag(AppTab.search)
                
                DevicesView()
                    .tabItem {
                        Label("Пристрої", systemImage: "hifispeaker.2.fill")
                    }
                    .tag(AppTab.devices)
                
                SettingsView()
                    .tabItem {
                        Label("Налаштування", systemImage: "gearshape.fill")
                    }
                    .tag(AppTab.settings)
            }
            .tint(ThemeManager.shared.accent)
            
            // Міні-плеєр — показується тільки коли є трек
            if audioEngine.currentTrack != nil {
                MiniPlayerView(showFullPlayer: $showFullPlayer)
                    .padding(.bottom, 49) // Висота TabBar = 49pt
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.3), value: audioEngine.currentTrack != nil)
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showFullPlayer) {
            FullPlayerView(isPresented: $showFullPlayer)
        }
    }
}

enum AppTab: String, CaseIterable {
    case home
    case search
    case devices
    case settings
}

#Preview {
    ContentView()
}
```

---

## Таск 4.3: MiniPlayerView — Міні-плеєр

### Файл: `Views/Player/MiniPlayerView.swift`

Компактний плеєр внизу екрану: обкладинка + назва + play/pause.

```swift
import SwiftUI

struct MiniPlayerView: View {
    @Binding var showFullPlayer: Bool
    @State private var audioEngine = AudioEngine.shared
    
    var body: some View {
        if let track = audioEngine.currentTrack {
            HStack(spacing: 12) {
                // Обкладинка
                AsyncImage(url: track.albumImageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ThemeManager.shared.cardBackground)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(ThemeManager.shared.secondaryText)
                        }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                
                // Назва та виконавець
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name)
                        .font(AppFonts.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(ThemeManager.shared.primaryText)
                        .lineLimit(1)
                    
                    Text(track.artistName)
                        .font(AppFonts.caption2)
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Play / Pause
                Button {
                    audioEngine.togglePlayPause()
                    HapticFeedbackService.light()
                } label: {
                    Image(systemName: audioEngine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(ThemeManager.shared.primaryText)
                        .frame(width: 44, height: 44)
                }
                
                // Next
                Button {
                    audioEngine.playNext()
                    HapticFeedbackService.light()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.body)
                        .foregroundStyle(ThemeManager.shared.primaryText)
                        .frame(width: 36, height: 44)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(ThemeManager.shared.secondaryBackground.opacity(0.8))
                    )
            )
            .padding(.horizontal, 8)
            .onTapGesture {
                showFullPlayer = true
                HapticFeedbackService.light()
            }
            // Прогрес-бар внизу міні-плеєра
            .overlay(alignment: .bottom) {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(ThemeManager.shared.accent)
                        .frame(
                            width: geometry.size.width * audioEngine.progress,
                            height: 2
                        )
                }
                .frame(height: 2)
                .clipShape(Capsule())
                .padding(.horizontal, 20)
            }
        }
    }
}

#Preview {
    ZStack {
        ThemeManager.shared.primaryBackground
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            MiniPlayerView(showFullPlayer: .constant(false))
        }
    }
    .preferredColorScheme(.dark)
}
```

---

## Таск 4.4: FullPlayerView — Повноекранний плеєр

### Файл: `Views/Player/FullPlayerView.swift`

**УВАГА**: 
- `.fullScreenCover` вже надає повноекранне вікно
- Жест свайп вниз для закриття
- Адаптивний фон: завантажуємо обкладинку через URL → UIImage → dominantColor
- `.symbolEffect` для анімації іконок — iOS 17+ API

```swift
import SwiftUI

struct FullPlayerView: View {
    @Binding var isPresented: Bool
    @State private var audioEngine = AudioEngine.shared
    @State private var safeVolume = SafeVolumeManager.shared
    @State private var backgroundColor = Color(hex: "1A1A24")
    
    var body: some View {
        ZStack {
            // Адаптивний фон
            LinearGradient(
                colors: [backgroundColor, ThemeManager.shared.primaryBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Drag indicator + Close
                HStack {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title3)
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 2) {
                        Text("Зараз грає")
                            .font(AppFonts.caption)
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                    }
                    
                    Spacer()
                    
                    // Пристрій
                    Image(systemName: "hifispeaker.fill")
                        .font(.title3)
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Обкладинка
                if let track = audioEngine.currentTrack {
                    AlbumArtView(track: track, onColorExtracted: { color in
                        withAnimation(.easeInOut(duration: 0.5)) {
                            backgroundColor = color
                        }
                    })
                }
                
                // Інформація про трек
                if let track = audioEngine.currentTrack {
                    VStack(spacing: 4) {
                        Text(track.name)
                            .font(AppFonts.title2)
                            .foregroundStyle(ThemeManager.shared.primaryText)
                            .lineLimit(1)
                        
                        Text(track.artistName)
                            .font(AppFonts.body)
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                    }
                    .padding(.horizontal)
                }
                
                // Прогрес-бар
                ProgressBarView()
                    .padding(.horizontal)
                
                // Контроли
                PlaybackControlsView()
                
                // Повзунок гучності
                VolumeSliderView()
                    .padding(.horizontal, 24)
                
                Spacer()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    // Свайп вниз → закрити
                    if value.translation.height > 100 {
                        isPresented = false
                    }
                }
        )
    }
}

#Preview {
    FullPlayerView(isPresented: .constant(true))
        .preferredColorScheme(.dark)
}
```

---

## Таск 4.5: AlbumArtView — Обкладинка

### Файл: `Views/Player/AlbumArtView.swift`

```swift
import SwiftUI

struct AlbumArtView: View {
    let track: Track
    var onColorExtracted: ((Color) -> Void)?
    
    var body: some View {
        AsyncImage(url: track.albumImageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                    .onAppear {
                        // Витягуємо домінантний колір
                        Task {
                            if let uiImage = await loadUIImage(from: track.albumImageURL) {
                                let color = uiImage.dominantColor
                                await MainActor.run {
                                    onColorExtracted?(color)
                                }
                            }
                        }
                    }
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
        .frame(maxWidth: 320, maxHeight: 320)
        .padding(.horizontal, 32)
    }
    
    private var albumPlaceholder: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(ThemeManager.shared.cardBackground)
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 60))
                    .foregroundStyle(ThemeManager.shared.secondaryText)
            }
    }
    
    /// Завантажити UIImage з URL
    private func loadUIImage(from url: URL?) async -> UIImage? {
        guard let url else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}

#Preview {
    AlbumArtView(
        track: Track(
            id: "1", name: "Test", artistName: "Artist",
            albumName: "Album", albumImageURL: nil, previewURL: nil,
            durationMs: 30000, popularity: 50
        )
    )
    .preferredColorScheme(.dark)
    .background(ThemeManager.shared.primaryBackground)
}
```

---

## Таск 4.6: ProgressBarView — Прогрес-бар

### Файл: `Views/Player/ProgressBarView.swift`

```swift
import SwiftUI

struct ProgressBarView: View {
    @State private var audioEngine = AudioEngine.shared
    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    
    var body: some View {
        VStack(spacing: 8) {
            // Прогрес-бар
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Фонова смужка
                    Capsule()
                        .fill(ThemeManager.shared.cardBackground)
                        .frame(height: 4)
                    
                    // Заповнена частина
                    Capsule()
                        .fill(ThemeManager.shared.accent)
                        .frame(
                            width: geometry.size.width * (isDragging ? dragProgress : audioEngine.progress),
                            height: 4
                        )
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            dragProgress = max(0, min(1, value.location.x / geometry.size.width))
                        }
                        .onEnded { value in
                            let progress = max(0, min(1, value.location.x / geometry.size.width))
                            audioEngine.seek(to: audioEngine.duration * progress)
                            isDragging = false
                        }
                )
            }
            .frame(height: 4)
            
            // Час
            HStack {
                Text(audioEngine.formattedTime.components(separatedBy: " / ").first ?? "0:00")
                    .font(AppFonts.caption2)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
                
                Spacer()
                
                Text(audioEngine.formattedTime.components(separatedBy: " / ").last ?? "0:00")
                    .font(AppFonts.caption2)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
            }
        }
    }
}

#Preview {
    ProgressBarView()
        .padding()
        .preferredColorScheme(.dark)
        .background(ThemeManager.shared.primaryBackground)
}
```

---

## Таск 4.7: PlaybackControlsView — Кнопки керування

### Файл: `Views/Player/PlaybackControlsView.swift`

```swift
import SwiftUI

struct PlaybackControlsView: View {
    @State private var audioEngine = AudioEngine.shared
    
    var body: some View {
        HStack(spacing: 40) {
            // Previous
            Button {
                audioEngine.playPrevious()
                HapticFeedbackService.light()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(ThemeManager.shared.primaryText)
            }
            
            // Play / Pause
            Button {
                audioEngine.togglePlayPause()
                HapticFeedbackService.medium()
            } label: {
                Image(systemName: audioEngine.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(ThemeManager.shared.primaryText)
            }
            
            // Next
            Button {
                audioEngine.playNext()
                HapticFeedbackService.light()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(ThemeManager.shared.primaryText)
            }
        }
    }
}

#Preview {
    PlaybackControlsView()
        .padding()
        .preferredColorScheme(.dark)
        .background(ThemeManager.shared.primaryBackground)
}
```

---

## Таск 4.8: VolumeSliderView — Повзунок гучності

### Файл: `Views/Player/VolumeSliderView.swift`

**УВАГА**: Колір повзунка залежить від рівня безпеки (зелений/жовтий/червоний).

```swift
import SwiftUI

struct VolumeSliderView: View {
    @State private var audioEngine = AudioEngine.shared
    @State private var safeVolume = SafeVolumeManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Іконка тихо
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundStyle(ThemeManager.shared.secondaryText)
            
            // Повзунок
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Фон
                    Capsule()
                        .fill(ThemeManager.shared.cardBackground)
                        .frame(height: 6)
                    
                    // Заповнена частина з кольором безпеки
                    Capsule()
                        .fill(safeVolume.safetyLevel(for: audioEngine.volume).color)
                        .frame(
                            width: geometry.size.width * CGFloat(audioEngine.volume),
                            height: 6
                        )
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newVolume = Float(max(0, min(1, value.location.x / geometry.size.width)))
                            audioEngine.setVolume(newVolume)
                        }
                )
            }
            .frame(height: 6)
            
            // Іконка гучно
            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundStyle(ThemeManager.shared.secondaryText)
        }
    }
}

#Preview {
    VolumeSliderView()
        .padding()
        .preferredColorScheme(.dark)
        .background(ThemeManager.shared.primaryBackground)
}
```

---

## Чеклист Фази 4

- [ ] `Color+DominantColor.swift` — витягує колір з UIImage
- [ ] `ContentView.swift` — оновлений з міні-плеєром та fullScreenCover
- [ ] `MiniPlayerView.swift` — показує поточний трек, play/pause, next
- [ ] `MiniPlayerView` — прогрес-бар внизу
- [ ] `MiniPlayerView` — натискання відкриває повноекранний плеєр
- [ ] `FullPlayerView.swift` — адаптивний фон з домінантним кольором
- [ ] `FullPlayerView` — свайп вниз для закриття
- [ ] `AlbumArtView.swift` — обкладинка з тінню та закругленням
- [ ] `AlbumArtView` — витягує і передає домінантний колір
- [ ] `ProgressBarView.swift` — прогрес із можливістю перемотки
- [ ] `ProgressBarView` — показує час "0:15 / 0:30"
- [ ] `PlaybackControlsView.swift` — previous, play/pause, next
- [ ] `VolumeSliderView.swift` — повзунок з кольором безпеки
- [ ] Хаптичний фідбек при натисканні кнопок
- [ ] Всі View мають `#Preview {}` блок
- [ ] Canvas Preview працює
