import AVFoundation
import MediaPlayer
import SwiftUI
import UIKit

@MainActor
final class SystemVolumeController: NSObject {
    static let shared = SystemVolumeController()
    
    private var volumeSlider: UISlider?
    private var volumeView: MPVolumeView?
    private var volumeObservation: NSKeyValueObservation?
    
    private override init() {
        super.init()
        setupVolumeObserver()
    }
    
    /// Підключення MPVolumeView, що змонтований у живій ієрархії SwiftUI
    func attach(volumeView: MPVolumeView) {
        self.volumeView = volumeView
        findSlider()
    }
    
    /// Рекурсивний пошук UISlider усередині MPVolumeView
    private func findSlider() {
        guard let volumeView else { return }
        self.volumeSlider = findSliderRecursively(in: volumeView)
    }
    
    private func findSliderRecursively(in view: UIView) -> UISlider? {
        if let slider = view as? UISlider {
            return slider
        }
        for subview in view.subviews {
            if let slider = findSliderRecursively(in: subview) {
                return slider
            }
        }
        return nil
    }
    
    private func getSlider() -> UISlider? {
        if let volumeSlider {
            return volumeSlider
        }
        findSlider()
        return volumeSlider
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
    
    /// Встановити системну гучність для підключеного пристрою (Mac, AirPlay, Bluetooth колонка)
    func setSystemVolume(_ volume: Float) {
        let clamped = max(0, min(1, volume))
        
        if let slider = getSlider() {
            DispatchQueue.main.async {
                slider.setValue(clamped, animated: false)
                slider.sendActions(for: .valueChanged)
            }
        } else {
            // Спробувати знайти слайдер знову через невелику затримку, якщо в'юшка щойно змонтувалась
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                if let slider = self?.getSlider() {
                    slider.setValue(clamped, animated: false)
                    slider.sendActions(for: .valueChanged)
                }
            }
        }
    }
    
    /// Поточна апаратна системна гучність активного пристрою
    var currentVolume: Float {
        AVAudioSession.sharedInstance().outputVolume
    }
}

/// Невидимий міст MPVolumeView для вбудовування в живий інтерфейс SwiftUI
struct SystemVolumeBridge: UIViewRepresentable {
    func makeUIView(context: Context) -> MPVolumeView {
        let volumeView = MPVolumeView(frame: CGRect(x: -100, y: -100, width: 1, height: 1))
        volumeView.alpha = 0.0001
        volumeView.clipsToBounds = true
        volumeView.isUserInteractionEnabled = false
        SystemVolumeController.shared.attach(volumeView: volumeView)
        return volumeView
    }
    
    func updateUIView(_ uiView: MPVolumeView, context: Context) {
        SystemVolumeController.shared.attach(volumeView: uiView)
    }
}
