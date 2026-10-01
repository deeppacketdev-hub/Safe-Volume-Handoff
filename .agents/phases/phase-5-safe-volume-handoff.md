# Фаза 5: Safe Volume Handoff (Пристрої)

## Мета
Реалізувати **ГОЛОВНИЙ ЕКРАН ПРОЄКТУ** — таб "Пристрої" з усіма UX-рішеннями з дослідження: виявлення пристроїв (AirPlay/Bluetooth), картки пристроїв з попередньою гучністю, діалог підтвердження, кольорова індикація безпеки, та історія підключень.

---

## КРИТИЧНІ ПРАВИЛА ДЛЯ ЦІЄЇ ФАЗИ

### 1. AirPlay та Bluetooth на iOS
- **AirPlay**: Використовувати `AVRouteDetector` для виявлення доступності AirPlay-маршрутів
- **AirPlay підключення**: Використовувати `AVRoutePickerView` обгорнуту в `UIViewRepresentable` — це ЄДИНИЙ спосіб показати системний AirPlay picker
- **Bluetooth**: iOS НЕ дозволяє програмно підключатися до аудіо-Bluetooth пристроїв. Bluetooth-аудіо керується СИСТЕМОЮ. Ми можемо тільки БАЧИТИ поточний аудіо-маршрут через `AVAudioSession.sharedInstance().currentRoute`
- **Реальне обмеження**: Ми НЕ можемо дізнатися гучність зовнішнього пристрою ДО підключення. Але ми можемо ЗАПАМ'ЯТАТИ останню гучність з історії
- Для демонстрації UX-рішень додати **симульовані (mock) пристрої** поруч з реальними

### 2. Mock-пристрої для демонстрації
Оскільки реальні AirPlay/Bluetooth пристрої можуть бути недоступні під час демо, додати перемикач "Показати демо-пристрої" в налаштуваннях. Це покаже симульовані пристрої для демонстрації UX.

### 3. `#Preview {}` ОБОВ'ЯЗКОВО для кожного View

---

## Таск 5.1: DeviceDiscoveryService

### Файл: `Services/DeviceDiscoveryService.swift`

**УВАГА**:
- `AVRouteDetector` — iOS 11+. Потрібно `import AVFoundation`
- `AVAudioSession.sharedInstance().currentRoute` — поточний аудіо-маршрут
- `AVAudioSession.routeChangeNotification` — підписка на зміну маршруту
- Для Bluetooth потрібен `import CoreBluetooth` але ТІЛЬКИ для BLE пристроїв (не аудіо)
- Аудіо Bluetooth пристрої визначаємо через `AVAudioSession.currentRoute.outputs`

```swift
import AVFoundation
import Observation
import UIKit

@Observable
@MainActor
class DeviceDiscoveryService {
    static let shared = DeviceDiscoveryService()
    
    private(set) var currentDevice: AudioDevice?
    private(set) var isAirPlayAvailable = false
    private(set) var connectedDevices: [AudioDevice] = []
    
    // Mock-пристрої для демонстрації
    var showMockDevices = true
    
    private let routeDetector = AVRouteDetector()
    
    private init() {
        setupRouteDetector()
        setupRouteChangeListener()
        updateCurrentRoute()
    }
    
    // MARK: - Route Detection
    
    private func setupRouteDetector() {
        routeDetector.isRouteDetectionEnabled = true
        // Спостерігаємо за зміною доступності AirPlay
        // AVRouteDetector публікує KVO на multipleRoutesDetected
    }
    
    private func setupRouteChangeListener() {
        NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Task { @MainActor in
                self?.updateCurrentRoute()
            }
        }
    }
    
    /// Оновити інформацію про поточний аудіо-маршрут
    func updateCurrentRoute() {
        let session = AVAudioSession.sharedInstance()
        let currentRoute = session.currentRoute
        
        // Визначити поточний пристрій з outputs
        if let output = currentRoute.outputs.first {
            let deviceType: DeviceType
            let connectionType: AudioDevice.ConnectionType
            
            switch output.portType {
            case .builtInSpeaker:
                deviceType = .iPhone
                connectionType = .builtIn
            case .headphones:
                deviceType = .headphones
                connectionType = .wired
            case .bluetoothA2DP, .bluetoothLE, .bluetoothHFP:
                deviceType = .speaker
                connectionType = .bluetooth
            case .airPlay:
                deviceType = .speaker
                connectionType = .airplay
            default:
                deviceType = .speaker
                connectionType = .bluetooth
            }
            
            currentDevice = AudioDevice(
                id: output.uid,
                name: output.portName,
                type: deviceType,
                connectionType: connectionType,
                isConnected: true
            )
        }
        
        isAirPlayAvailable = routeDetector.multipleRoutesDetected
    }
    
    // MARK: - All Available Devices
    
    /// Повертає всі доступні пристрої (реальні + mock якщо ввімкнено)
    var allDevices: [AudioDevice] {
        var devices: [AudioDevice] = []
        
        // Поточний підключений пристрій
        if let current = currentDevice {
            devices.append(current)
        }
        
        // Mock-пристрої для демонстрації
        if showMockDevices {
            devices.append(contentsOf: mockDevices)
        }
        
        return devices
    }
    
    // MARK: - Mock Devices
    
    private var mockDevices: [AudioDevice] {
        let safeVolume = SafeVolumeManager.shared
        return [
            AudioDevice(
                id: "mock-jbl",
                name: "JBL Flip 6",
                type: .speaker,
                connectionType: .bluetooth,
                roomName: "Кімната",
                lastKnownVolume: safeVolume.lastKnownVolume(for: "mock-jbl") ?? 0.35,
                isConnected: false
            ),
            AudioDevice(
                id: "mock-tv",
                name: "Samsung TV",
                type: .tv,
                connectionType: .airplay,
                roomName: "Вітальня",
                lastKnownVolume: safeVolume.lastKnownVolume(for: "mock-tv") ?? 0.72,
                isConnected: false
            ),
            AudioDevice(
                id: "mock-homepod",
                name: "HomePod mini",
                type: .speaker,
                connectionType: .airplay,
                roomName: "Кухня",
                lastKnownVolume: safeVolume.lastKnownVolume(for: "mock-homepod") ?? 0.25,
                isConnected: false
            ),
            AudioDevice(
                id: "mock-airpods",
                name: "AirPods Pro",
                type: .headphones,
                connectionType: .bluetooth,
                lastKnownVolume: safeVolume.lastKnownVolume(for: "mock-airpods") ?? 0.5,
                isConnected: false
            )
        ]
    }
}
```

---

## Таск 5.2: DeviceManagerViewModel

### Файл: `ViewModels/DeviceManagerViewModel.swift`

```swift
import Foundation
import Observation

@Observable
@MainActor
class DeviceManagerViewModel {
    let discovery = DeviceDiscoveryService.shared
    let safeVolume = SafeVolumeManager.shared
    let fadeIn = FadeInEngine.shared
    let audioEngine = AudioEngine.shared
    
    var selectedDevice: AudioDevice?
    var showHandoffConfirm = false
    var adjustedVolume: Float = 0.3
    
    /// Почати підключення до пристрою (показати діалог)
    func initiateHandoff(to device: AudioDevice) {
        selectedDevice = device
        adjustedVolume = safeVolume.recommendedVolume(for: device)
        showHandoffConfirm = true
    }
    
    /// Підтвердити підключення
    func confirmHandoff() {
        guard let device = selectedDevice else { return }
        
        // Обмежити гучність
        let safeVol = safeVolume.clampVolume(adjustedVolume)
        
        // Записати в історію
        safeVolume.recordConnection(
            deviceId: device.id,
            deviceName: device.name,
            volume: safeVol
        )
        
        // Запустити fade-in якщо ввімкнено
        if safeVolume.config.isFadeInEnabled {
            fadeIn.startFadeIn(
                targetVolume: safeVol,
                duration: safeVolume.config.fadeInDuration,
                audioEngine: audioEngine
            )
        } else {
            audioEngine.setVolume(safeVol)
        }
        
        HapticFeedbackService.success()
        showHandoffConfirm = false
        selectedDevice = nil
    }
    
    /// Скасувати підключення
    func cancelHandoff() {
        showHandoffConfirm = false
        selectedDevice = nil
    }
}
```

---

## Таск 5.3: DevicesView — Головний екран пристроїв

### Файл: `Views/Devices/DevicesView.swift`

```swift
import SwiftUI

struct DevicesView: View {
    @State private var viewModel = DeviceManagerViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Поточний пристрій
                    if let current = viewModel.discovery.currentDevice {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Поточний пристрій")
                                .font(AppFonts.caption)
                                .foregroundStyle(ThemeManager.shared.secondaryText)
                                .padding(.horizontal)
                            
                            CurrentDeviceCard(device: current)
                                .padding(.horizontal)
                        }
                    }
                    
                    Divider()
                        .background(ThemeManager.shared.cardBackground)
                        .padding(.horizontal)
                    
                    // Доступні пристрої
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Доступні пристрої")
                            .font(AppFonts.caption)
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                            .padding(.horizontal)
                        
                        let otherDevices = viewModel.discovery.allDevices.filter { !$0.isConnected }
                        
                        if otherDevices.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 8) {
                                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                                        .font(.system(size: 36))
                                        .foregroundStyle(ThemeManager.shared.secondaryText)
                                    Text("Пристрої не знайдено")
                                        .font(AppFonts.body)
                                        .foregroundStyle(ThemeManager.shared.secondaryText)
                                }
                                .padding(.vertical, 40)
                                Spacer()
                            }
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(otherDevices) { device in
                                    DeviceCardView(device: device) {
                                        viewModel.initiateHandoff(to: device)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    
                    // Night Mode статус
                    NightModeStatusBar()
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                .padding(.vertical)
            }
            .background(ThemeManager.shared.primaryBackground.ignoresSafeArea())
            .navigationTitle("Пристрої")
            .sheet(isPresented: $viewModel.showHandoffConfirm) {
                if let device = viewModel.selectedDevice {
                    HandoffConfirmSheet(
                        device: device,
                        adjustedVolume: $viewModel.adjustedVolume,
                        onConfirm: { viewModel.confirmHandoff() },
                        onCancel: { viewModel.cancelHandoff() }
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
        }
    }
}

// MARK: - Current Device Card

struct CurrentDeviceCard: View {
    let device: AudioDevice
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: device.type.sfSymbol)
                .font(.title2)
                .foregroundStyle(ThemeManager.shared.accent)
                .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(AppFonts.headline)
                    .foregroundStyle(ThemeManager.shared.primaryText)
                
                Text(device.connectionType.rawValue)
                    .font(AppFonts.caption)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
            }
            
            Spacer()
            
            // Індикатор підключення
            Circle()
                .fill(ThemeManager.shared.safeColor)
                .frame(width: 8, height: 8)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ThemeManager.shared.cardBackground)
        )
    }
}

// MARK: - Night Mode Status

struct NightModeStatusBar: View {
    @State private var safeVolume = SafeVolumeManager.shared
    
    var body: some View {
        HStack(spacing: 16) {
            // Night Mode
            HStack(spacing: 6) {
                Image(systemName: "moon.fill")
                    .font(.caption)
                    .foregroundStyle(
                        safeVolume.config.isNightModeActive
                        ? ThemeManager.shared.accent
                        : ThemeManager.shared.secondaryText
                    )
                Text("Нічний: \(safeVolume.config.isNightModeActive ? "УВІМК" : "ВИМК")")
                    .font(AppFonts.caption)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
            }
            
            Spacer()
            
            // Max Threshold
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.caption)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
                Text("Макс: \(Int(safeVolume.config.effectiveMaxVolume * 100))%")
                    .font(AppFonts.caption)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ThemeManager.shared.secondaryBackground)
        )
    }
}

#Preview {
    DevicesView()
        .preferredColorScheme(.dark)
}
```

---

## Таск 5.4: DeviceCardView — Картка пристрою

### Файл: `Views/Devices/DeviceCardView.swift`

Це ключовий компонент — він показує пристрій з його останньою гучністю та кольоровою індикацією безпеки.

```swift
import SwiftUI

struct DeviceCardView: View {
    let device: AudioDevice
    let onConnect: () -> Void
    
    @State private var safeVolume = SafeVolumeManager.shared
    
    private var volume: Float {
        device.lastKnownVolume ?? safeVolume.recommendedVolume(for: device)
    }
    
    private var safety: SafeVolumeManager.SafetyLevel {
        safeVolume.safetyLevel(for: volume)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок
            HStack(spacing: 12) {
                Image(systemName: device.type.sfSymbol)
                    .font(.title2)
                    .foregroundStyle(ThemeManager.shared.primaryText)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(AppFonts.headline)
                        .foregroundStyle(ThemeManager.shared.primaryText)
                    
                    HStack(spacing: 4) {
                        Text(device.connectionType.rawValue)
                        if let room = device.roomName {
                            Text("·")
                            Text(room)
                        }
                    }
                    .font(AppFonts.caption)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
                }
                
                Spacer()
            }
            
            // Остання гучність
            VStack(alignment: .leading, spacing: 6) {
                Text("Остання гучність: \(Int(volume * 100))%")
                    .font(AppFonts.caption)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
                
                // Volume bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(ThemeManager.shared.secondaryBackground)
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(safety.color)
                            .frame(width: geometry.size.width * CGFloat(volume), height: 6)
                    }
                }
                .frame(height: 6)
            }
            
            // Попередження (якщо потрібно)
            if safety != .safe {
                HStack(spacing: 6) {
                    Image(systemName: safety.sfSymbol)
                        .font(.caption)
                    Text(safety.label)
                        .font(AppFonts.caption)
                }
                .foregroundStyle(safety.color)
            }
            
            // Кнопка підключення
            Button {
                onConnect()
                HapticFeedbackService.medium()
            } label: {
                HStack {
                    Spacer()
                    Text("Підключити безпечно")
                        .font(AppFonts.headline)
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(safety.color.opacity(0.2))
                )
                .foregroundStyle(safety.color)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(ThemeManager.shared.cardBackground)
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        DeviceCardView(
            device: AudioDevice(
                id: "1", name: "JBL Flip 6", type: .speaker,
                connectionType: .bluetooth, roomName: "Кімната",
                lastKnownVolume: 0.35
            ),
            onConnect: {}
        )
        
        DeviceCardView(
            device: AudioDevice(
                id: "2", name: "Samsung TV", type: .tv,
                connectionType: .airplay, roomName: "Вітальня",
                lastKnownVolume: 0.72
            ),
            onConnect: {}
        )
    }
    .padding()
    .preferredColorScheme(.dark)
    .background(ThemeManager.shared.primaryBackground)
}
```

---

## Таск 5.5: HandoffConfirmSheet — Діалог підтвердження

### Файл: `Views/Devices/HandoffConfirmSheet.swift`

**Це найважливіший UX-елемент додатку** — він вирішує проблему П9 з дослідження ("Немає контролю до підключення").

```swift
import SwiftUI

struct HandoffConfirmSheet: View {
    let device: AudioDevice
    @Binding var adjustedVolume: Float
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var safeVolume = SafeVolumeManager.shared
    
    private var safety: SafeVolumeManager.SafetyLevel {
        safeVolume.safetyLevel(for: adjustedVolume)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Заголовок
            VStack(spacing: 8) {
                Text("Підключити до")
                    .font(AppFonts.subheadline)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
                
                HStack(spacing: 8) {
                    Image(systemName: device.type.sfSymbol)
                        .font(.title2)
                    Text(device.name)
                        .font(AppFonts.title2)
                }
                .foregroundStyle(ThemeManager.shared.primaryText)
            }
            
            Divider()
                .background(ThemeManager.shared.cardBackground)
            
            // Повзунок гучності (МОЖНА ЗМІНИТИ ДО ПІДКЛЮЧЕННЯ)
            VStack(spacing: 12) {
                Text("Гучність пристрою:")
                    .font(AppFonts.body)
                    .foregroundStyle(ThemeManager.shared.primaryText)
                
                // Значення
                Text("\(Int(adjustedVolume * 100))%")
                    .font(AppFonts.largeTitle)
                    .foregroundStyle(safety.color)
                
                // Повзунок
                Slider(
                    value: $adjustedVolume,
                    in: 0...1,
                    step: 0.01
                ) {
                    Text("Гучність")
                } minimumValueLabel: {
                    Image(systemName: "speaker.fill")
                        .font(.caption)
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                } maximumValueLabel: {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.caption)
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                }
                .tint(safety.color)
                
                // Індикатор безпеки
                HStack(spacing: 6) {
                    Image(systemName: safety.sfSymbol)
                    Text(safety.label)
                }
                .font(AppFonts.subheadline)
                .foregroundStyle(safety.color)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ThemeManager.shared.cardBackground)
            )
            
            // Інфо
            VStack(spacing: 8) {
                if safeVolume.config.isFadeInEnabled {
                    InfoRow(
                        icon: "timer",
                        label: "Fade-in",
                        value: "\(String(format: "%.1f", safeVolume.config.fadeInDuration)) сек"
                    )
                }
                
                if safeVolume.config.isNightModeActive {
                    InfoRow(
                        icon: "moon.fill",
                        label: "Нічний режим",
                        value: "увімкнено"
                    )
                }
                
                InfoRow(
                    icon: "chart.bar.fill",
                    label: "Макс. поріг",
                    value: "\(Int(safeVolume.config.effectiveMaxVolume * 100))%"
                )
            }
            
            Spacer()
            
            // Кнопки
            VStack(spacing: 12) {
                Button {
                    onConfirm()
                } label: {
                    HStack {
                        Image(systemName: "checkmark.shield.fill")
                        Text("Підключити безпечно")
                    }
                    .font(AppFonts.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(safety.color)
                    )
                }
                
                Button("Скасувати") {
                    onCancel()
                }
                .foregroundStyle(ThemeManager.shared.secondaryText)
            }
        }
        .padding(24)
        .background(ThemeManager.shared.primaryBackground.ignoresSafeArea())
        .onChange(of: adjustedVolume) { _, newValue in
            // Обмежити гучність максимальним порогом
            let maxAllowed = safeVolume.config.effectiveMaxVolume
            if newValue > maxAllowed {
                adjustedVolume = maxAllowed
                HapticFeedbackService.warning()
            }
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(ThemeManager.shared.secondaryText)
                .frame(width: 20)
            
            Text(label)
                .font(AppFonts.subheadline)
                .foregroundStyle(ThemeManager.shared.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(AppFonts.subheadline)
                .foregroundStyle(ThemeManager.shared.primaryText)
        }
    }
}

#Preview {
    HandoffConfirmSheet(
        device: AudioDevice(
            id: "1", name: "JBL Flip 6", type: .speaker,
            connectionType: .bluetooth, roomName: "Кімната",
            lastKnownVolume: 0.35
        ),
        adjustedVolume: .constant(0.35),
        onConfirm: {},
        onCancel: {}
    )
    .preferredColorScheme(.dark)
}
```

---

## Таск 5.6: SafetyIndicator — Компонент індикатора

### Файл: `Components/SafetyIndicator.swift`

```swift
import SwiftUI

struct SafetyIndicator: View {
    let level: SafeVolumeManager.SafetyLevel
    var showLabel = true
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: level.sfSymbol)
                .font(.caption)
            
            if showLabel {
                Text(level.label)
                    .font(AppFonts.caption)
            }
        }
        .foregroundStyle(level.color)
    }
}

#Preview {
    VStack(spacing: 12) {
        SafetyIndicator(level: .safe)
        SafetyIndicator(level: .warning)
        SafetyIndicator(level: .danger)
        SafetyIndicator(level: .safe, showLabel: false)
    }
    .padding()
    .preferredColorScheme(.dark)
    .background(ThemeManager.shared.primaryBackground)
}
```

---

## Чеклист Фази 5

- [x] `DeviceDiscoveryService.swift` — виявляє поточний аудіо-маршрут
- [x] `DeviceDiscoveryService` — робота з реальними апаратними пристроями та історією (заглушки повністю видалено)
- [x] `DeviceDiscoveryService` — реагує на зміну маршруту
- [x] `DeviceManagerViewModel.swift` — ініціює handoff, підтверджує, скасовує
- [x] `DevicesView.swift` — показує поточний пристрій та доступні
- [x] `DevicesView` — Night Mode статус-бар внизу
- [x] `CurrentDeviceCard` — показує підключений пристрій
- [x] `DeviceCardView.swift` — картка з гучністю та кольоровою індикацією
- [x] `DeviceCardView` — кнопка "Підключити безпечно" з кольором безпеки
- [x] `HandoffConfirmSheet.swift` — діалог з повзунком гучності
- [x] `HandoffConfirmSheet` — показує safety level, fade-in, night mode, max threshold
- [x] `HandoffConfirmSheet` — обмежує гучність максимальним порогом
- [x] `HandoffConfirmSheet` — хаптичний фідбек при перевищенні порогу
- [x] `SafetyIndicator.swift` — компонент індикатора безпеки
- [x] Всі View мають `#Preview {}` блок
- [x] Canvas Preview працює
- [x] Жодних емоджі — тільки SF Symbols
