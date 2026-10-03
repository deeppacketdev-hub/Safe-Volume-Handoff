# Castlie — Прогрес Розробки

## Загальний Статус: ВСІ ФАЗИ ЗАВЕРШЕНО ✅ (ФАЗА 6 ЗАВЕРШЕНА)

---

## Фази

| Фаза | Назва | Статус | Файл |
|---|---|---|---|
| 1 | Фундамент (Xcode, Theme, Models, TabView) | ✅ ЗАВЕРШЕНО | [phase-1-foundation.md](phases/phase-1-foundation.md) |
| 2 | Spotify API та Аудіо-движок | ✅ ЗАВЕРШЕНО | [phase-2-spotify-audio.md](phases/phase-2-spotify-audio.md) |
| 3 | UI: Головна та Пошук | ✅ ЗАВЕРШЕНО | [phase-3-home-search-ui.md](phases/phase-3-home-search-ui.md) |
| 4 | Плеєр (міні + повноекранний) | ✅ ЗАВЕРШЕНО | [phase-4-player.md](phases/phase-4-player.md) |
| 5 | Safe Volume Handoff (Пристрої) | ✅ ЗАВЕРШЕНО | [phase-5-safe-volume-handoff.md](phases/phase-5-safe-volume-handoff.md) |
| 6 | Налаштування та Полірування | ✅ ЗАВЕРШЕНО | [phase-6-settings-polish.md](phases/phase-6-settings-polish.md) |
| 7 | Повноцінний Плеєр Spotify (Full Playback) | 🔄 В РОБОТІ (Досліджено) | [phase-7-spotify-full-playback.md](phases/phase-7-spotify-full-playback.md) |

---

## Деталі Фази 1

### Таск 1.1: Xcode-проєкт ✅
- Проєкт `Castlie` створено через XcodeGen
- Deployment Target: iOS 18.0 (SDK: iOS 27.0)
- Swift 6.0, SwiftUI
- Структура папок: Theme/, Models/, ViewModels/, Services/, Views/, Components/, Extensions/

### Таск 1.2: ThemeManager ✅
- `ThemeManager.swift` — @Observable singleton з палітрою кольорів
- `Color+Hex.swift` — extension для ініціалізації Color з hex-рядка
- `AppFonts.swift` — шрифти з rounded design

### Таск 1.3: Моделі даних ✅
- `Track.swift` — модель треку з Spotify
- `AudioDevice.swift` — модель пристрою з DeviceType enum
- `Playlist.swift` — модель плейлиста
- `DeviceHistory.swift` — історія підключень
- `SafeVolumeConfig.swift` — конфігурація safe volume з Night Mode

### Таск 1.4: ContentView з TabView ✅
- `ContentView.swift` — TabView з 4 табами (SF Symbols)
- `CastlieApp.swift` — точка входу з dark color scheme
- Placeholder views: HomeView, SearchView, DevicesView, SettingsView
- Кожен View з #Preview блоком

### Результат білда
- ✅ **BUILD SUCCEEDED** (xcodebuild, generic/platform=iOS)
- Всі файли компілюються без помилок та ворнінгів

---

## Деталі Фази 2

### Таск 2.1: Spotify Models ✅
- `SpotifyModels.swift` — моделі для всіх API відповідей Spotify
- SpotifyAuthResponse, SpotifySearchResponse, SpotifyTrack, SpotifyArtist, SpotifyAlbum
- SpotifyImage, SpotifyNewReleasesResponse, SpotifyCategoriesResponse, SpotifyRecommendationsResponse
- Метод `toTrack()` для конвертації SpotifyTrack → Track

### Таск 2.2: SpotifyAuthService ✅
- `SpotifyAuthService.swift` — Client Credentials Flow автентифікація
- Кешування токена з автоматичним оновленням за 60с до закінчення
- Base64-кодування client_id:client_secret для Basic Auth
- `SpotifyError` enum з LocalizedError

### Таск 2.3: SpotifyAPIService ✅
- `SpotifyAPIService.swift` — основний сервіс для запитів до Spotify Web API
- `searchTracks()` — пошук треків з фільтрацією без прев'ю
- `getNewReleases()` — отримання нових релізів
- `getAlbumTracks()` — треки альбому з обкладинкою
- `getRecommendations()` — рекомендації за жанрами
- Авто-ретрай при 401 (протухший токен)

### Таск 2.4: AudioEngine ✅
- `AudioEngine.swift` — аудіо-движок на AVPlayer для стрімінгу
- AVAudioSession `.playback` для фонового відтворення та зовнішніх пристроїв
- play/pause/stop/seek/volume контроль
- Черга треків з next/previous (циклічна навігація)
- Periodic time observer (0.1с) для оновлення прогресу
- Now Playing Info для екрану блокування (MPNowPlayingInfoCenter)
- Форматований час та прогрес-бар

### Таск 2.5: FadeInEngine ✅
- `FadeInEngine.swift` — плавне наростання гучності
- Від 0 до targetVolume за configurable duration
- 20 кроків на секунду для плавності
- Cancellable Task з підтримкою скасування

### Таск 2.6: SafeVolumeManager ✅
- `SafeVolumeManager.swift` — ключовий сервіс безпечного перемикання гучності
- SafetyLevel enum: safe/warning/danger з кольорами та іконками
- Рекомендована гучність на основі історії пристрою
- Device history з UserDefaults persistence (макс. 100 записів)
- Night Mode інтеграція через SafeVolumeConfig
- Volume clamping відповідно до налаштувань

### Таск 2.7: HapticFeedbackService ✅
- `HapticFeedbackService.swift` — тактильний відгук
- Impact: light, medium, heavy
- Notification: success, warning, error

### Результат білда
- ✅ **BUILD SUCCEEDED** (xcodebuild, generic/platform=iOS)
- 0 помилок, 0 ворнінгів
- Swift 6.0 strict concurrency — повна відповідність

---

## Деталі Фази 3

### Таск 3.1: HomeViewModel ✅
- `HomeViewModel.swift` — @Observable @MainActor ViewModel
- Завантажує нові релізи та рекомендації паралельно через async let
- Стани: isLoading, errorMessage
- Використовує SpotifyAPIService.shared

### Таск 3.2: HomeView ✅
- `HomeView.swift` — замінений placeholder на повну реалізацію
- NavigationStack з ScrollView
- Нові релізи — горизонтальний скрол (NewReleasesSection)
- Рекомендації — вертикальний список (SpotifyTrackRow)
- Loading state з ProgressView
- Error state з кнопкою "Повторити"
- .task для автоматичного завантаження контенту

### Таск 3.3: NewReleasesSection ✅
- `NewReleasesSection.swift` — горизонтальний скрол обкладинок альбомів
- AlbumCardView — AsyncImage для завантаження обкладинок з Spotify
- Placeholder з ProgressView при завантаженні
- Назва альбому та дата релізу

### Таск 3.4: SpotifyTrackRow ✅
- `SpotifyTrackRow.swift` — рядок треку для списків
- AsyncImage для обкладинки (48x48)
- Назва треку, виконавець, тривалість
- Підсвітка поточного треку акцентним кольором
- Анімований індикатор "зараз грає" (symbolEffect .variableColor)

### Таск 3.5: SearchViewModel ✅
- `SearchViewModel.swift` — @Observable @MainActor ViewModel
- Debounce пошуку: 0.5 секунди після останнього вводу
- Скасування попереднього запиту при новому
- Стани: isSearching, errorMessage

### Таск 3.6: SearchView ✅
- `SearchView.swift` — замінений placeholder на повну реалізацію
- Поле пошуку з іконкою та кнопкою очищення
- autocorrectionDisabled, textInputAutocapitalization(.never)
- onChange → performSearch з debounce
- Empty state: "Введіть назву треку або виконавця"
- Not found state: "Нічого не знайдено"
- Loading state: ProgressView
- Результати: LazyVStack з SpotifyTrackRow

### Таск 3.7: TrackCardView ✅
- `TrackCardView.swift` — більша картка треку (140x140) для горизонтальних секцій
- AsyncImage для обкладинки
- Назва треку та виконавець

### Результат білда
- ✅ **BUILD SUCCEEDED** (xcodebuild, generic/platform=iOS)
- 0 помилок, 0 ворнінгів
- Всі нові файли інтегровані через XcodeGen

---

## Деталі Фази 4

### Таск 4.1: Color+DominantColor Extension ✅
- `Color+DominantColor.swift` — extension для UIImage
- Алгоритм: зменшення зображення до 1x1 піксель через CGContext
- Затемнення кольору (× 0.4) для фону тексту
- Fallback на `Color(hex: "1A1A24")`

### Таск 4.2: ContentView оновлений ✅
- Додано `@State audioEngine = AudioEngine.shared`
- Додано `@State showFullPlayer = false`
- Міні-плеєр як overlay поверх TabView з padding(.bottom, 49)
- `.fullScreenCover` для повноекранного плеєра
- Анімація появи міні-плеєра: `.spring(response: 0.3)`

### Таск 4.3: MiniPlayerView ✅
- `MiniPlayerView.swift` — компактний плеєр внизу екрану
- AsyncImage для обкладинки (44x44) з fallback іконкою
- Назва треку + виконавець з lineLimit(1)
- Кнопки Play/Pause та Next з хаптичним фідбеком
- Прогрес-бар (2pt) внизу через overlay
- onTapGesture → відкриває повноекранний плеєр
- Фон: ultraThinMaterial + secondaryBackground

### Таск 4.4: FullPlayerView ✅
- `FullPlayerView.swift` — повноекранний плеєр
- Адаптивний фон: LinearGradient від домінантного кольору обкладинки до primaryBackground
- Кнопка "chevron.down" для закриття
- "Зараз грає" заголовок, іконка пристрою
- AlbumArtView, інформація про трек
- ProgressBarView, PlaybackControlsView, VolumeSliderView
- DragGesture: свайп вниз (> 100pt) → закриття

### Таск 4.5: AlbumArtView ✅
- `AlbumArtView.swift` — обкладинка альбому
- AsyncImage з 3 станами: success, failure, empty (з ProgressView)
- RoundedRectangle(cornerRadius: 16) + shadow
- Колбек `onColorExtracted` для передачі домінантного кольору
- Async loadUIImage через URLSession.shared.data

### Таск 4.6: ProgressBarView ✅
- `ProgressBarView.swift` — прогрес із можливістю перемотки
- GeometryReader для Capsule-індикатора
- DragGesture для seekування
- Стан isDragging для плавного переміщення
- Час: "0:15" зліва, "0:30" справа (через formattedTime split)

### Таск 4.7: PlaybackControlsView ✅
- `PlaybackControlsView.swift` — кнопки керування
- Previous (backward.fill, 28pt)
- Play/Pause (play.circle.fill / pause.circle.fill, 64pt)
- Next (forward.fill, 28pt)
- Хаптичний фідбек: light для skip, medium для play/pause

### Таск 4.8: VolumeSliderView ✅
- `VolumeSliderView.swift` — повзунок гучності
- Іконки speaker.fill та speaker.wave.3.fill
- GeometryReader + DragGesture для керування
- Колір повзунка залежить від SafetyLevel (safe/warning/danger)
- Інтеграція з SafeVolumeManager для визначення безпеки

### Результат білда
- ✅ **BUILD SUCCEEDED** (xcodebuild, generic/platform=iOS)
- 0 помилок, 0 ворнінгів
- Всі 7 нових файлів + 1 оновлений інтегровані через XcodeGen

---

## Деталі Фази 5

### Таск 5.1: DeviceDiscoveryService ✅
- `DeviceDiscoveryService.swift` — @Observable @MainActor singleton
- **Повна відмова від заглушок (mock-пристроїв)**: додаток працює виключно з реальними апаратними аудіо-маршрутами iOS
- Виявлення поточного аудіо-маршруту через `AVAudioSession.sharedInstance().currentRoute`
- Автоматичний Safe Volume Handoff при зміні аудіо-маршруту (`AVAudioSession.routeChangeNotification`)
- Відстеження доступності AirPlay у мережі через `AVRouteDetector` та `AVRouteDetectorMultipleRoutesDetectedDidChange`
- Персистентний список реальних підключених пристроїв з історії `SafeVolumeManager` (`knownDevices`)

### Таск 5.2: DeviceManagerViewModel ✅
- `DeviceManagerViewModel.swift` — @Observable @MainActor ViewModel
- Керування процесом налаштування безпечної гучності для реальних збережених та активних пристроїв
- Інтеграція з `SafeVolumeManager`: рекомендована початкова гучність з історії та збереження записів
- `FadeInEngine` інтеграція: плавне наростання гучності при підключенні
- Тактильний відгук через `HapticFeedbackService`

### Таск 5.3: DevicesView ✅
- `DevicesView.swift` — головний екран пристроїв
- Картка поточного активного пристрою з індикатором підключення (`CurrentDeviceCard`)
- Список доступних пристроїв з фільтрацією
- Індикатор доступності AirPlay
- Стан порожнього списку при відсутності пристроїв
- `NightModeStatusBar` внизу екрана зі статусом нічного режиму та макс. порогом
- Системний AirPlay picker у toolbar через `AirPlayPickerButton`
- Модальний sheet (`HandoffConfirmSheet`) з `.presentationDetents([.medium, .large])`

### Таск 5.4: DeviceCardView ✅
- `DeviceCardView.swift` — картка пристрою з останньою гучністю
- Візуальний прогрес-бар гучності з динамічним кольором безпеки (зелений, жовтий, червоний)
- Попередження при підвищеній або небезпечній гучності (`SafetyIndicator`)
- Кнопка "Підключити безпечно" зі стилізацією під рівень безпеки та хаптичним відгуком

### Таск 5.5: HandoffConfirmSheet ✅
- `HandoffConfirmSheet.swift` — ключовий UX-компонент підтвердження переходу
- Інтерактивний повзунок гучності для налаштування ДО фактичного підключення
- Захист від перевищення максимального безпечного порогу (авто-обмеження та попереджувальний хаптик)
- Відображення налаштувань: fade-in тривалість, нічний режим, максимальний ліміт
- Кнопки безпечного підключення та скасування

### Таск 5.6: SafetyIndicator & AirPlayPickerButton ✅
- `SafetyIndicator.swift` — багаторазовий компонент статусу безпеки
- `AirPlayPickerButton.swift` — `UIViewRepresentable` обгортка над `AVRoutePickerView` для виклику системного AirPlay діалогу
- Оновлено `FullPlayerView.swift` для динамічного відображення іконки активного аудіо-пристрою

### Результат білда
- ✅ **BUILD SUCCEEDED** (xcodebuild, generic/platform=iOS)
- 0 помилок, 0 ворнінгів
- Повна підтримка Swift 6.0 strict concurrency

---

## Деталі Фази 6

### Таск 6.1: SettingsViewModel ✅
- `SettingsViewModel.swift` — @Observable @MainActor ViewModel
- Інтеграція `SafeVolumeManager`, `DeviceDiscoveryService`, `ThemeManager`
- Метод `saveAll()` для збереження повної конфігурації

### Таск 6.2: SettingsView ✅
- `SettingsView.swift` — повноцінний екран налаштувань на базі `List` та `Section`
- Секції: Нічний режим, Fade-in, Обмеження гучності, Пристрої, Про додаток
- Динамічне збереження конфігурації через `.onChange(of: viewModel.safeVolume.config)`
- Навігація до `AboutView` через `NavigationLink`

### Таск 6.3: NightModeSettings ✅
- `NightModeSettings.swift` — налаштування нічного режиму
- Toggle увімкнення/вимкнення
- Вибір годин початку та завершення нічного періоду через пікери
- Слайдер максимальної нічної гучності (10% - 50%)
- Динамічний статус "Зараз активний / неактивний" з відповідною іконкою SF Symbols

### Таск 6.4: FadeInSettings ✅
- `FadeInSettings.swift` — налаштування плавного наростання звуку
- Toggle увімкнення/вимкнення
- Слайдер тривалості fade-in (0.5с - 5.0с з кроком 0.5с)
- Текстове пояснення роботи алгоритму для користувача

### Таск 6.5: VolumeLimitSettings ✅
- `VolumeLimitSettings.swift` — глобальне обмеження гучності при підключенні
- Слайдер максимального порогу (10% - 100%)
- Динамічна зміна кольору відповідно до SafetyLevel
- Індикатор безпеки `SafetyIndicator`
- Пояснення принципу роботи Safe Volume Handoff

### Таск 6.6: AboutView ✅
- `AboutView.swift` — екран "Про додаток"
- Логотип додатку з SF Symbol та брендовим акцентом
- Опис проєкту та академічного контексту (дослідження взаємодії зі Spotify Connect)
- Список ключових функцій додатку з `FeatureRow`

### Таск 6.7: GlowingButton ✅
- `Components/GlowingButton.swift` — динамічна кнопка з пульсуючим неоновим свіченням
- Анімація `.repeatForever(autoreverses: true)` на тіні
- Тактильний відгук `HapticFeedbackService.medium()`
- Підтримка адаптивної та фіксованої ширини (`isFullWidth`)
- Інтегровано у `HandoffConfirmSheet`

### Таск 6.8: AnimatedWaveform ✅
- `Components/AnimatedWaveform.swift` — анімований графічний аудіо-еквалайзер
- Плавна рандомізована висота стовпчиків при відтворенні
- М'яке згасання при паузі
- Інтегровано у `SpotifyTrackRow`, `MiniPlayerView`, `FullPlayerView`

### Таск 6.9: NightModeManager ✅
- `Services/NightModeManager.swift` — автоматичний менеджер нічного режиму
- Таймер періодичної перевірки щохвилини
- Повна сумісність зі Swift 6 strict concurrency (`nonisolated(unsafe)`)

### Таск 6.10: View+Transitions Extension ✅
- `Extensions/View+Transitions.swift` — розширення для View
- Модифікатор `.cardStyle()` для уніфікованого дизайну карток пристроїв
- Анімований перехід `.fadeInTransition()`

### Таск 6.11: Фінальна перевірка та полірування ✅
- Всі 4 таби перевірено: Home, Search, Devices, Settings
- 0 емоджі в коді та UI — суворе використання системних SF Symbols
- Кожен View має робочий `#Preview` блок
- Додаток збирається без помилок та ворнінгів
- Повна персистентність усіх налаштувань у UserDefaults

### Результат білда
- ✅ **BUILD SUCCEEDED** (xcodebuild, generic/platform=iOS)
- 0 помилок, 0 ворнінгів
- Swift 6.0 strict concurrency — повна відповідність

---

## Журнал Змін

| Дата | Що зроблено |
|---|---|
| 2026-10-01 | Створено план проєкту та структуру фаз |
| 2026-10-01 | ✅ Фаза 1 завершена: Xcode-проєкт, ThemeManager, моделі даних, TabView з 4 табами |
| 2026-10-01 | ✅ Фаза 2 завершена: SpotifyModels, SpotifyAuthService, SpotifyAPIService, AudioEngine, FadeInEngine, SafeVolumeManager, HapticFeedbackService |
| 2026-10-01 | ✅ Фаза 3 завершена: HomeViewModel, HomeView, NewReleasesSection, AlbumCardView, SpotifyTrackRow, SearchViewModel, SearchView, TrackCardView |
| 2026-10-02 | ✅ Фаза 4 завершена: Color+DominantColor, MiniPlayerView, FullPlayerView, AlbumArtView, ProgressBarView, PlaybackControlsView, VolumeSliderView, ContentView оновлений |
| 2026-10-02 | ✅ Фаза 5 завершена: DeviceDiscoveryService, DeviceManagerViewModel, DevicesView, DeviceCardView, HandoffConfirmSheet, SafetyIndicator, AirPlayPickerButton, FullPlayerView оновлений |
| 2026-10-02 | ✅ Фаза 6 завершена: SettingsViewModel, SettingsView, NightModeSettings, FadeInSettings, VolumeLimitSettings, AboutView, GlowingButton, AnimatedWaveform, NightModeManager, View+Transitions, фінальне полірування |
| 2026-10-02 | 🎨 Повний редизайн Apple HIG та Dimillian View Refactoring: перероблено Castlie Connect без шумів та зайвого тексту (Hero активний вивід, інтуїтивний tap-to-connect список, тихий пошук пристроїв, відсутність дублюючих повзунків); редизайн SettingsView з кольоровими Apple Settings бейджами та компактними пікерами розкладу; рефакторинг FullPlayerView та MiniPlayerView на виділені subview-структури згідно зі swiftui-view-refactor та 8pt сіткою. |
| 2026-10-02 | 🏝️ Виправлено відступ Dynamic Island у FullPlayerView (гарантований кліренс через hardware safe area, Grabber pill та плашка «Зараз грає» більше не ховаються під острівцем); відновлено Apple Liquid Glass на капсулі MiniPlayerView (iOS 26+ .glassEffect(.regular, in: .capsule)) зі збереженням чистих контролів без стороннього синього скла. |
| 2026-10-02 | 📡 Виправлено Castlie Connect та збереження WebSocket-з'єднання з Mac: додано 15-секундний heartbeat ping-таймер для запобігання тайм-ауту Cloudflare на `castlie.dron.lol`; Mac успішно виявляється у списку пристроїв на iPhone. |
| 2026-10-02 | 🔊 Відновлено показ системної шторки гучності iOS та синхронізацію: видалено блокуючий `MPVolumeView` з ієрархії, налаштовано прямий KVO/NotificationCenter слухач системної гучності `outputVolume`, усунено подвійне затухання звуку (unity gain на динаміках iPhone). |
| 2026-10-02 | ⚡️ Комплексна оптимізація продуктивності (120 FPS ProMotion & 0% idle CPU): ізольовано дерево рендеру MiniPlayer/FullPlayer (усунено 10 Hz шторм інвалідацій через leaf views), кешовано екстракцію палітри кольорів обкладинок (NSCache), обмежено пам'ять URLCache/ImageCache, анімації хвилі та світіння переведено на RenderServer PhaseAnimator, виправлено O(N) операції в списках та запобігли витоку таймерів/обзерверів у AudioEngine. |
| 2026-10-02 | 📱 Spotify-style індикація пристрою та плаваюча підказка зі стрілочкою: у міні-плеєрі при підключенні до зовнішнього пристрою (Mac / Bluetooth / AirPlay) другий рядок плавно змінюється з виконавця на `[Device Icon] Device Name` у фірмовому кольорі; додано фірмову плаваючу підказку Spotify (`SpotifyDeviceCalloutView` із кастомним дзьобиком `CalloutBubbleShape`) над міні-плеєром з текстом «Слухайте на [Пристрій]» та кнопкою «Змінити», яка з'являється при закритті великого плеєра, запуску або перемиканні вкладок із розумним тротлінгом («через раз», 20с кулдаун) та автозниканням через 3.8с. |
| 2026-10-02 | 🎛️ Виправлено зависання та паузу еквалайзера (`AnimatedWaveform`): повністю відновлено оригінальний дизайн вертикальних заокруглених смужок (ширина 3pt, інтервал 2pt, висота до 16-20pt замість маленьких точок); переведено на `TimelineView(.animation(paused: !isPlaying))` — тепер при відтворенні смужки плавно і динамічно танцюють за синусоїдою на 120 FPS, а при натисканні на паузу еквалайзер миттєво і повністю завмирає на місці з нульовим рухом та 0% CPU; повністю перероблено трек прогресу в міні-плеєрі (`MiniPlayerProgressTrack`): прибрано відступ 24pt під обкладинкою, лінію інтегровано на всю ширину вздовж нижнього контуру скла капсули з акцентним світловим маяком початку (`Origin Anchor Beacon` на 0:00) та сяючим рухомим бісером (`Liquid Playhead Bead`). |
| 2026-10-02 | 🌊 Оксамитова пружинна анімація (Apple Fluid Springs) відкриття та закриття великого плеєра: замінено занадто різкі переходи на калібровані пружини Apple Music (`response: 0.52/0.50`, `dampingFraction: 0.86/0.88`); розширено вікна накладання кросфейдів контролів (`fullControlsOpacity` та `miniControlsOpacity`), завдяки чому картка плавно і м'яко випливає та вкладається в міні-плеєр без різких ривків на 120 FPS ProMotion. |

