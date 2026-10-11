import AVFoundation
import Observation
import UIKit

@Observable
@MainActor
class DeviceDiscoveryService {
    static let shared = DeviceDiscoveryService()
    
    private(set) var currentDevice: AudioDevice?
    private(set) var isAirPlayAvailable = false
    
    /// Зберігає останній реально підключений Bluetooth пристрій,
    /// щоб коли звук перемикається на динамік iPhone або на Mac,
    /// колонка залишалася видимою у списку пристроїв для повернення звуку на неї.
    private(set) var connectedBluetoothDevice: AudioDevice?
    private(set) var isSpeakerOverridden: Bool = false
    
    /// Прапорець перемикання маршруту — запобігає перетиранню гучності проміжними KVO-подіями
    private(set) var isHandoffSwitching: Bool = false
    private(set) var pendingTargetVolume: Float?
    private(set) var pendingTargetDeviceId: String?
    
    private let routeDetector = AVRouteDetector()
    private var routeChangeObserver: NSObjectProtocol?
    private var airplayObserver: NSObjectProtocol?
    
    private let lastBtDeviceKey = "Castlie_LastConnectedBluetoothDevice"
    
    private func saveLastConnectedBluetoothDevice(_ device: AudioDevice?) {
        if let device, let data = try? JSONEncoder().encode(device) {
            UserDefaults.standard.set(data, forKey: lastBtDeviceKey)
        } else {
            UserDefaults.standard.removeObject(forKey: lastBtDeviceKey)
        }
    }
    
    private static func loadLastConnectedBluetoothDevice() -> AudioDevice? {
        guard let data = UserDefaults.standard.data(forKey: "Castlie_LastConnectedBluetoothDevice"),
              let dev = try? JSONDecoder().decode(AudioDevice.self, from: data) else {
            return nil
        }
        return dev
    }
    
    private init() {
        self.connectedBluetoothDevice = Self.loadLastConnectedBluetoothDevice()
        setupRouteDetector()
        setupRouteChangeListener()
        updateCurrentRoute(syncVolume: false)
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
            let prevOutput = (notification.userInfo?[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription)?.outputs.first
            let previousOutputId = prevOutput?.uid
            let previousOutputName = prevOutput?.portName
            let reasonValue = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            let reason = reasonValue != nil ? AVAudioSession.RouteChangeReason(rawValue: reasonValue!) : nil
            
            Task { @MainActor in
                self?.handleAudioRouteChange(
                    previousOutputId: previousOutputId,
                    previousOutputName: previousOutputName,
                    reason: reason
                )
            }
        }
    }
    
    /// Оновити інформацію про поточний аудіо-маршрут
    func updateCurrentRoute(syncVolume: Bool = true) {
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
            
            let realHardwareVolume = session.outputVolume
            if syncVolume && !isHandoffSwitching {
                AudioEngine.shared.syncSystemVolume(realHardwareVolume)
            }
            
            let newDevice = AudioDevice(
                id: output.uid,
                name: output.portName,
                type: deviceType,
                connectionType: connectionType,
                lastKnownVolume: realHardwareVolume,
                isConnected: true
            )
            
            currentDevice = newDevice
            
            // Якщо зараз активно грає через Bluetooth — фіксуємо його
            if connectionType == .bluetooth {
                connectedBluetoothDevice = newDevice
                saveLastConnectedBluetoothDevice(newDevice)
                isSpeakerOverridden = false
            }
        } else {
            let realHardwareVolume = session.outputVolume
            if syncVolume && !isHandoffSwitching {
                AudioEngine.shared.syncSystemVolume(realHardwareVolume)
            }
            
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
    
    /// Обробка реальної зміни аудіо-маршруту
    private func handleAudioRouteChange(
        previousOutputId: String?,
        previousOutputName: String?,
        reason: AVAudioSession.RouteChangeReason?
    ) {
        // Якщо пристрій фізично вимкнули або роз'єднали — видаляємо його
        if reason == .oldDeviceUnavailable {
            if let prevId = previousOutputId, connectedBluetoothDevice?.id == prevId {
                connectedBluetoothDevice = nil
                saveLastConnectedBluetoothDevice(nil)
                isSpeakerOverridden = false
            } else if let prevName = previousOutputName?.lowercased(),
                      connectedBluetoothDevice?.name.lowercased() == prevName {
                connectedBluetoothDevice = nil
                saveLastConnectedBluetoothDevice(nil)
                isSpeakerOverridden = false
            }
        }
        
        updateCurrentRoute()
        
        guard let current = currentDevice else { return }
        let isRealDeviceChange = (current.id != previousOutputId)
        
        if isHandoffSwitching, let targetVol = pendingTargetVolume {
            // Програмне перемикання: гарантовано застосовуємо вибрану користувачем гучність
            SystemVolumeController.shared.setSystemVolume(targetVol)
            AudioEngine.shared.setVolume(targetVol)
            SafeVolumeManager.shared.updateDeviceVolume(
                deviceId: current.id,
                deviceName: current.name,
                volume: targetVol
            )
        } else if isRealDeviceChange && reason != .categoryChange {
            // Зовнішня зміна маршруту (наприклад, користувач підключив навушники)
            let savedVol = SafeVolumeManager.shared.lastKnownVolume(for: current)
                ?? SafeVolumeManager.shared.recommendedVolume(for: current)
            
            SystemVolumeController.shared.setSystemVolume(savedVol)
            AudioEngine.shared.setVolume(savedVol)
            SafeVolumeManager.shared.updateDeviceVolume(
                deviceId: current.id,
                deviceName: current.name,
                volume: savedVol
            )
            
            if AudioEngine.shared.isPlaying && SafeVolumeManager.shared.config.isFadeInEnabled {
                FadeInEngine.shared.startFadeIn(
                    duration: SafeVolumeManager.shared.config.fadeInDuration,
                    audioEngine: AudioEngine.shared
                )
            }
            
            HapticFeedbackService.light()
        }
    }
    
    /// Зберегти Bluetooth-пристрій у пам'яті для подальшого швидкого повернення
    func preserveBluetoothDevice(_ device: AudioDevice) {
        if device.connectionType == .bluetooth {
            self.connectedBluetoothDevice = device
            saveLastConnectedBluetoothDevice(device)
        }
    }
    
    // MARK: - Live Connected Bluetooth Devices (ONLY physically connected right now)
    
    /// Повертає ТІЛЬКИ ті Bluetooth-пристрої, які ФІЗИЧНО підключені та готові до роботи в цей момент.
    /// Залишається видимим навіть при перемиканні на Mac або динамік iPhone!
    var connectedBluetoothDevices: [AudioDevice] {
        var result: [AudioDevice] = []
        var seenNames = Set<String>()
        
        let currentNameNorm = currentDevice?.name.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        let currentId = currentDevice?.id ?? ""
        let isRemoteActive = CastlieConnectService.shared.activeRemoteDevice != nil
        
        if !currentNameNorm.isEmpty && !isRemoteActive {
            seenNames.insert(currentNameNorm)
        }
        
        // 1. Якщо активний Mac, а поточний маршрут iPhone — це Bluetooth колонка:
        if isRemoteActive, let cur = currentDevice, cur.connectionType == .bluetooth {
            let nameNorm = cur.name.trimmingCharacters(in: .whitespaces).lowercased()
            if !seenNames.contains(nameNorm) {
                seenNames.insert(nameNorm)
                var dev = cur
                dev.lastKnownVolume = SafeVolumeManager.shared.lastKnownVolume(for: cur) ?? cur.lastKnownVolume
                result.append(dev)
            }
        }
        
        // 2. Останній підключений або збережений Bluetooth пристрій (колонка або навушники):
        if let btDev = connectedBluetoothDevice {
            let nameNorm = btDev.name.trimmingCharacters(in: .whitespaces).lowercased()
            let isCurrentLocal = (nameNorm == currentNameNorm || btDev.id == currentId)
            
            // Показуємо пристрій, якщо:
            // а) зараз активний Mac (щоб можна було повернутись на Bluetooth-колонку)
            // б) або локально активний динамік iPhone (Bluetooth-колонка не грає прямо зараз)
            if (isRemoteActive || !isCurrentLocal) && !seenNames.contains(nameNorm) {
                seenNames.insert(nameNorm)
                var dev = btDev
                dev.lastKnownVolume = SafeVolumeManager.shared.lastKnownVolume(for: btDev) ?? btDev.lastKnownVolume
                result.append(dev)
            }
        }
        
        // 3. Реально підключені аудіопорти з AVAudioSession
        let session = AVAudioSession.sharedInstance()
        for output in session.currentRoute.outputs {
            if output.portType == .bluetoothA2DP || output.portType == .bluetoothLE || output.portType == .bluetoothHFP {
                let name = output.portName
                let nameNorm = name.trimmingCharacters(in: .whitespaces).lowercased()
                let isCurrentLocal = (nameNorm == currentNameNorm || output.uid == currentId)
                if (isRemoteActive || !isCurrentLocal) && !seenNames.contains(nameNorm) {
                    seenNames.insert(nameNorm)
                    let vol = SafeVolumeManager.shared.lastKnownVolume(for: output.uid)
                        ?? SafeVolumeManager.shared.lastKnownVolume(forDeviceName: name)
                        ?? session.outputVolume
                    let devType: DeviceType = nameNorm.contains("airpod") || nameNorm.contains("headphone") ? .headphones : .speaker
                    result.append(AudioDevice(
                        id: output.uid,
                        name: name,
                        type: devType,
                        connectionType: .bluetooth,
                        lastKnownVolume: vol,
                        isConnected: true
                    ))
                }
            }
        }
        
        return result
    }
    
    // MARK: - System Audio Route Switching
    
    /// Перемкнути аудіо-вихід на Bluetooth-пристрій із незалежною гучністю
    func switchToBluetoothDevice(_ device: AudioDevice, targetVolume: Float? = nil) {
        let session = AVAudioSession.sharedInstance()
        
        // 1. Зберігаємо поточний пристрій і його гучність перед перемиканням
        if let cur = currentDevice {
            SafeVolumeManager.shared.updateDeviceVolume(
                deviceId: cur.id,
                deviceName: cur.name,
                volume: AudioEngine.shared.volume
            )
        }
        
        // 2. Визначаємо цільову гучність для Bluetooth пристрою
        let desiredVolume = targetVolume
            ?? SafeVolumeManager.shared.lastKnownVolume(for: device)
            ?? SafeVolumeManager.shared.recommendedVolume(for: device)
        
        isHandoffSwitching = true
        pendingTargetVolume = desiredVolume
        pendingTargetDeviceId = device.id
        isSpeakerOverridden = false
        
        // 3. Скидаємо override динаміка якщо він був активний
        try? session.overrideOutputAudioPort(.none)
        
        print("[Discovery] ✅ Системно перемкнуто звук на Bluetooth: \(device.name), гучність: \(Int(desiredVolume * 100))%")
        
        // 4. Застосовуємо вибрану гучність до системи та збереження
        SystemVolumeController.shared.setSystemVolume(desiredVolume)
        AudioEngine.shared.setVolume(desiredVolume)
        SafeVolumeManager.shared.updateDeviceVolume(
            deviceId: device.id,
            deviceName: device.name,
            volume: desiredVolume
        )
        
        connectedBluetoothDevice = device
        saveLastConnectedBluetoothDevice(device)
        
        if AudioEngine.shared.isPlaying && SafeVolumeManager.shared.config.isFadeInEnabled {
            FadeInEngine.shared.startFadeIn(
                duration: SafeVolumeManager.shared.config.fadeInDuration,
                audioEngine: AudioEngine.shared
            )
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            self.updateCurrentRoute()
            SystemVolumeController.shared.setSystemVolume(desiredVolume)
            self.isHandoffSwitching = false
            self.pendingTargetVolume = nil
            self.pendingTargetDeviceId = nil
        }
    }
    
    /// Перемкнути аудіо-вихід назад на вбудований динамік iPhone із відновленням його гучності
    func switchToBuiltInSpeaker(targetVolume: Float? = nil) {
        let session = AVAudioSession.sharedInstance()
        
        // 1. Зберігаємо поточний Bluetooth пристрій та його гучність перед перемиканням
        if let current = currentDevice {
            SafeVolumeManager.shared.updateDeviceVolume(
                deviceId: current.id,
                deviceName: current.name,
                volume: AudioEngine.shared.volume
            )
            if current.connectionType == .bluetooth {
                preserveBluetoothDevice(current)
            }
        }
        
        // 2. Визначаємо збережену незалежну гучність для iPhone
        let iphoneVolume = targetVolume
            ?? SafeVolumeManager.shared.lastKnownVolume(for: "builtin-speaker")
            ?? SafeVolumeManager.shared.lastKnownVolume(forDeviceName: "iPhone")
            ?? 0.35
        
        isHandoffSwitching = true
        pendingTargetVolume = iphoneVolume
        pendingTargetDeviceId = "builtin-speaker"
        isSpeakerOverridden = true
        
        // Спробуємо активувати override динаміка
        try? session.overrideOutputAudioPort(.speaker)
        print("[Discovery] ✅ Системно перемкнуто на вбудований динамік iPhone, гучність: \(Int(iphoneVolume * 100))%")
        
        // 3. Застосовуємо відновлену гучність iPhone
        SystemVolumeController.shared.setSystemVolume(iphoneVolume)
        AudioEngine.shared.setVolume(iphoneVolume)
        SafeVolumeManager.shared.updateDeviceVolume(
            deviceId: "builtin-speaker",
            deviceName: "iPhone",
            volume: iphoneVolume
        )
        
        if AudioEngine.shared.isPlaying && SafeVolumeManager.shared.config.isFadeInEnabled {
            FadeInEngine.shared.startFadeIn(
                duration: SafeVolumeManager.shared.config.fadeInDuration,
                audioEngine: AudioEngine.shared
            )
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            self.updateCurrentRoute()
            SystemVolumeController.shared.setSystemVolume(iphoneVolume)
            self.isHandoffSwitching = false
            self.pendingTargetVolume = nil
            self.pendingTargetDeviceId = nil
        }
    }
}
