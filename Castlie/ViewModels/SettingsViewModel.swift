import Foundation
import Observation

@Observable
@MainActor
class SettingsViewModel {
    var safeVolume = SafeVolumeManager.shared
    var discovery = DeviceDiscoveryService.shared
    var theme = ThemeManager.shared
    
    /// Зберегти всі налаштування
    func saveAll() {
        safeVolume.saveConfig()
    }
}
