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
    
    /// Почати налаштування безпечної гучності для пристрою
    func initiateHandoff(to device: AudioDevice) {
        selectedDevice = device
        adjustedVolume = safeVolume.recommendedVolume(for: device)
        if safeVolume.config.requireConfirmation {
            showHandoffConfirm = true
        } else {
            confirmHandoff()
        }
    }
    
    /// Підтвердити безпечну гучність
    func confirmHandoff() {
        guard let device = selectedDevice else { return }
        
        // Обмежити гучність безпечним порогом
        let safeVol = safeVolume.clampVolume(adjustedVolume)
        
        // Записати в історію пристрою
        safeVolume.recordConnection(
            deviceId: device.id,
            deviceName: device.name,
            volume: safeVol
        )
        
        // Якщо це поточний активний пристрій, застосовуємо гучність
        if device.id == discovery.currentDevice?.id {
            if safeVolume.config.isFadeInEnabled {
                fadeIn.startFadeIn(
                    targetVolume: safeVol,
                    duration: safeVolume.config.fadeInDuration,
                    audioEngine: audioEngine
                )
            } else {
                audioEngine.setVolume(safeVol)
            }
        }
        
        HapticFeedbackService.success()
        showHandoffConfirm = false
        selectedDevice = nil
    }
    
    /// Скасувати
    func cancelHandoff() {
        showHandoffConfirm = false
        selectedDevice = nil
    }
}
