import SwiftUI

@main
struct CastlieApp: App {
    init() {
        // Дисковий кеш для обкладинок і відповідей API.
        URLCache.shared = URLCache(memoryCapacity: 20 * 1024 * 1024, diskCapacity: 150 * 1024 * 1024)
        // Запускаємо стеження за аудіовиходом і гучністю одразу, а не при першому відкритті екрана.
        _ = AudioEngine.shared
        _ = DeviceDiscoveryService.shared
        _ = CastlieConnectService.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
