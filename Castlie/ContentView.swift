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
            
            // Міні-плеєр — показується тільки коли є трек (парить над TabBar як острівець)
            if audioEngine.currentTrack != nil {
                MiniPlayerView(showFullPlayer: $showFullPlayer)
                    .padding(.bottom, 54) // Відступ над стандартним TabBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.38, dampingFraction: 0.82), value: audioEngine.currentTrack != nil)
            }
            
            // Системний невидимий міст для перехоплення та синхронізації апаратної гучності (Mac, AirPlay, Bluetooth)
            SystemVolumeBridge()
                .frame(width: 1, height: 1)
                .opacity(0.0001)
                .allowsHitTesting(false)
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showFullPlayer) {
            FullPlayerView(isPresented: $showFullPlayer)
                .presentationBackground(.clear)
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
