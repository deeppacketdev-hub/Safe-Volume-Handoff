# Фаза 1: Фундамент

## Мета
Створити Xcode-проєкт, систему тем, моделі даних та базовий TabView з 4 табами. Після цієї фази додаток повинен запускатися, показувати 4 таби з placeholder-контентом, і мати повністю робочу систему тем.

---

## Таск 1.1: Створити Xcode-проєкт

### Що зробити
Створити новий Xcode-проєкт з назвою `Castlie`.

### Як саме
1. Xcode → File → New → Project
2. Template: **App** (не Document App, не Game)
3. Product Name: `Castlie`
4. Team: Personal Team (безкоштовний Apple ID)
5. Organization Identifier: `com.castlie` 
6. Interface: **SwiftUI** (НЕ Storyboard)
7. Language: **Swift**
8. Storage: **None** (SwiftData додамо пізніше)
9. НЕ вмикати Include Tests (для лабораторної не потрібно)
10. Deployment Target: **iOS 26.0**

### Структура папок яку створити в проєкті
```
Castlie/
├── CastlieApp.swift        (вже створений Xcode)
├── ContentView.swift        (вже створений Xcode)
├── Theme/
├── Models/
├── ViewModels/
├── Services/
├── Views/
│   ├── Home/
│   ├── Search/
│   ├── Player/
│   ├── Devices/
│   └── Settings/
├── Components/
└── Extensions/
```

Створити папки можна правою кнопкою на проєкті → New Group.

### Результат
Додаток запускається в симуляторі/на пристрої і показує "Hello, world!".

---

## Таск 1.2: ThemeManager — Система тем

### Що зробити
Створити `ThemeManager` — централізований менеджер кольорів та шрифтів, який легко змінюється в одному місці.

### ВАЖЛИВО
- Всі кольори в додатку беруться ТІЛЬКИ з ThemeManager
- НІКОЛИ не хардкодити кольори в View (наприклад `Color.red` або `Color(hex: "#FF0000")`)
- Використовувати `@Observable` macro (iOS 17+), НЕ `ObservableObject`

### Файл: `Theme/ThemeManager.swift`

```swift
import SwiftUI
import Observation

@Observable
@MainActor
class ThemeManager {
    // MARK: - Singleton
    static let shared = ThemeManager()
    
    // MARK: - Background Colors
    var primaryBackground = Color(hex: "0A0A0F")
    var secondaryBackground = Color(hex: "1A1A24")
    var cardBackground = Color(hex: "242430")
    
    // MARK: - Text Colors
    var primaryText = Color(hex: "F5F5F7")
    var secondaryText = Color(hex: "8E8E93")
    
    // MARK: - Accent Colors
    var accent = Color(hex: "FF6B35")        // Червоно-оранжевий
    var accentHover = Color(hex: "FF8C42")   // Яскравий оранж
    
    // MARK: - Safety Colors
    var safeColor = Color(hex: "34C759")     // Зелений — безпечний рівень
    var warningColor = Color(hex: "FFD60A")  // Жовтий — увага
    var dangerColor = Color(hex: "FF3B30")   // Червоний — небезпечний
    
    private init() {}
    
    // MARK: - Safety Level
    /// Повертає колір на основі рівня гучності (0.0 — 1.0)
    func colorForVolume(_ volume: Float) -> Color {
        switch volume {
        case 0..<0.5:
            return safeColor
        case 0.5..<0.75:
            return warningColor
        default:
            return dangerColor
        }
    }
}
```

### Файл: `Extensions/Color+Hex.swift`

**УВАГА**: Color ініціалізатор з hex-рядка НЕ є стандартним API SwiftUI. Потрібно створити extension.

```swift
import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
```

### Файл: `Theme/AppFonts.swift`

```swift
import SwiftUI

enum AppFonts {
    static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let title = Font.system(size: 28, weight: .bold, design: .rounded)
    static let title2 = Font.system(size: 22, weight: .semibold, design: .rounded)
    static let headline = Font.system(size: 17, weight: .semibold)
    static let body = Font.system(size: 17, weight: .regular)
    static let subheadline = Font.system(size: 15, weight: .regular)
    static let caption = Font.system(size: 12, weight: .regular)
    static let caption2 = Font.system(size: 11, weight: .regular)
}
```

### Результат
ThemeManager компілюється без помилок. Кольори можна використовувати як `ThemeManager.shared.accent`.

---

## Таск 1.3: Моделі даних

### Файл: `Models/Track.swift`

Уніфікована модель треку, яка працює з Spotify API.

```swift
import Foundation

struct Track: Identifiable, Codable, Hashable {
    let id: String                    // Spotify track ID
    let name: String                  // Назва треку
    let artistName: String            // Ім'я виконавця
    let albumName: String             // Назва альбому
    let albumImageURL: URL?           // URL обкладинки (від Spotify)
    let previewURL: URL?              // URL 30-секундного прев'ю (від Spotify)
    let durationMs: Int               // Тривалість в мілісекундах
    let popularity: Int               // Популярність (0-100)
    
    /// Тривалість у секундах
    var durationSeconds: Double {
        Double(durationMs) / 1000.0
    }
    
    /// Форматована тривалість "3:24"
    var formattedDuration: String {
        let totalSeconds = Int(durationSeconds)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
```

### Файл: `Models/AudioDevice.swift`

```swift
import Foundation

enum DeviceType: String, Codable, CaseIterable {
    case iPhone = "iphone"
    case speaker = "hifispeaker.fill"
    case tv = "tv.fill"
    case headphones = "headphones"
    case airplay = "airplayaudio"
    case bluetooth = "wave.3.right"
    
    /// SF Symbol для іконки пристрою
    var sfSymbol: String { rawValue }
    
    /// Назва типу українською
    var displayName: String {
        switch self {
        case .iPhone: return "iPhone"
        case .speaker: return "Колонка"
        case .tv: return "Телевізор"
        case .headphones: return "Навушники"
        case .airplay: return "AirPlay"
        case .bluetooth: return "Bluetooth"
        }
    }
}

struct AudioDevice: Identifiable, Codable, Hashable {
    let id: String                       // Унікальний ідентифікатор
    let name: String                     // Назва пристрою ("JBL Flip 6")
    let type: DeviceType                 // Тип пристрою
    let connectionType: ConnectionType   // AirPlay / Bluetooth
    var roomName: String?                // Кімната (якщо задано)
    var lastKnownVolume: Float?          // Остання відома гучність (0.0 - 1.0)
    var isConnected: Bool = false        // Чи підключений зараз
    
    enum ConnectionType: String, Codable {
        case airplay = "AirPlay"
        case bluetooth = "Bluetooth"
        case wired = "Дротове"
        case builtIn = "Вбудований"
    }
}
```

### Файл: `Models/Playlist.swift`

```swift
import Foundation

struct Playlist: Identifiable, Codable {
    let id: UUID
    var name: String
    var tracks: [Track]
    let createdAt: Date
    
    init(name: String, tracks: [Track] = []) {
        self.id = UUID()
        self.name = name
        self.tracks = tracks
        self.createdAt = Date()
    }
    
    var trackCount: Int { tracks.count }
    
    /// Загальна тривалість плейлиста
    var totalDuration: String {
        let total = tracks.reduce(0) { $0 + $1.durationSeconds }
        let minutes = Int(total) / 60
        return "\(minutes) хв"
    }
}
```

### Файл: `Models/DeviceHistory.swift`

```swift
import Foundation

struct DeviceHistoryEntry: Identifiable, Codable {
    let id: UUID
    let deviceId: String
    let deviceName: String
    let volume: Float              // 0.0 - 1.0
    let timestamp: Date
    let wasNightMode: Bool
    
    init(deviceId: String, deviceName: String, volume: Float, wasNightMode: Bool = false) {
        self.id = UUID()
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.volume = volume
        self.timestamp = Date()
        self.wasNightMode = wasNightMode
    }
}
```

### Файл: `Models/SafeVolumeConfig.swift`

```swift
import Foundation

struct SafeVolumeConfig: Codable {
    var isFadeInEnabled: Bool = true
    var fadeInDuration: Double = 2.0        // Секунди (0.5 - 5.0)
    var maxVolumeThreshold: Float = 0.4     // 40% максимальний поріг при підключенні
    var isNightModeEnabled: Bool = false
    var nightModeStartHour: Int = 22        // 22:00
    var nightModeEndHour: Int = 8           // 08:00
    var nightModeMaxVolume: Float = 0.3     // 30% максимум у нічному режимі
    var requireConfirmation: Bool = true    // Показувати діалог підтвердження
    
    /// Перевіряє, чи зараз активний нічний режим
    var isNightModeActive: Bool {
        guard isNightModeEnabled else { return false }
        let hour = Calendar.current.component(.hour, from: Date())
        if nightModeStartHour > nightModeEndHour {
            // Переходить через опівніч: наприклад 22:00 - 08:00
            return hour >= nightModeStartHour || hour < nightModeEndHour
        } else {
            return hour >= nightModeStartHour && hour < nightModeEndHour
        }
    }
    
    /// Максимальна дозволена гучність з урахуванням усіх налаштувань
    var effectiveMaxVolume: Float {
        if isNightModeActive {
            return min(maxVolumeThreshold, nightModeMaxVolume)
        }
        return maxVolumeThreshold
    }
}
```

### Результат
Всі моделі компілюються без помилок.

---

## Таск 1.4: ContentView з TabView

### Що зробити
Створити основний `ContentView` з 4 табами та placeholder-контентом. Використовувати ТІЛЬКИ SF Symbols для іконок табів.

### ВАЖЛИВО
- Використовувати `TabView` з `Tab` API (iOS 18+) АБО класичний `TabView` з `.tabItem` (iOS 16+). Для iOS 26+ можна використовувати новий API.
- Фон TabView має бути темним (з ThemeManager)
- Жодних емоджі — тільки SF Symbols через `Image(systemName:)`

### Файл: `ContentView.swift`

```swift
import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $selectedTab) {
                // Таб 1: Головна
                HomeView()
                    .tabItem {
                        Label("Головна", systemImage: "music.note.house.fill")
                    }
                    .tag(AppTab.home)
                
                // Таб 2: Пошук
                SearchView()
                    .tabItem {
                        Label("Пошук", systemImage: "magnifyingglass")
                    }
                    .tag(AppTab.search)
                
                // Таб 3: Пристрої
                DevicesView()
                    .tabItem {
                        Label("Пристрої", systemImage: "hifispeaker.2.fill")
                    }
                    .tag(AppTab.devices)
                
                // Таб 4: Налаштування
                SettingsView()
                    .tabItem {
                        Label("Налаштування", systemImage: "gearshape.fill")
                    }
                    .tag(AppTab.settings)
            }
            .tint(ThemeManager.shared.accent)
        }
        .preferredColorScheme(.dark)
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

### Файл: `CastlieApp.swift`

```swift
import SwiftUI

@main
struct CastlieApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
```

### Placeholder Views (тимчасові, замінимо пізніше)

#### `Views/Home/HomeView.swift`
```swift
import SwiftUI

struct HomeView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                ThemeManager.shared.primaryBackground
                    .ignoresSafeArea()
                
                Text("Головна")
                    .font(AppFonts.title)
                    .foregroundStyle(ThemeManager.shared.primaryText)
            }
            .navigationTitle("Головна")
        }
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
```

#### `Views/Search/SearchView.swift`
```swift
import SwiftUI

struct SearchView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                ThemeManager.shared.primaryBackground
                    .ignoresSafeArea()
                
                Text("Пошук")
                    .font(AppFonts.title)
                    .foregroundStyle(ThemeManager.shared.primaryText)
            }
            .navigationTitle("Пошук")
        }
    }
}

#Preview {
    SearchView()
        .preferredColorScheme(.dark)
}
```

#### `Views/Devices/DevicesView.swift`
```swift
import SwiftUI

struct DevicesView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                ThemeManager.shared.primaryBackground
                    .ignoresSafeArea()
                
                Text("Пристрої")
                    .font(AppFonts.title)
                    .foregroundStyle(ThemeManager.shared.primaryText)
            }
            .navigationTitle("Пристрої")
        }
    }
}

#Preview {
    DevicesView()
        .preferredColorScheme(.dark)
}
```

#### `Views/Settings/SettingsView.swift`
```swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                ThemeManager.shared.primaryBackground
                    .ignoresSafeArea()
                
                Text("Налаштування")
                    .font(AppFonts.title)
                    .foregroundStyle(ThemeManager.shared.primaryText)
            }
            .navigationTitle("Налаштування")
        }
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
```

### Результат
- Додаток запускається з 4 табами
- Кожен таб показує свою назву
- Фон темний (#0A0A0F)
- Іконки табів — SF Symbols
- Акцентний колір — червоно-оранжевий (#FF6B35)
- Xcode Canvas Preview працює для кожного View

---

## Чеклист Фази 1

- [ ] Xcode-проєкт створено з назвою Castlie
- [ ] Deployment Target = iOS 26.0
- [ ] Структура папок створена
- [ ] `ThemeManager.swift` — компілюється, кольори працюють
- [ ] `Color+Hex.swift` — extension компілюється
- [ ] `AppFonts.swift` — шрифти визначені
- [ ] `Track.swift` — модель створена
- [ ] `AudioDevice.swift` — модель створена з DeviceType enum
- [ ] `Playlist.swift` — модель створена
- [ ] `DeviceHistory.swift` — модель створена
- [ ] `SafeVolumeConfig.swift` — модель створена з логікою Night Mode
- [ ] `ContentView.swift` — TabView з 4 табами працює
- [ ] `CastlieApp.swift` — точка входу налаштована
- [ ] Placeholder views створені для всіх 4 табів
- [ ] Кожен View має `#Preview { }` блок
- [ ] Додаток білдиться без помилок
- [ ] Canvas Preview працює для кожного файлу
