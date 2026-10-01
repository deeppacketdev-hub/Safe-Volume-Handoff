import AVFoundation
import Observation
import UIKit

@Observable
@MainActor
class DeviceDiscoveryService {
    static let shared = DeviceDiscoveryService()
    
    private(set) var currentDevice: AudioDevice?
    private(set) var isAirPlayAvailable = false
    var showMockDevices: Bool = true {
        didSet {
            UserDefaults.standard.set(showMockDevices, forKey: "ShowMockDevices")
        }
    }
    
    private let routeDetector = AVRouteDetector()
    private var routeChangeObserver: NSObjectProtocol?
    private var airplayObserver: NSObjectProtocol?
    
    private init() {
        if UserDefaults.standard.object(forKey: "ShowMockDevices") != nil {
            showMockDevices = UserDefaults.standard.bool(forKey: "ShowMockDevices")
        }
        setupRouteDetector()
        setupRouteChangeListener()
        updateCurrentRoute()
    }
    
    // MARK: - Route Detection
    
    private func setupRouteDetector() {
        routeDetector.isRouteDetectionEnabled = true
        isAirPlayAvailable = routeDetector.multipleRoutesDetected
        
        airplayObserver = NotificationCenter.default.addObserver(
            forName: .AVRouteDetectorMultipleRoutesDetectedDidChange,
            object: routeDetector,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isAirPlayAvailable = self.routeDetector.multipleRoutesDetected
            }
        }
    }
    
    private func setupRouteChangeListener() {
        routeChangeObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let previousOutputId = (notification.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription)?.outputs.first?.uid
            Task { @MainActor in
                self?.handleAudioRouteChange(previousOutputId: previousOutputId)
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
            case .builtInSpeaker, .builtInReceiver:
                deviceType = .iPhone
                connectionType = .builtIn
            case .headphones:
                deviceType = .headphones
                connectionType = .wired
            case .bluetoothA2DP, .bluetoothLE, .bluetoothHFP:
                let portNameLower = output.portName.lowercased()
                deviceType = portNameLower.contains("airpod") || portNameLower.contains("headphone") ? .headphones : .speaker
                connectionType = .bluetooth
            case .airPlay:
                let portNameLower = output.portName.lowercased()
                if portNameLower.contains("mac") || portNameLower.contains("macbook") {
                    deviceType = .mac
                } else if portNameLower.contains("tv") {
                    deviceType = .tv
                } else {
                    deviceType = .speaker
                }
                connectionType = .airplay
            default:
                let portNameLower = output.portName.lowercased()
                if portNameLower.contains("mac") || portNameLower.contains("macbook") {
                    deviceType = .mac
                    connectionType = .airplay
                } else {
                    deviceType = .speaker
                    connectionType = .bluetooth
                }
            }
            
            // Реальна апаратна гучність підключеного пристрою (Mac, AirPlay, Bluetooth або динамік)
            let realHardwareVolume = AVAudioSession.sharedInstance().outputVolume
            AudioEngine.shared.syncSystemVolume(realHardwareVolume)
            
            currentDevice = AudioDevice(
                id: output.uid,
                name: output.portName,
                type: deviceType,
                connectionType: connectionType,
                lastKnownVolume: realHardwareVolume,
                isConnected: true
            )
        } else {
            let realHardwareVolume = AVAudioSession.sharedInstance().outputVolume
            AudioEngine.shared.syncSystemVolume(realHardwareVolume)
            
            currentDevice = AudioDevice(
                id: "builtin-speaker",
                name: "iPhone",
                type: .iPhone,
                connectionType: .builtIn,
                lastKnownVolume: realHardwareVolume,
                isConnected: true
            )
        }
        
        isAirPlayAvailable = routeDetector.multipleRoutesDetected
    }
    
    /// Обробка реальної зміни аудіо-маршруту (підключення навушників, AirPlay, Bluetooth)
    private func handleAudioRouteChange(previousOutputId: String?) {
        updateCurrentRoute()
        
        // Отримуємо реальну актуальну гучність підключеного пристрою
        let realHardwareVolume = AVAudioSession.sharedInstance().outputVolume
        AudioEngine.shared.syncSystemVolume(realHardwareVolume)
        
        if let current = currentDevice, current.id != previousOutputId {
            let maxSafe = SafeVolumeManager.shared.config.effectiveMaxVolume
            if realHardwareVolume > maxSafe {
                // Захищаємо слух, якщо пристрій підключився на небезпечно високій гучності
                applySafeVolumeHandoff(for: current)
            } else {
                // Фіксуємо поточну реальну гучність пристрою
                SafeVolumeManager.shared.recordConnection(
                    deviceId: current.id,
                    deviceName: current.name,
                    volume: realHardwareVolume
                )
                HapticFeedbackService.light()
            }
        }
    }
    
    /// Безпечне перемикання гучності при підключенні пристрою
    func applySafeVolumeHandoff(for device: AudioDevice) {
        let safeVolume = SafeVolumeManager.shared
        let audioEngine = AudioEngine.shared
        let fadeIn = FadeInEngine.shared
        
        // Рекомендована безпечна гучність
        let safeVol = safeVolume.recommendedVolume(for: device)
        
        // Фіксація в історії
        safeVolume.recordConnection(
            deviceId: device.id,
            deviceName: device.name,
            volume: safeVol
        )
        
        // Fade-in або встановлення гучності
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
    }
    
    // MARK: - Real Known Devices from History
    
    /// Повертає збережені реальні пристрої з історії підключень без дублікатів
    var knownDevices: [AudioDevice] {
        let histories = SafeVolumeManager.shared.deviceHistories
        var seenNames = Set<String>()
        var seenIds = Set<String>()
        var result: [AudioDevice] = []
        
        let currentNameNorm = currentDevice?.name.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        let currentId = currentDevice?.id ?? ""
        
        let sortedHistories = histories.sorted { $0.timestamp > $1.timestamp }
        
        for entry in sortedHistories {
            let nameNorm = entry.deviceName.trimmingCharacters(in: .whitespaces).lowercased()
            
            // Якщо це поточний активний пристрій — не показуємо в збережених
            if (!currentNameNorm.isEmpty && nameNorm == currentNameNorm) || (!currentId.isEmpty && entry.deviceId == currentId) {
                continue
            }
            
            // Уникаємо дублювання за назвою або ID
            guard !seenNames.contains(nameNorm) && !seenIds.contains(entry.deviceId) else { continue }
            seenNames.insert(nameNorm)
            seenIds.insert(entry.deviceId)
            
            let deviceType: DeviceType
            let connectionType: AudioDevice.ConnectionType
            
            if nameNorm.contains("mac") || nameNorm.contains("macbook") {
                deviceType = .mac
                connectionType = .airplay
            } else if nameNorm.contains("airpod") || nameNorm.contains("headphone") || nameNorm.contains("навушник") {
                deviceType = .headphones
                connectionType = .bluetooth
            } else if nameNorm.contains("tv") || nameNorm.contains("телевізор") {
                deviceType = .tv
                connectionType = .airplay
            } else if nameNorm.contains("speaker") || nameNorm.contains("колонк") || nameNorm.contains("jbl") {
                deviceType = .speaker
                connectionType = .bluetooth
            } else if nameNorm.contains("iphone") {
                deviceType = .iPhone
                connectionType = .builtIn
            } else {
                deviceType = .speaker
                connectionType = .bluetooth
            }
            
            result.append(AudioDevice(
                id: entry.deviceId,
                name: entry.deviceName,
                type: deviceType,
                connectionType: connectionType,
                lastKnownVolume: entry.volume,
                isConnected: false
            ))
        }
        
        // Mock-пристрої для демонстрації Safe Volume Handoff
        if showMockDevices {
            for mock in mockDevices {
                let mockNameNorm = mock.name.trimmingCharacters(in: .whitespaces).lowercased()
                if !seenNames.contains(mockNameNorm) && mock.id != currentId && mockNameNorm != currentNameNorm {
                    result.append(mock)
                }
            }
        }
        
        return result
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
                roomName: "Особисті",
                lastKnownVolume: safeVolume.lastKnownVolume(for: "mock-airpods") ?? 0.5,
                isConnected: false
            )
        ]
    }
    
    /// Всі доступні та збережені пристрої
    var allDevices: [AudioDevice] {
        var devices: [AudioDevice] = []
        if let current = currentDevice {
            devices.append(current)
        }
        devices.append(contentsOf: knownDevices)
        return devices
    }
}
