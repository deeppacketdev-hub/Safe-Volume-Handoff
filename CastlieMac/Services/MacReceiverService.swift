import AppKit
import Foundation
import Observation

struct RemoteTrackInfo: Codable, Identifiable {
    var id: String
    var name: String
    var artistName: String
    var albumName: String?
    var albumArtURL: String?
    var previewURL: String?
}

@Observable
@MainActor
final class MacReceiverService: NSObject {
    static let shared = MacReceiverService()
    
    // Status & Connected Client
    private(set) var isConnectedToServer: Bool = false
    private(set) var serverDomain: String = "castlie.dron.lol"
    private(set) var deviceName: String = Host.current().localizedName ?? "MacBook Pro"
    private(set) var deviceId: String = "mac_" + UUID().uuidString.prefix(6)
    private(set) var connectedUser: String? = nil
    
    // Now playing
    private(set) var currentTrack: RemoteTrackInfo? = nil
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var session: URLSession?
    private var pingTimer: Timer?
    private var isReconnecting = false
    
    let audioPlayer = MacAudioPlayer.shared
    
    var isPlaying: Bool {
        audioPlayer.isPlaying
    }
    
    var volume: Float {
        audioPlayer.volume
    }
    
    private override init() {
        super.init()
        setupSession()
        connect()
    }
    
    private func setupSession() {
        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        session = URLSession(configuration: config)
    }
    
    func connect() {
        disconnect()
        
        let urlString = "wss://\(serverDomain)/ws?roomId=default"
        guard let url = URL(string: urlString) else { return }
        
        webSocketTask = session?.webSocketTask(with: url)
        webSocketTask?.resume()
        
        isConnectedToServer = true
        sendRegistration()
        listenForMessages()
        startPingTimer()
    }
    
    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        isConnectedToServer = false
    }
    
    private func startPingTimer() {
        pingTimer?.invalidate()
        pingTimer = Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sendPing()
            }
        }
    }
    
    private func sendPing() {
        webSocketTask?.sendPing { [weak self] error in
            if let error {
                print("[MacReceiver] Ping error: \(error.localizedDescription)")
                Task { @MainActor in
                    self?.handleDisconnect()
                }
            }
        }
    }
    
    // MARK: - Outgoing Messages
    
    private func sendRegistration() {
        let payload: [String: Any] = [
            "type": "register",
            "role": "receiver",
            "deviceId": deviceId,
            "name": deviceName,
            "volume": audioPlayer.volume,
            "isPlaying": audioPlayer.isPlaying,
            "currentTrack": currentTrack.flatMap { try? JSONEncoder().encode($0) }.flatMap { String(data: $0, encoding: .utf8) } as Any
        ]
        send(json: payload)
    }
    
    func updateVolume(_ newVol: Float) {
        audioPlayer.setVolume(newVol)
        send(json: [
            "type": "volume_update",
            "deviceId": deviceId,
            "volume": newVol
        ])
    }
    
    private func send(json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let string = String(data: data, encoding: .utf8) else { return }
        
        webSocketTask?.send(.string(string)) { [weak self] error in
            if let error {
                print("[MacReceiver] WS Send error: \(error.localizedDescription)")
                Task { @MainActor in
                    self?.handleDisconnect()
                }
            }
        }
    }
    
    // MARK: - Incoming Messages
    
    private func listenForMessages() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let message):
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
                    self.listenForMessages()
                    
                case .failure(let error):
                    print("[MacReceiver] WS Receive error: \(error.localizedDescription)")
                    self.handleDisconnect()
                }
            }
        }
    }
    
    private func handleIncomingText(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String else { return }
        
        switch type {
        case "perform_handoff":
            guard let trackData = json["track"] as? [String: Any] else { return }
            
            let trackId = trackData["id"] as? String ?? UUID().uuidString
            let trackName = trackData["name"] as? String ?? "Track"
            let artistName = trackData["artistName"] as? String ?? "Artist"
            let albumName = trackData["albumName"] as? String
            let albumArtURL = trackData["albumArtURL"] as? String
            let previewURLString = trackData["previewURL"] as? String
            
            let targetVol = (json["targetVolume"] as? NSNumber)?.floatValue ?? 0.35
            let fadeIn = (json["fadeInDuration"] as? NSNumber)?.doubleValue ?? 2.0
            let sender = json["senderName"] as? String ?? "iPhone"
            
            let track = RemoteTrackInfo(
                id: trackId,
                name: trackName,
                artistName: artistName,
                albumName: albumName,
                albumArtURL: albumArtURL,
                previewURL: previewURLString
            )
            
            self.currentTrack = track
            self.connectedUser = sender
            
            print("[MacReceiver] 🎵 Handoff received from \(sender): \"\(trackName)\" by \(artistName)")
            
            Task { @MainActor in
                var finalURL: URL? = nil
                if let previewURLString, let url = URL(string: previewURLString) {
                    finalURL = url
                } else {
                    finalURL = await self.resolveAudioFallback(artist: artistName, track: trackName)
                }
                
                guard let finalURL else {
                    print("[MacReceiver] ❌ Could not find audio stream URL for \(trackName)")
                    return
                }
                
                print("[MacReceiver] ▶️ Playing \(trackName) with volume \(Int(targetVol * 100))% (fade-in: \(fadeIn)s)")
                self.audioPlayer.play(url: finalURL, targetVolume: targetVol, fadeInDuration: fadeIn)
                
                // Broadcast updated playback state
                self.send(json: [
                    "type": "playback_state",
                    "deviceId": self.deviceId,
                    "isPlaying": true,
                    "currentTrack": [
                        "id": track.id,
                        "name": track.name,
                        "artistName": track.artistName,
                        "albumArtURL": track.albumArtURL as Any
                    ],
                    "connectedUser": sender
                ])
            }
            
        case "volume_changed":
            if let devId = json["deviceId"] as? String, devId == deviceId,
               let newVol = (json["volume"] as? NSNumber)?.floatValue {
                audioPlayer.setVolume(newVol)
            }
            
        case "remote_playback_command":
            if let action = json["action"] as? String {
                switch action {
                case "toggle": 
                    audioPlayer.togglePlayPause()
                case "pause": 
                    audioPlayer.pause()
                case "play": 
                    audioPlayer.resume()
                case "stop", "disconnect": 
                    audioPlayer.stop()
                    self.currentTrack = nil
                    self.connectedUser = nil
                    self.send(json: [
                        "type": "playback_state",
                        "deviceId": self.deviceId,
                        "isPlaying": false,
                        "currentTrack": NSNull(),
                        "connectedUser": NSNull()
                    ])
                case "seek":
                    if let sec = (json["value"] as? NSNumber)?.doubleValue {
                        audioPlayer.seek(to: sec)
                    }
                default: 
                    break
                }
            }
            
        default:
            break
        }
    }
    
    /// Сповіщення сервера про закінчення пісні на Mac для автоперемикання
    func notifyTrackEnded() {
        print("[MacReceiver] ⏹️ Track ended on Mac, notifying room")
        send(json: [
            "type": "track_ended",
            "deviceId": deviceId
        ])
        send(json: [
            "type": "playback_state",
            "deviceId": deviceId,
            "isPlaying": false,
            "connectedUser": connectedUser as Any
        ])
    }
    
    private func handleDisconnect() {
        isConnectedToServer = false
        guard !isReconnecting else { return }
        isReconnecting = true
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            self.isReconnecting = false
            self.connect()
        }
    }
    
    /// Автономний fallback пошук прев'ю на Mac через Apple iTunes Search API
    private func resolveAudioFallback(artist: String, track: String) async -> URL? {
        let query = "\(artist) \(track)"
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=song&limit=1") else {
            return nil
        }
        
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 4
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                struct ITunesResult: Codable {
                    let previewUrl: String?
                }
                struct ITunesResponse: Codable {
                    let results: [ITunesResult]
                }
                let res = try JSONDecoder().decode(ITunesResponse.self, from: data)
                if let first = res.results.first?.previewUrl, let u = URL(string: first) {
                    return u
                }
            }
        } catch {
            print("[MacReceiver] Fallback error: \(error.localizedDescription)")
        }
        return nil
    }
}
