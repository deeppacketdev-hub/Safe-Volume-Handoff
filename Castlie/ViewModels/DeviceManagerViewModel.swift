import Foundation
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
    
    /// Почати налаштування безпечної гучності для звичайного аудіопристрою
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
    
    /// Почати Safe Handoff для пристрою Castlie Connect (Mac)
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
        // Рекомендована безпечна гучність з урахуванням Night Mode та порогу
        adjustedVolume = min(remote.volume, safeVolume.config.effectiveMaxVolume)
        if safeVolume.config.requireConfirmation {
            showHandoffConfirm = true
        } else {
            confirmHandoff()
        }
    }
    
    /// Підтвердити безпечну гучність
    func confirmHandoff() {
        let targetVol = max(0, min(1, adjustedVolume))
        
        // 1. Якщо це Castlie Connect пристрій (Mac)
        if let remote = selectedRemoteDevice {
            safeVolume.recordConnection(
                deviceId: remote.id,
                deviceName: remote.name,
                volume: targetVol
            )
            
            // Якщо на телефоні грає трек — передаємо його на Mac з Safe Fade-in
            if let currentTrack = audioEngine.currentTrack {
                connectService.sendHandoff(
                    to: remote.id,
                    track: currentTrack,
                    targetVolume: targetVol,
                    fadeInDuration: safeVolume.config.fadeInDuration
                )
                // Ставимо телефон на паузу, бо грає Mac
                if audioEngine.isPlaying {
                    audioEngine.togglePlayPause()
                }
            } else {
                // Якщо трек не грає, просто встановлюємо безпечну гучність на Mac
                connectService.setRemoteVolume(deviceId: remote.id, volume: targetVol)
            }
            
            HapticFeedbackService.success()
            showHandoffConfirm = false
            selectedDevice = nil
            selectedRemoteDevice = nil
            return
        }
        
        // 2. Якщо це звичайний локальний / Bluetooth пристрій
        guard let device = selectedDevice else { return }
        
        safeVolume.recordConnection(
            deviceId: device.id,
            deviceName: device.name,
            volume: targetVol
        )
        
        let currentNameNorm = discovery.currentDevice?.name.trimmingCharacters(in: .whitespaces).lowercased() ?? ""
        let devNameNorm = device.name.trimmingCharacters(in: .whitespaces).lowercased()
        let isCurrent = (device.id == discovery.currentDevice?.id) || (!devNameNorm.isEmpty && devNameNorm == currentNameNorm)
        
        if isCurrent {
            if safeVolume.config.isFadeInEnabled {
                fadeIn.startFadeIn(
                    targetVolume: targetVol,
                    duration: safeVolume.config.fadeInDuration,
                    audioEngine: audioEngine
                )
            } else {
                audioEngine.setVolume(targetVol)
            }
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
}
