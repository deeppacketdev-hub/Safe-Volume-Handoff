# Фаза 6: Налаштування та Полірування

## Мета
Реалізувати повний екран налаштувань (Night Mode, Fade-in, макс. поріг, тема), додати компоненти-прикраси (GlowingButton, AnimatedWaveform, AdaptiveBackground), та зробити фінальне полірування додатку.

---

## Таск 6.1: SettingsViewModel

### Файл: `ViewModels/SettingsViewModel.swift`

```swift
import Foundation
import Observation

@Observable
@MainActor
class SettingsViewModel {
    var safeVolume = SafeVolumeManager.shared
    var discovery = DeviceDiscoveryService.shared
    var theme = ThemeManager.shared
    
    /// Зберегти всі налаштування
    func saveAll() {
        safeVolume.saveConfig()
    }
}
```

---

## Таск 6.2: SettingsView — Повний екран налаштувань

### Файл: `Views/Settings/SettingsView.swift`

**УВАГА**: Використовувати `Form` або `List` для стандартного iOS-вигляду налаштувань. `Form` автоматично групує секції.

```swift
import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Night Mode
                Section {
                    NightModeSettings()
                } header: {
                    Label("Нічний режим", systemImage: "moon.fill")
                }
                
                // MARK: - Fade-in
                Section {
                    FadeInSettings()
                } header: {
                    Label("Fade-in", systemImage: "waveform.path.ecg")
                }
                
                // MARK: - Volume Limit
                Section {
                    VolumeLimitSettings()
                } header: {
                    Label("Обмеження гучності", systemImage: "chart.bar.fill")
                }
                
                // MARK: - Devices
                Section {
                    Toggle("Показати демо-пристрої", isOn: $viewModel.discovery.showMockDevices)
                        .tint(ThemeManager.shared.accent)
                    
                    Toggle("Підтвердження підключення", isOn: $viewModel.safeVolume.config.requireConfirmation)
                        .tint(ThemeManager.shared.accent)
                } header: {
                    Label("Пристрої", systemImage: "hifispeaker.2.fill")
                }
                
                // MARK: - About
                Section {
                    HStack {
                        Text("Версія")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                    }
                    
                    HStack {
                        Text("Розробник")
                        Spacer()
                        Text("Castlie Team")
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                    }
                    
                    NavigationLink {
                        AboutView()
                    } label: {
                        Text("Про дослідження")
                    }
                } header: {
                    Label("Про додаток", systemImage: "info.circle.fill")
                }
            }
            .scrollContentBackground(.hidden)
            .background(ThemeManager.shared.primaryBackground.ignoresSafeArea())
            .navigationTitle("Налаштування")
            .onChange(of: viewModel.safeVolume.config) { _, _ in
                viewModel.saveAll()
            }
        }
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
```

---

## Таск 6.3: NightModeSettings

### Файл: `Views/Settings/NightModeSettings.swift`

```swift
import SwiftUI

struct NightModeSettings: View {
    @State private var safeVolume = SafeVolumeManager.shared
    
    var body: some View {
        Toggle("Увімкнути нічний режим", isOn: $safeVolume.config.isNightModeEnabled)
            .tint(ThemeManager.shared.accent)
        
        if safeVolume.config.isNightModeEnabled {
            // Час початку
            HStack {
                Image(systemName: "sunset.fill")
                    .foregroundStyle(ThemeManager.shared.accent)
                Text("Початок")
                Spacer()
                Picker("", selection: $safeVolume.config.nightModeStartHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text("\(hour):00").tag(hour)
                    }
                }
                .pickerStyle(.menu)
                .tint(ThemeManager.shared.accent)
            }
            
            // Час кінця
            HStack {
                Image(systemName: "sunrise.fill")
                    .foregroundStyle(ThemeManager.shared.accent)
                Text("Кінець")
                Spacer()
                Picker("", selection: $safeVolume.config.nightModeEndHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text("\(hour):00").tag(hour)
                    }
                }
                .pickerStyle(.menu)
                .tint(ThemeManager.shared.accent)
            }
            
            // Макс. гучність у нічному режимі
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Макс. гучність вночі")
                    Spacer()
                    Text("\(Int(safeVolume.config.nightModeMaxVolume * 100))%")
                        .foregroundStyle(ThemeManager.shared.accent)
                }
                
                Slider(
                    value: $safeVolume.config.nightModeMaxVolume,
                    in: 0.1...0.5,
                    step: 0.05
                )
                .tint(ThemeManager.shared.accent)
            }
            
            // Статус
            HStack {
                Image(systemName: safeVolume.config.isNightModeActive ? "moon.fill" : "sun.max.fill")
                    .foregroundStyle(
                        safeVolume.config.isNightModeActive
                        ? ThemeManager.shared.accent
                        : ThemeManager.shared.secondaryText
                    )
                Text(safeVolume.config.isNightModeActive ? "Зараз активний" : "Зараз неактивний")
                    .font(AppFonts.caption)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
            }
        }
    }
}

#Preview {
    List {
        Section("Нічний режим") {
            NightModeSettings()
        }
    }
    .preferredColorScheme(.dark)
}
```

---

## Таск 6.4: FadeInSettings

### Файл: `Views/Settings/FadeInSettings.swift`

```swift
import SwiftUI

struct FadeInSettings: View {
    @State private var safeVolume = SafeVolumeManager.shared
    
    var body: some View {
        Toggle("Увімкнути fade-in", isOn: $safeVolume.config.isFadeInEnabled)
            .tint(ThemeManager.shared.accent)
        
        if safeVolume.config.isFadeInEnabled {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Тривалість")
                    Spacer()
                    Text("\(String(format: "%.1f", safeVolume.config.fadeInDuration)) сек")
                        .foregroundStyle(ThemeManager.shared.accent)
                }
                
                Slider(
                    value: $safeVolume.config.fadeInDuration,
                    in: 0.5...5.0,
                    step: 0.5
                )
                .tint(ThemeManager.shared.accent)
                
                HStack {
                    Text("0.5с")
                        .font(AppFonts.caption2)
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                    Spacer()
                    Text("5.0с")
                        .font(AppFonts.caption2)
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                }
            }
            
            // Пояснення
            Text("Звук плавно наростатиме від 0% до обраного рівня за вказаний час при кожному підключенні до нового пристрою")
                .font(AppFonts.caption)
                .foregroundStyle(ThemeManager.shared.secondaryText)
        }
    }
}

#Preview {
    List {
        Section("Fade-in") {
            FadeInSettings()
        }
    }
    .preferredColorScheme(.dark)
}
```

---

## Таск 6.5: VolumeLimitSettings

### Файл: `Views/Settings/VolumeLimitSettings.swift`

```swift
import SwiftUI

struct VolumeLimitSettings: View {
    @State private var safeVolume = SafeVolumeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Максимальний поріг")
                Spacer()
                Text("\(Int(safeVolume.config.maxVolumeThreshold * 100))%")
                    .foregroundStyle(
                        safeVolume.safetyLevel(for: safeVolume.config.maxVolumeThreshold).color
                    )
            }
            
            Slider(
                value: $safeVolume.config.maxVolumeThreshold,
                in: 0.1...1.0,
                step: 0.05
            )
            .tint(safeVolume.safetyLevel(for: safeVolume.config.maxVolumeThreshold).color)
            
            HStack {
                Text("10%")
                    .font(AppFonts.caption2)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
                Spacer()
                Text("100%")
                    .font(AppFonts.caption2)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
            }
        }
        
        // Безпека індикатор
        SafetyIndicator(level: safeVolume.safetyLevel(for: safeVolume.config.maxVolumeThreshold))
        
        Text("При підключенні до нового пристрою гучність не перевищить цей рівень, навіть якщо попередня гучність пристрою була вищою")
            .font(AppFonts.caption)
            .foregroundStyle(ThemeManager.shared.secondaryText)
    }
}

#Preview {
    List {
        Section("Обмеження гучності") {
            VolumeLimitSettings()
        }
    }
    .preferredColorScheme(.dark)
}
```

---

## Таск 6.6: AboutView — Про додаток

### Файл: `Views/Settings/AboutView.swift`

```swift
import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Логотип
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "hifispeaker.and.homepodmini.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(ThemeManager.shared.accent)
                        
                        Text("Castlie")
                            .font(AppFonts.largeTitle)
                            .foregroundStyle(ThemeManager.shared.primaryText)
                        
                        Text("Safe Volume Handoff")
                            .font(AppFonts.subheadline)
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
                
                // Опис
                VStack(alignment: .leading, spacing: 12) {
                    Text("Про проєкт")
                        .font(AppFonts.title2)
                        .foregroundStyle(ThemeManager.shared.primaryText)
                    
                    Text("Castlie — це музичний плеєр, створений на основі дослідження проблем взаємодії користувачів з системою Spotify Connect. Головна функція додатку — Safe Volume Handoff — забезпечує безпечне перемикання аудіо на зовнішні пристрої з попереднім контролем гучності.")
                        .font(AppFonts.body)
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                    
                    Text("Курс: Людино-машинна взаємодія")
                        .font(AppFonts.subheadline)
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                }
                
                // Ключові функції
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ключові функції")
                        .font(AppFonts.title2)
                        .foregroundStyle(ThemeManager.shared.primaryText)
                    
                    FeatureRow(icon: "speaker.wave.2.fill", title: "Попередній перегляд гучності", description: "Бачте рівень гучності ДО підключення")
                    FeatureRow(icon: "waveform.path.ecg", title: "Fade-in", description: "Плавне наростання звуку")
                    FeatureRow(icon: "moon.fill", title: "Нічний режим", description: "Автоматичне обмеження ввечері")
                    FeatureRow(icon: "checkmark.shield.fill", title: "Діалог підтвердження", description: "Контроль перед підключенням")
                    FeatureRow(icon: "chart.bar.fill", title: "Максимальний поріг", description: "Захист від небезпечної гучності")
                    FeatureRow(icon: "clock.arrow.circlepath", title: "Історія пристроїв", description: "Запам'ятовує вподобаний рівень")
                }
            }
            .padding()
        }
        .background(ThemeManager.shared.primaryBackground.ignoresSafeArea())
        .navigationTitle("Про додаток")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(ThemeManager.shared.accent)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.headline)
                    .foregroundStyle(ThemeManager.shared.primaryText)
                Text(description)
                    .font(AppFonts.caption)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
    .preferredColorScheme(.dark)
}
```

---

## Таск 6.7: GlowingButton — Кнопка з ефектом свічення

### Файл: `Components/GlowingButton.swift`

```swift
import SwiftUI

struct GlowingButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    @State private var isGlowing = false
    
    var body: some View {
        Button(action: {
            action()
            HapticFeedbackService.medium()
        }) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                Text(title)
            }
            .font(AppFonts.headline)
            .foregroundStyle(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(color)
                    .shadow(color: color.opacity(isGlowing ? 0.6 : 0.2), radius: isGlowing ? 12 : 4)
            )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isGlowing = true
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        GlowingButton(title: "Підключити", icon: "checkmark.shield.fill", color: ThemeManager.shared.safeColor, action: {})
        GlowingButton(title: "Обережно", icon: "exclamationmark.triangle.fill", color: ThemeManager.shared.warningColor, action: {})
    }
    .padding()
    .preferredColorScheme(.dark)
    .background(ThemeManager.shared.primaryBackground)
}
```

---

## Таск 6.8: AnimatedWaveform

### Файл: `Components/AnimatedWaveform.swift`

Анімована хвиля, яка показує що музика грає.

```swift
import SwiftUI

struct AnimatedWaveform: View {
    let isPlaying: Bool
    let color: Color
    let barCount: Int
    
    @State private var animationPhases: [CGFloat]
    
    init(isPlaying: Bool, color: Color = ThemeManager.shared.accent, barCount: Int = 4) {
        self.isPlaying = isPlaying
        self.color = color
        self.barCount = barCount
        self._animationPhases = State(initialValue: Array(repeating: 0.3, count: barCount))
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 3, height: animationPhases[index] * 20)
            }
        }
        .onAppear {
            if isPlaying { startAnimation() }
        }
        .onChange(of: isPlaying) { _, newValue in
            if newValue {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
    }
    
    private func startAnimation() {
        for i in 0..<barCount {
            withAnimation(
                .easeInOut(duration: Double.random(in: 0.3...0.6))
                .repeatForever(autoreverses: true)
                .delay(Double(i) * 0.1)
            ) {
                animationPhases[i] = CGFloat.random(in: 0.3...1.0)
            }
        }
    }
    
    private func stopAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            for i in 0..<barCount {
                animationPhases[i] = 0.3
            }
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        AnimatedWaveform(isPlaying: true)
        AnimatedWaveform(isPlaying: false)
        AnimatedWaveform(isPlaying: true, color: ThemeManager.shared.safeColor, barCount: 6)
    }
    .padding()
    .preferredColorScheme(.dark)
    .background(ThemeManager.shared.primaryBackground)
}
```

---

## Таск 6.9: NightModeManager — автоматичний нічний режим

### Файл: `Services/NightModeManager.swift`

```swift
import Foundation
import Observation

@Observable
@MainActor
class NightModeManager {
    static let shared = NightModeManager()
    
    private(set) var isActive = false
    private var timer: Timer?
    
    private init() {
        checkNightMode()
        startPeriodicCheck()
    }
    
    /// Перевірити чи зараз нічний режим
    func checkNightMode() {
        let config = SafeVolumeManager.shared.config
        isActive = config.isNightModeActive
    }
    
    /// Запустити періодичну перевірку (кожну хвилину)
    private func startPeriodicCheck() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkNightMode()
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}
```

---

## Таск 6.10: View+Transitions Extension

### Файл: `Extensions/View+Transitions.swift`

```swift
import SwiftUI

extension View {
    /// Стандартний перехід для карток пристроїв
    func cardStyle() -> some View {
        self
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ThemeManager.shared.cardBackground)
            )
    }
    
    /// Анімований перехід при появі
    func fadeInTransition(delay: Double = 0) -> some View {
        self
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(delay), value: UUID())
    }
}
```

---

## Таск 6.11: Фінальна перевірка та полірування

### Що перевірити:

1. **Запуск додатку**: 4 таби відображаються з правильними SF Symbols іконками
2. **Головна**: Нові релізи та рекомендації завантажуються з Spotify
3. **Пошук**: Поле вводу працює, результати з обкладинками відображаються
4. **Плеєр**: Міні-плеєр з'являється при натисканні на трек
5. **Повноекранний плеєр**: Обкладинка, прогрес, контроли, адаптивний фон
6. **Пристрої**: Картки з гучністю, кольорова індикація, діалог підтвердження
7. **Налаштування**: Night Mode, Fade-in, Volume Limit працюють і зберігаються
8. **Теми**: Всі кольори з ThemeManager, легко змінити в одному місці
9. **Canvas Preview**: Працює для КОЖНОГО View
10. **Жодних емоджі**: Тільки SF Symbols скрізь

---

## Чеклист Фази 6

- [x] `SettingsViewModel.swift` — зберігає налаштування
- [x] `SettingsView.swift` — повний екран з секціями
- [x] `NightModeSettings.swift` — toggle, час, макс. гучність
- [x] `FadeInSettings.swift` — toggle, тривалість slider
- [x] `VolumeLimitSettings.swift` — slider з кольором безпеки
- [x] `AboutView.swift` — інформація про проєкт та дослідження
- [x] `GlowingButton.swift` — кнопка з анімованим свіченням
- [x] `AnimatedWaveform.swift` — анімовані стовпці
- [x] `NightModeManager.swift` — автоматична перевірка часу
- [x] `View+Transitions.swift` — extension з cardStyle та fadeInTransition
- [x] Всі View мають `#Preview {}` блок
- [x] Canvas Preview працює для кожного файлу
- [x] Жодних емоджі в інтерфейсі додатку
- [x] Всі кольори з ThemeManager
- [x] Додаток білдиться без помилок
- [x] Налаштування зберігаються між запусками
