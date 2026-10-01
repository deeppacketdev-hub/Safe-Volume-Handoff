import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @State private var audioEngine = AudioEngine.shared
    @State private var showFullPlayer = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // TabView
            TabView(selection: $selectedTab) {
                HomeView()
                    .tabItem {
                        Label("Головна", systemImage: "music.note.house.fill")
                    }
                    .tag(AppTab.home)
                
                SearchView()
                    .tabItem {
                        Label("Пошук", systemImage: "magnifyingglass")
                    }
                    .tag(AppTab.search)
                
                DevicesView()
                    .tabItem {
                        Label("Пристрої", systemImage: "hifispeaker.2.fill")
                    }
                    .tag(AppTab.devices)
                
                SettingsView()
                    .tabItem {
                        Label("Налаштування", systemImage: "gearshape.fill")
                    }
                    .tag(AppTab.settings)
            }
            .tint(ThemeManager.shared.accent)
            
            // Міні-плеєр — показується тільки коли є трек
            if audioEngine.currentTrack != nil {
                MiniPlayerView(showFullPlayer: $showFullPlayer)
                    .padding(.bottom, 49) // Висота TabBar = 49pt
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.3), value: audioEngine.currentTrack != nil)
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showFullPlayer) {
            FullPlayerView(isPresented: $showFullPlayer)
        }
    }
}

enum AppTab: String, CaseIterable {
    case home
    case search
    case devices
    case settings
}

#Preview {
    ContentView()
}
