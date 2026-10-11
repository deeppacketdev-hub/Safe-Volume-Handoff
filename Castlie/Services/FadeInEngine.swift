import Foundation

@Observable
@MainActor
class FadeInEngine {
    static let shared = FadeInEngine()
    
    private(set) var isFadingIn = false
    private(set) var fadeProgress: Float = 0  // 0.0 - 1.0
    private var fadeTask: Task<Void, Never>?
    
    private init() {}
    
    /// Запустити плавний програмний fade-in (software gain AVPlayer 0.0 -> 1.0) під капотом.
    /// Повзунок користувача та системна апаратна гучність залишаються стабільними!
    /// - Parameters:
    ///   - duration: Тривалість fade-in у секундах
    ///   - audioEngine: Посилання на аудіо-движок
    func startFadeIn(duration: Double, audioEngine: AudioEngine) {
        cancelFadeIn()
        
        guard duration > 0.05 else {
            audioEngine.setSoftwareGain(1.0)
            return
        }
        
        isFadingIn = true
        fadeProgress = 0
        audioEngine.setSoftwareGain(0.0)
        
        let steps = max(10, Int(duration * 30))  // 30 кроків на секунду — бездоганна плавність
        let intervalNanoseconds = UInt64(duration / Double(steps) * 1_000_000_000)
        
        fadeTask = Task { @MainActor in
            for step in 1...steps {
                guard !Task.isCancelled else { break }
                
                let progress = Float(step) / Float(steps)
                audioEngine.setSoftwareGain(progress)
                fadeProgress = progress
                
                try? await Task.sleep(nanoseconds: intervalNanoseconds)
            }
            
            // Гарантуємо повний програмний рівень по завершенню
            audioEngine.setSoftwareGain(1.0)
            fadeProgress = 1.0
            isFadingIn = false
        }
    }
    
    /// Скасувати fade-in та миттєво повернути повне програмне підсилення 1.0
    func cancelFadeIn() {
        fadeTask?.cancel()
        fadeTask = nil
        isFadingIn = false
        fadeProgress = 0
        AudioEngine.shared.setSoftwareGain(1.0)
    }
}
