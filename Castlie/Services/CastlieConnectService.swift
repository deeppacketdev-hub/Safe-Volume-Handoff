import Foundation
import Observation

struct CastlieRemoteDevice: Identifiable, Hashable {
    let id: String
    var name: String
    var volume: Float
    var isPlaying: Bool

    var audioDevice: AudioDevice {
        AudioDevice(id: id, name: name, type: .mac, connection: .castlieConnect)
    }
}

/// Зв'язок з Castlie на Mac через WebSocket-релей.
@Observable
@MainActor
final class CastlieConnectService {
    static let shared = CastlieConnectService()

    private(set) var serverDomain: String
    private(set) var isConnected = false
    private(set) var availableReceivers: [CastlieRemoteDevice] = []
    /// Mac, на який зараз іде звук.
    private(set) var activeRemoteDevice: CastlieRemoteDevice?

    private var webSocketTask: URLSessionWebSocketTask?
    private let session: URLSession
    private var pingTimer: Timer?
    private var reconnectTask: Task<Void, Never>?
    private var remoteGraceTask: Task<Void, Never>?
    private let senderId = "iphone_" + UUID().uuidString.prefix(6)

    // Гучність на Mac: не частіше ніж раз на 50 мс, плюс ігнор власного "ехо" від сервера.
    private var pendingVolume: (deviceId: String, volume: Float)?
    private var volumeFlushTask: Task<Void, Never>?
    private var lastVolumeSent = Date.distantPast

    private init() {
        serverDomain = UserDefaults.standard.string(forKey: "CastlieServerDomain") ?? "castlie.dron.lol"
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
        connect()
    }

    // MARK: - Connection

    func updateServerDomain(_ domain: String) {
        let clean = domain.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, clean != serverDomain else { return }
        serverDomain = clean
        UserDefaults.standard.set(clean, forKey: "CastlieServerDomain")
        connect()
    }

    func connect() {
        reconnectTask?.cancel()
        closeSocket()
        guard let url = URL(string: "wss://\(serverDomain)/ws?roomId=default") else { return }

        let task = session.webSocketTask(with: url)
        webSocketTask = task
        task.resume()
        send(["type": "register", "role": "sender", "deviceId": senderId, "name": "iPhone"])
        listen(on: task)

        pingTimer = Timer.scheduledTimer(withTimeInterval: 20, repeats: true) { _ in
            Task { @MainActor in CastlieConnectService.shared.sendPing() }
        }
    }

    private func closeSocket() {
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    private func sendPing() {
        guard let task = webSocketTask else { return }
        task.sendPing { error in
            guard error != nil else { return }
            Task { @MainActor in CastlieConnectService.shared.handleConnectionFailure(of: task) }
        }
    }

    /// Помилки від уже закритого сокета ігноруємо, щоб не рвати нове з'єднання.
    private func handleConnectionFailure(of task: URLSessionWebSocketTask) {
        guard webSocketTask === task else { return }
        closeSocket()
        reconnectTask?.cancel()
        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.connect()
        }
        // Якщо сервер не повернеться швидко, Mac уже не керується — закриваємо сесію безпечно.
        if activeRemoteDevice != nil, remoteGraceTask == nil {
            remoteGraceTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(10))
                guard !Task.isCancelled, let self else { return }
                self.remoteGraceTask = nil
                if !self.isConnected { self.remoteLost() }
            }
        }
    }

    // MARK: - Remote session

    func connectToRemote(_ device: CastlieRemoteDevice) {
        if let previous = activeRemoteDevice, previous.id != device.id {
            sendPlaybackCommand(deviceId: previous.id, action: "stop")
            clearActive(previous.id)
        }
        activeRemoteDevice = device
        AudioEngine.shared.didConnectRemote(device)
    }

    /// Користувач сам повертає звук з Mac на iPhone.
    func disconnectActiveRemote(continueLocally: Bool = true, volume: Float? = nil) {
        guard let active = activeRemoteDevice else { return }
        sendPlaybackCommand(deviceId: active.id, action: "stop")
        clearActive(active.id)
        AudioEngine.shared.didDisconnectRemote(continueLocally: continueLocally, volume: volume)
    }

    private func clearActive(_ id: String) {
        activeRemoteDevice = nil
        if let index = availableReceivers.firstIndex(where: { $0.id == id }) {
            availableReceivers[index].isPlaying = false
        }
    }

    private func remoteLost() {
        guard let active = activeRemoteDevice else { return }
        clearActive(active.id)
        AudioEngine.shared.didDisconnectRemote(continueLocally: false)
    }

    // MARK: - Commands

    func sendHandoff(
        to deviceId: String,
        track: Track,
        previewURL: URL,
        targetVolume: Float,
        fadeInDuration: Double,
        startTime: Double
    ) {
        send([
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
                "previewURL": previewURL.absoluteString,
                "startTime": startTime
            ]
        ])
    }

    func setRemoteVolume(deviceId: String, volume: Float) {
        let clamped = min(max(0, volume), 1)
        if let index = availableReceivers.firstIndex(where: { $0.id == deviceId }) {
            availableReceivers[index].volume = clamped
        }
        if activeRemoteDevice?.id == deviceId {
            activeRemoteDevice?.volume = clamped
        }

        pendingVolume = (deviceId, clamped)
        let elapsed = Date().timeIntervalSince(lastVolumeSent)
        if elapsed >= 0.05 {
            flushVolume()
        } else if volumeFlushTask == nil {
            volumeFlushTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(0.05 - elapsed))
                self?.volumeFlushTask = nil
                self?.flushVolume()
            }
        }
    }

    private func flushVolume() {
        guard let pending = pendingVolume else { return }
        pendingVolume = nil
        lastVolumeSent = Date()
        send(["type": "volume_update", "targetDeviceId": pending.deviceId, "volume": pending.volume])
    }

    func sendPlaybackCommand(deviceId: String, action: String, value: Double? = nil) {
        var payload: [String: Any] = ["type": "playback_command", "targetDeviceId": deviceId, "action": action]
        if let value { payload["value"] = value }
        send(payload)
    }

    private func send(_ json: [String: Any]) {
        guard let task = webSocketTask,
              let data = try? JSONSerialization.data(withJSONObject: json),
              let text = String(data: data, encoding: .utf8) else { return }
        task.send(.string(text)) { error in
            guard error != nil else { return }
            Task { @MainActor in CastlieConnectService.shared.handleConnectionFailure(of: task) }
        }
    }

    // MARK: - Incoming

    private func listen(on task: URLSessionWebSocketTask) {
        task.receive { result in
            Task { @MainActor in
                let service = CastlieConnectService.shared
                guard service.webSocketTask === task else { return }
                switch result {
                case .success(let message):
                    service.isConnected = true
                    service.remoteGraceTask?.cancel()
                    service.remoteGraceTask = nil
                    switch message {
                    case .string(let text): service.handle(text)
                    case .data(let data): service.handle(String(decoding: data, as: UTF8.self))
                    @unknown default: break
                    }
                    service.listen(on: task)
                case .failure:
                    service.handleConnectionFailure(of: task)
                }
            }
        }
    }

    private func handle(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }

        switch type {
        case "registered":
            isConnected = true

        case "devices_list":
            // Після перезапуску Mac на сервері може ще висіти старий запис з тією ж назвою — лишаємо новіший.
            var receivers: [CastlieRemoteDevice] = []
            for item in json["devices"] as? [[String: Any]] ?? [] {
                guard let device = Self.receiver(from: item) else { continue }
                receivers.removeAll { $0.id == device.id || $0.audioDevice.matchKey == device.audioDevice.matchKey }
                receivers.append(device)
            }
            availableReceivers = receivers
            if let active = activeRemoteDevice {
                if let updated = receivers.first(where: { $0.id == active.id }) {
                    activeRemoteDevice?.isPlaying = updated.isPlaying
                } else {
                    remoteLost()
                }
            }

        case "device_joined":
            guard let item = json["device"] as? [String: Any], let device = Self.receiver(from: item) else { return }
            availableReceivers.removeAll { $0.id == device.id || $0.audioDevice.matchKey == device.audioDevice.matchKey }
            availableReceivers.append(device)

        case "device_left":
            guard let id = json["deviceId"] as? String else { return }
            availableReceivers.removeAll { $0.id == id }
            if activeRemoteDevice?.id == id { remoteLost() }

        case "volume_changed":
            guard let id = json["deviceId"] as? String,
                  let volume = (json["volume"] as? NSNumber)?.floatValue else { return }
            // Сервер повертає і наші власні зміни — поки користувач крутить гучність, ігноруємо їх.
            guard Date().timeIntervalSince(lastVolumeSent) > 0.8, pendingVolume == nil else { return }
            if let index = availableReceivers.firstIndex(where: { $0.id == id }) {
                availableReceivers[index].volume = volume
            }
            if activeRemoteDevice?.id == id, abs((activeRemoteDevice?.volume ?? 0) - volume) > 0.005 {
                activeRemoteDevice?.volume = volume
                AudioEngine.shared.didReceiveRemoteVolume(volume)
            }

        case "playback_state_updated":
            guard let id = json["deviceId"] as? String, let playing = json["isPlaying"] as? Bool else { return }
            if let index = availableReceivers.firstIndex(where: { $0.id == id }) {
                availableReceivers[index].isPlaying = playing
            }
            if activeRemoteDevice?.id == id {
                activeRemoteDevice?.isPlaying = playing
                AudioEngine.shared.handleRemotePlaybackState(isPlaying: playing)
            }

        case "track_ended":
            if let id = json["deviceId"] as? String, activeRemoteDevice?.id == id {
                AudioEngine.shared.handleRemoteTrackEnded()
            }

        default:
            break
        }
    }

    private static func receiver(from item: [String: Any]) -> CastlieRemoteDevice? {
        guard (item["role"] as? String) == "receiver",
              let id = item["deviceId"] as? String,
              let name = item["name"] as? String else { return nil }
        return CastlieRemoteDevice(
            id: id,
            name: name,
            volume: (item["volume"] as? NSNumber)?.floatValue ?? 0.5,
            isPlaying: item["isPlaying"] as? Bool ?? false
        )
    }
}
