import Foundation
import Observation

@Observable
@MainActor
class NightModeManager {
    static let shared = NightModeManager()
    
    private(set) var isActive = false
    nonisolated(unsafe) private var timer: Timer?
    
    private init() {
        checkNightMode()
        startPeriodicCheck()
    }
    
    /// Перевірити чи зараз нічний режим
    func checkNightMode() {
        let config = SafeVolumeManager.shared.config
        isActive = config.isNightModeActive
    }
    
    /// Запустити періодичну перевірку (кожну хвилину)
    private func startPeriodicCheck() {
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            Task { @MainActor in
                NightModeManager.shared.checkNightMode()
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}
