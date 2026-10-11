import Foundation
import AVFoundation
import Observation

@Observable
@MainActor
class DeviceManagerViewModel {
    let discovery = DeviceDiscoveryService.shared
    let safeVolume = SafeVolumeManager.shared
    let fadeIn = FadeInEngine.shared
    let audioEngine = AudioEngine.shared
    let connectService = CastlieConnectService.shared
    
    var selectedDevice: AudioDevice?
    var selectedRemoteDevice: CastlieRemoteDevice?
    var showHandoffConfirm = false
    var adjustedVolume: Float = 0.3
    
    /// Почати налаштування гучності для звичайного аудіопристрою
    func initiateHandoff(to device: AudioDevice) {
        selectedDevice = device
        selectedRemoteDevice = nil
        adjustedVolume = safeVolume.recommendedVolume(for: device)
        if safeVolume.config.requireConfirmation {
            showHandoffConfirm = true
        } else {
            confirmHandoff()
        }
    }
    
    /// Почати Handoff для пристрою Castlie Connect (Mac)
    func initiateRemoteHandoff(to remote: CastlieRemoteDevice) {
        selectedRemoteDevice = remote
        selectedDevice = AudioDevice(
            id: remote.id,
            name: remote.name,
            type: .mac,
            connectionType: .airplay,
            roomName: "Castlie Connect",
            lastKnownVolume: remote.volume,
            isConnected: remote.isPlaying
        )
        adjustedVolume = remote.volume
        if safeVolume.config.requireConfirmation {
            showHandoffConfirm = true
        } else {
            confirmHandoff()
        }
    }
    
    /// Обробка зміни повзунка в HandoffConfirmSheet у реальному часі
    func handleAdjustedVolumeChange(_ newVol: Float) {
        let clamped = max(0, min(1, newVol))
        adjustedVolume = clamped
        
        // Для пристроїв Castlie Connect (Mac) одразу передаємо команду в реальному часі
        // Це змінює СИСТЕМНУ гучність на Mac ще ДО підтвердження підключення
        if let remote = selectedRemoteDevice {
            connectService.setRemoteVolume(deviceId: remote.id, volume: clamped)
        }
    }
    
    /// Підтвердити гучність та підключитись
    func confirmHandoff() {
        let targetVol = max(0, min(1, adjustedVolume))
        
        // 1. Якщо це Castlie Connect пристрій (Mac)
        if let remote = selectedRemoteDevice {
            // Зберігаємо поточний локальний пристрій перед перемиканням на Mac
            if let cur = discovery.currentDevice {
                safeVolume.updateDeviceVolume(
                    deviceId: cur.id,
                    deviceName: cur.name,
                    volume: audioEngine.volume
                )
                if cur.connectionType == .bluetooth {
                    discovery.preserveBluetoothDevice(cur)
                }
            }
            
            safeVolume.recordConnection(
                deviceId: remote.id,
                deviceName: remote.name,
                volume: targetVol
            )
            
            // Встановлюємо стійке з'єднання із Mac
            var updatedRemote = remote
            updatedRemote.volume = targetVol
            connectService.connectToRemote(device: updatedRemote)
            
            // Фіксуємо гучність у реальному часі
            connectService.setRemoteVolume(deviceId: remote.id, volume: targetVol)
            
            // Якщо на телефоні є трек — запускаємо на Mac
            let trackToPlay = audioEngine.currentTrack ?? audioEngine.queue.first
            if let track = trackToPlay {
                audioEngine.play(track: track)
            }
            
            HapticFeedbackService.success()
            showHandoffConfirm = false
            selectedDevice = nil
            selectedRemoteDevice = nil
            return
        }
        
        // 2. Якщо це звичайний локальний / Bluetooth пристрій
        guard let device = selectedDevice else { return }
        
        // Якщо ми були підключені до Mac — відключаємо його
        if connectService.activeRemoteDevice != nil {
            connectService.disconnectActiveRemote()
        }
        
        let currentNameNorm = discovery.currentDevice?.name.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        let devNameNorm = device.name.trimmingCharacters(in: .whitespaces).lowercased()
        let isCurrent = (device.id == discovery.currentDevice?.id) || (!devNameNorm.isEmpty && devNameNorm == currentNameNorm)
        
        if device.type == .iPhone || device.id == "builtin-speaker" || devNameNorm == "iphone" || devNameNorm == "цей iphone" {
            // Перемикання на динамік iPhone із вказаною цільовою гучністю
            discovery.switchToBuiltInSpeaker(targetVolume: targetVol)
        } else if isCurrent {
            // Пристрій вже активний — просто оновлюємо гучність
            audioEngine.setVolume(targetVol)
            safeVolume.updateDeviceVolume(deviceId: device.id, deviceName: device.name, volume: targetVol)
        } else {
            // Перемикаємо на Bluetooth пристрій із вказаною цільовою гучністю
            discovery.switchToBluetoothDevice(device, targetVolume: targetVol)
        }
        
        // Якщо відтворення не активне або ми перемкнулись з Mac, відновлюємо локальне відтворення
        if !audioEngine.isPlaying, let track = audioEngine.currentTrack ?? audioEngine.queue.first {
            audioEngine.play(track: track)
        }
        
        HapticFeedbackService.success()
        showHandoffConfirm = false
        selectedDevice = nil
        selectedRemoteDevice = nil
    }
    
    /// Скасувати
    func cancelHandoff() {
        showHandoffConfirm = false
        selectedDevice = nil
        selectedRemoteDevice = nil
    }
    
    /// Відключитись від активного Mac і повернути звук на iPhone
    func disconnectActiveRemote() {
        connectService.disconnectActiveRemote()
        HapticFeedbackService.light()
    }
    
    /// Перемкнути аудіо-вихід на вбудований динамік iPhone (з Bluetooth колонки/навушників)
    func switchToBuiltInSpeaker() {
        // 1. Відключити Castlie Remote (Mac) якщо активний
        if connectService.activeRemoteDevice != nil {
            connectService.disconnectActiveRemote()
        }
        
        // 2. Перемкнути системний аудіо-маршрут на вбудований динамік з відновленням його гучності
        discovery.switchToBuiltInSpeaker()
        
        HapticFeedbackService.success()
    }
}
