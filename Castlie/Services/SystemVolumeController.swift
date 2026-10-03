import AVFoundation
import MediaPlayer
import SwiftUI
import UIKit

@MainActor
final class SystemVolumeController: NSObject {
    static let shared = SystemVolumeController()
    
    private var volumeObservation: NSKeyValueObservation?
    
    private override init() {
        super.init()
        setupVolumeObserver()
    }
    
    private func setupVolumeObserver() {
        let session = AVAudioSession.sharedInstance()
        
        // 1. Офіційний надійний KVO моніторинг апаратної гучності (реагує на фізичні кнопки iPhone, регулювання на Mac через AirPlay, кнопки Bluetooth колонок/навушників)
        volumeObservation = session.observe(\.outputVolume, options: [.new, .initial]) { _, _ in
            let vol = AVAudioSession.sharedInstance().outputVolume
            Task { @MainActor in
                AudioEngine.shared.syncSystemVolume(vol)
            }
        }
        
        // 2. Додатковий слухач системного сповіщення
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("AVSystemController_SystemVolumeDidChangeNotification"),
            object: nil,
            queue: .main
        ) { notification in
            if let volume = notification.userInfo?["AVSystemController_AudioVolumeNotificationParameter"] as? Float {
                Task { @MainActor in
                    AudioEngine.shared.syncSystemVolume(volume)
                }
            }
        }
    }
    
    /// Встановлення системної гучності
    func setSystemVolume(_ volume: Float) {
        // Системний HUD залишається активним та видимим для користувача
    }
    
    /// Поточна апаратна системна гучність активного пристрою
    var currentVolume: Float {
        AVAudioSession.sharedInstance().outputVolume
    }
}
