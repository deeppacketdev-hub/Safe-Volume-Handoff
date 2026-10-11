import AVFoundation
import MediaPlayer
import SwiftUI
import UIKit

@MainActor
final class SystemVolumeController: NSObject {
    static let shared = SystemVolumeController()
    
    private var volumeObservation: NSKeyValueObservation?
    private var volumeView: MPVolumeView?
    private var volumeSlider: UISlider?
    private var deactivateTask: Task<Void, Never>?
    
    private override init() {
        super.init()
        setupVolumeObserver()
    }
    
    // MARK: - On-Demand Activation
    // MPVolumeView приєднується ДО ВІКНА ТІЛЬКИ коли користувач рухає повзунок у додатку.
    // Коли користувач закінчує взаємодію, MPVolumeView видаляється з вікна.
    // Завдяки цьому при натисканні фізичних кнопок на iPhone З'ЯВЛЯЄТЬСЯ РІДНА СИСТЕМНА ПЛАШКА ГУЧНОСТІ iOS!
    
    /// Початок взаємодії з повзунком у додатку
    func beginVolumeInteraction() {
        deactivateTask?.cancel()
        activateVolumeView()
    }
    
    /// Завершення взаємодії з повзунком
    func endVolumeInteraction() {
        scheduleDeactivation(after: 0.35)
    }
    
    private func activateVolumeView() {
        if volumeView == nil {
            let mp = MPVolumeView(frame: CGRect(x: -200, y: -200, width: 1, height: 1))
            mp.alpha = 0.0001
            mp.clipsToBounds = true
            mp.isUserInteractionEnabled = false
            self.volumeView = mp
        }
        
        guard let volumeView else { return }
        
        if volumeView.superview == nil {
            if let window = getActiveWindow() {
                window.addSubview(volumeView)
                findSlider()
            }
        }
    }
    
    private func scheduleDeactivation(after delay: TimeInterval = 0.5) {
        deactivateTask?.cancel()
        deactivateTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            deactivateVolumeView()
        }
    }
    
    private func deactivateVolumeView() {
        volumeView?.removeFromSuperview()
        volumeSlider = nil
    }
    
    private func getActiveWindow() -> UIWindow? {
        for scene in UIApplication.shared.connectedScenes {
            if let windowScene = scene as? UIWindowScene,
               windowScene.activationState == .foregroundActive || windowScene.activationState == .foregroundInactive {
                for window in windowScene.windows where window.isKeyWindow {
                    return window
                }
                if let first = windowScene.windows.first {
                    return first
                }
            }
        }
        return nil
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
        
        // Офіційний KVO моніторинг апаратної гучності (натискання фізичних кнопок на iPhone або Bluetooth колонках)
        volumeObservation = session.observe(\.outputVolume, options: [.new]) { _, _ in
            let vol = AVAudioSession.sharedInstance().outputVolume
            Task { @MainActor in
                AudioEngine.shared.syncSystemVolume(vol)
            }
        }
        
        // Додатковий слухач системного сповіщення
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
    
    @discardableResult
    private func applyToSlider(volume: Float) -> Bool {
        if let slider = getSlider() {
            slider.setValue(volume, animated: false)
            slider.sendActions(for: .valueChanged)
            return true
        }
        return false
    }

    /// Встановлення РЕАЛЬНОЇ системної гучності iOS (динамік iPhone, AirPods, Bluetooth-колонки, AirPlay)
    func setSystemVolume(_ volume: Float) {
        let clamped = max(0, min(1, volume))
        
        // Тимчасово приєднуємо MPVolumeView щоб передати зміну системі
        activateVolumeView()
        
        if !applyToSlider(volume: clamped) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.04) { [weak self] in
                guard let self else { return }
                if !self.applyToSlider(volume: clamped) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) { [weak self] in
                        self?.applyToSlider(volume: clamped)
                    }
                }
            }
        }
        
        // Автоматично прибираємо MPVolumeView після завершення зміни,
        // щоб системна плашка гучності завжди показувалася при натисканні кнопок
        scheduleDeactivation(after: 0.6)
    }
    
    /// Поточна апаратна системна гучність активного пристрою
    var currentVolume: Float {
        AVAudioSession.sharedInstance().outputVolume
    }
}
