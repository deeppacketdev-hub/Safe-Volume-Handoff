import SwiftUI

@main
struct CastlieApp: App {
    init() {
        // Обмежуємо системний кеш зображень та мережі, щоб уникнути витоків пам'яті з часом
        let memoryCapacity = 40 * 1024 * 1024  // 40 MB RAM
        let diskCapacity = 150 * 1024 * 1024   // 150 MB Disk
        URLCache.shared = URLCache(memoryCapacity: memoryCapacity, diskCapacity: diskCapacity)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
 
