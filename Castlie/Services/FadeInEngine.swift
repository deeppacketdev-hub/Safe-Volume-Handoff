import Foundation

@Observable
@MainActor
class FadeInEngine {
    static let shared = FadeInEngine()
    
    private(set) var isFadingIn = false
    private(set) var fadeProgress: Float = 0  // 0.0 - 1.0
    private var fadeTask: Task<Void, Never>?
    
    private init() {}
    
    /// Запустити fade-in від 0 до targetVolume за duration секунд
    /// - Parameters:
    ///   - targetVolume: Цільова гучність (0.0 - 1.0)
    ///   - duration: Тривалість fade-in у секундах
    ///   - audioEngine: Посилання на аудіо-движок
    func startFadeIn(targetVolume: Float, duration: Double, audioEngine: AudioEngine) {
        // Скасувати попередній fade-in якщо він ще йде
        cancelFadeIn()
        
        isFadingIn = true
        fadeProgress = 0
        
        let steps = Int(duration * 20)  // 20 кроків на секунду — плавно
        let volumeStep = targetVolume / Float(steps)
        let intervalNanoseconds = UInt64(duration / Double(steps) * 1_000_000_000)
        
        audioEngine.setVolume(0)
        
        fadeTask = Task {
            for step in 1...steps {
                guard !Task.isCancelled else { break }
                
                let newVolume = volumeStep * Float(step)
                audioEngine.setVolume(min(newVolume, targetVolume))
                fadeProgress = Float(step) / Float(steps)
                
                try? await Task.sleep(nanoseconds: intervalNanoseconds)
            }
            
            // Гарантуємо що кінцева гучність точна
            audioEngine.setVolume(targetVolume)
            fadeProgress = 1.0
            isFadingIn = false
        }
    }
    
    /// Скасувати fade-in
    func cancelFadeIn() {
        fadeTask?.cancel()
        fadeTask = nil
        isFadingIn = false
        fadeProgress = 0
    }
}
