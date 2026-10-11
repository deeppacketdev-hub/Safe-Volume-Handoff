import Foundation
import Observation

struct CastlieRemoteDevice: Identifiable, Hashable {
    let id: String
    var name: String
    var volume: Float
    var isPlaying: Bool
    var currentTrackTitle: String?
    var connectedUser: String?
    var isOnline: Bool = true
}

@Observable
@MainActor
final class CastlieConnectService: NSObject {
    static let shared = CastlieConnectService()
    
    // Server Config
    var serverDomain: String {
        didSet {
            UserDefaults.standard.set(serverDomain, forKey: "CastlieServerDomain")
            connect()
        }
    }
    
    private(set) var isConnected: Bool = false
    private(set) var isConnecting: Bool = false
    private(set) var availableReceivers: [CastlieRemoteDevice] = []
    
    // Активний віддалений пристрій (Mac), на який зараз транслюється аудіо
    var activeRemoteDevice: CastlieRemoteDevice? = nil
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var pingTimer: Timer?
    private var reconnectTask: Task<Void, Never>?
    
    private override init() {
        self.serverDomain = UserDefaults.standard.string(forKey: "CastlieServerDomain") ?? "castlie.dron.lol"
        super.init()
        setupSession()
        connect()
    }
    
    private func setupSession() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
    }
    
    // MARK: - Connection
    
    func connect() {
        reconnectTask?.cancel()
        disconnect()
        
        isConnecting = true
        let cleanDomain = serverDomain.trimmingCharacters(in: .whitespacesAndNewlines)
        let urlString = "wss://\(cleanDomain)/ws?roomId=default"
        guard let url = URL(string: urlString) else {
            isConnecting = false
            return
        }
        
        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()
        
        // Register as sender (iPhone)
        registerSender()
        listen()
        startPingTimer()
    }
    
    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
        isConnecting = false
    }
    
    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sendPing()
            }
        }
    }
    
    private func sendPing() {
        webSocketTask?.sendPing { [weak self] error in
            if error != nil {
                Task { @MainActor in
                    self?.handleConnectionFailure()
                }
            }
        }
    }
    
    // MARK: - Messaging
    
    private func registerSender() {
        let payload: [String: Any] = [
            "type": "register",
            "role": "sender",
            "deviceId": "iphone_" + UUID().uuidString.prefix(6),
            "name": "iPhone"
        ]
        send(json: payload)
    }
    
    /// Надіслати трек на віддалений Mac із Safe Fade-In
    func sendHandoff(to deviceId: String, track: Track, previewURL: URL? = nil, targetVolume: Float, fadeInDuration: Double) {
        let finalURLString = previewURL?.absoluteString ?? track.previewURL?.absoluteString
        let payload: [String: Any] = [
            "type": "handoff",
            "targetDeviceId": deviceId,
            "senderName": "iPhone",
            "targetVolume": targetVolume,
            "fadeInDuration": fadeInDuration,
            "track": [
                "id": track.id,
                "name": track.name,
                "artistName": track.artistName,
                "albumName": track.albumName,
                "albumArtURL": track.albumImageURL?.absoluteString as Any,
                "previewURL": finalURLString as Any
            ]
        ]
        send(json: payload)
    }
    
    /// Підключитись до віддаленого Mac для постійного стрімінгу
    func connectToRemote(device: CastlieRemoteDevice) {
        self.activeRemoteDevice = device
        AudioEngine.shared.updateVolumeFromRemote(device.volume)
    }
    
    /// Відключитись від активного Mac і повернути звук на iPhone
    func disconnectActiveRemote() {
        guard let active = activeRemoteDevice else { return }
        sendPlaybackCommand(deviceId: active.id, action: "stop")
        activeRemoteDevice = nil
        if let idx = availableReceivers.firstIndex(where: { $0.id == active.id }) {
            availableReceivers[idx].isPlaying = false
            availableReceivers[idx].connectedUser = nil
        }
        AudioEngine.shared.handleRemoteDisconnected()
    }

    /// Оптимістичне оновлення стану для швидкого відгуку UI
    func markReceiverAsPlaying(deviceId: String, volume: Float) {
        if let idx = availableReceivers.firstIndex(where: { $0.id == deviceId }) {
            availableReceivers[idx].isPlaying = true
            availableReceivers[idx].volume = volume
        }
        if activeRemoteDevice?.id == deviceId {
            activeRemoteDevice?.isPlaying = true
            activeRemoteDevice?.volume = volume
        }
    }
    
    /// Змінити гучність віддаленого пристрою в реальному часі
    func setRemoteVolume(deviceId: String, volume: Float) {
        let clamped = max(0, min(1, volume))
        // Оптимістичне оновлення локального стейту
        if let idx = availableReceivers.firstIndex(where: { $0.id == deviceId }) {
            availableReceivers[idx].volume = clamped
        }
        if activeRemoteDevice?.id == deviceId {
            activeRemoteDevice?.volume = clamped
        }
        
        let payload: [String: Any] = [
            "type": "volume_update",
            "targetDeviceId": deviceId,
            "volume": clamped
        ]
        send(json: payload)
    }
    
    /// Керування відтворенням на Mac (Play / Pause / Toggle / Seek / Stop)
    func sendPlaybackCommand(deviceId: String, action: String, value: Any? = nil) {
        var payload: [String: Any] = [
            "type": "playback_command",
            "targetDeviceId": deviceId,
            "action": action
        ]
        if let value {
            payload["value"] = value
        }
        send(json: payload)
    }
    
    private func send(json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let string = String(data: data, encoding: .utf8) else { return }
        
        webSocketTask?.send(.string(string)) { [weak self] error in
            if error != nil {
                Task { @MainActor in
                    self?.handleConnectionFailure()
                }
            }
        }
    }
    
    // MARK: - Listener
    
    private func listen() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let message):
                    self.isConnected = true
                    self.isConnecting = false
                    
                    switch message {
                    case .string(let text):
                        self.handleIncomingText(text)
                    case .data(let data):
                        if let text = String(data: data, encoding: .utf8) {
                            self.handleIncomingText(text)
                        }
                    @unknown default:
                        break
                    }
                    self.listen()
                    
                case .failure:
                    self.handleConnectionFailure()
                }
            }
        }
    }
    
    private func handleIncomingText(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }
        
        switch type {
        case "registered":
            self.isConnected = true
            self.isConnecting = false
            
        case "devices_list":
            if let list = json["devices"] as? [[String: Any]] {
                var receivers: [CastlieRemoteDevice] = []
                var seenNames = Set<String>()
                for item in list {
                    if let role = item["role"] as? String, role == "receiver",
                       let id = item["deviceId"] as? String,
                       let name = item["name"] as? String {
                        // Дедуплікація по імені — один Mac не повинен з'являтися двічі
                        let nameNorm = name.trimmingCharacters(in: .whitespaces).lowercased()
                        guard !seenNames.contains(nameNorm) else { continue }
                        seenNames.insert(nameNorm)
                        
                        let vol = (item["volume"] as? NSNumber)?.floatValue ?? 0.5
                        let isPlaying = (item["isPlaying"] as? Bool) ?? false
                        receivers.append(CastlieRemoteDevice(
                            id: id,
                            name: name,
                            volume: vol,
                            isPlaying: isPlaying,
                            connectedUser: item["connectedUser"] as? String,
                            isOnline: true
                        ))
                    }
                }
                self.availableReceivers = receivers
                
                // Якщо ми підключені до пристрою, синхронізуємо його поточні дані
                if let active = self.activeRemoteDevice {
                    if let updated = receivers.first(where: { $0.id == active.id }) {
                        self.activeRemoteDevice = updated
                    }
                }
            }
            
        case "device_joined":
            if let item = json["device"] as? [String: Any],
               let role = item["role"] as? String, role == "receiver",
               let id = item["deviceId"] as? String,
               let name = item["name"] as? String {
                let vol = (item["volume"] as? NSNumber)?.floatValue ?? 0.5
                let isPlaying = (item["isPlaying"] as? Bool) ?? false
                let newDev = CastlieRemoteDevice(
                    id: id,
                    name: name,
                    volume: vol,
                    isPlaying: isPlaying,
                    connectedUser: item["connectedUser"] as? String,
                    isOnline: true
                )
                // Дедуплікація: видаляємо старі записи з тим же id АБО тим же ім'ям
                let nameNorm = name.trimmingCharacters(in: .whitespaces).lowercased()
                availableReceivers.removeAll(where: {
                    $0.id == id || $0.name.trimmingCharacters(in: .whitespaces).lowercased() == nameNorm
                })
                availableReceivers.append(newDev)
            }
            
        case "device_left":
            if let id = json["deviceId"] as? String {
                availableReceivers.removeAll(where: { $0.id == id })
                if activeRemoteDevice?.id == id {
                    activeRemoteDevice = nil
                    AudioEngine.shared.handleRemoteDisconnected()
                }
            }
            
        case "volume_changed":
            if let id = json["deviceId"] as? String,
               let newVol = (json["volume"] as? NSNumber)?.floatValue {
                if let idx = availableReceivers.firstIndex(where: { $0.id == id }) {
                    availableReceivers[idx].volume = newVol
                }
                if activeRemoteDevice?.id == id {
                    activeRemoteDevice?.volume = newVol
                    AudioEngine.shared.updateVolumeFromRemote(newVol)
                }
            }
            
        case "playback_state_updated":
            if let id = json["deviceId"] as? String {
                if let idx = availableReceivers.firstIndex(where: { $0.id == id }) {
                    if let isPlay = json["isPlaying"] as? Bool {
                        availableReceivers[idx].isPlaying = isPlay
                    }
                    if let user = json["connectedUser"] as? String {
                        availableReceivers[idx].connectedUser = user
                    }
                }
                if activeRemoteDevice?.id == id {
                    if let isPlay = json["isPlaying"] as? Bool {
                        activeRemoteDevice?.isPlaying = isPlay
                        AudioEngine.shared.updatePlaybackState(isPlaying: isPlay)
                    }
                }
            }
            
        case "track_ended":
            if let id = json["deviceId"] as? String, activeRemoteDevice?.id == id {
                print("[CastlieConnect] ⏭️ Remote Mac track ended, advancing to next song")
                AudioEngine.shared.playNext(autoAdvance: true)
            }
            
        default:
            break
        }
    }
    
    private func handleConnectionFailure() {
        isConnected = false
        isConnecting = false
        
        reconnectTask?.cancel()
        reconnectTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            self.connect()
        }
    }
}
