import AVFoundation
import MediaPlayer
import UIKit

/// Читає та змінює апаратну гучність iOS.
///
/// Публічного API для встановлення гучності немає, тому використовується прихований `MPVolumeView`.
/// Він додається у вікно лише на час зміни — інакше iOS перестає показувати власну плашку гучності.
@MainActor
final class SystemVolumeController {
    static let shared = SystemVolumeController()

    private var observation: NSKeyValueObservation?
    private var volumeView: MPVolumeView?
    private var detachTask: Task<Void, Never>?
    private var isInteracting = false

    // Обмеження частоти: не частіше ніж раз на 1/30 с, останнє значення не губиться.
    private var lastApplied = Date.distantPast
    private var pendingVolume: Float?
    private var flushTask: Task<Void, Never>?

    // Нещодавні програмні значення — щоб відрізнити "ехо" KVO від натискання кнопок.
    private var recentProgrammatic: [(volume: Float, date: Date)] = []

    private init() {
        observation = AVAudioSession.sharedInstance().observe(\.outputVolume, options: [.new]) { _, change in
            guard let volume = change.newValue else { return }
            Task { @MainActor in
                SystemVolumeController.shared.handleObservedVolume(volume)
            }
        }
    }

    var currentVolume: Float { AVAudioSession.sharedInstance().outputVolume }

    /// Тримати `MPVolumeView` у вікні, поки користувач тягне повзунок.
    func beginInteraction() {
        isInteracting = true
        detachTask?.cancel()
        attachVolumeView()
    }

    func endInteraction() {
        isInteracting = false
        scheduleDetach()
    }

    func setVolume(_ volume: Float) {
        let clamped = min(max(0, volume), 1)
        pendingVolume = clamped
        let elapsed = Date().timeIntervalSince(lastApplied)
        if elapsed >= 1.0 / 30 {
            flush()
        } else if flushTask == nil {
            flushTask = Task { [weak self] in
                try? await Task.sleep(for: .seconds(1.0 / 30 - elapsed))
                self?.flushTask = nil
                self?.flush()
            }
        }
    }

    private func flush() {
        guard let volume = pendingVolume else { return }
        pendingVolume = nil
        lastApplied = Date()
        recentProgrammatic.removeAll { Date().timeIntervalSince($0.date) > 1.2 }
        recentProgrammatic.append((volume, Date()))
        attachVolumeView()
        apply(volume, attempt: 0)
        scheduleDetach()
    }

    /// Слайдер всередині `MPVolumeView` з'являється не одразу після додавання у вікно.
    private func apply(_ volume: Float, attempt: Int) {
        if let slider = volumeView.flatMap(findSlider) {
            slider.setValue(volume, animated: false)
            slider.sendActions(for: .valueChanged)
        } else if attempt < 3 {
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(50 * (attempt + 1)))
                self?.apply(volume, attempt: attempt + 1)
            }
        }
    }

    private func handleObservedVolume(_ volume: Float) {
        // Поки палець на повзунку, усі зміни — наші; інакше шукаємо збіг із нещодавніми записами
        // (під час швидкого жесту iOS може повідомити одне з попередніх значень).
        let isEcho = isInteracting || recentProgrammatic.contains {
            Date().timeIntervalSince($0.date) < 1.2 && abs($0.volume - volume) < 0.02
        }
        AudioEngine.shared.handleHardwareVolumeChange(volume, isEcho: isEcho)
    }

    private func attachVolumeView() {
        if volumeView == nil {
            let view = MPVolumeView(frame: CGRect(x: -100, y: -100, width: 1, height: 1))
            view.alpha = 0.0001
            view.isUserInteractionEnabled = false
            volumeView = view
        }
        guard let volumeView, volumeView.superview == nil, let window = activeWindow() else { return }
        window.addSubview(volumeView)
    }

    private func scheduleDetach() {
        detachTask?.cancel()
        detachTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard let self, !Task.isCancelled, !self.isInteracting else { return }
            self.volumeView?.removeFromSuperview()
        }
    }

    private func activeWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let preferred = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        return preferred?.windows.first { $0.isKeyWindow } ?? preferred?.windows.first
    }

    private func findSlider(in view: UIView) -> UISlider? {
        if let slider = view as? UISlider { return slider }
        for subview in view.subviews {
            if let slider = findSlider(in: subview) { return slider }
        }
        return nil
    }
}
