import SwiftUI

enum AppTab: Hashable {
    case home, devices, settings, search
}

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @State private var showPlayer = false
    @State private var showDevices = false
    @Namespace private var playerNamespace
    @Environment(\.scenePhase) private var scenePhase

    private let engine = AudioEngine.shared

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Головна", systemImage: "music.note.house.fill", value: AppTab.home) {
                HomeView()
            }
            Tab("Пристрої", systemImage: "hifispeaker.2.fill", value: AppTab.devices) {
                DevicesView()
            }
            Tab("Налаштування", systemImage: "gearshape.fill", value: AppTab.settings) {
                SettingsView()
            }
            Tab(value: AppTab.search, role: .search) {
                SearchView()
            }
        }
        .tint(Theme.accent)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory(isEnabled: engine.currentTrack != nil) {
            MiniPlayer(onOpen: { showPlayer = true }, onDevices: { showDevices = true })
                .matchedTransitionSource(id: "now-playing", in: playerNamespace)
        }
        .fullScreenCover(isPresented: $showPlayer) {
            NowPlayingView()
                .navigationTransition(.zoom(sourceID: "now-playing", in: playerNamespace))
        }
        .sheet(isPresented: $showDevices) {
            DevicesView(presentation: .sheet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .statusBanners()
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            SafeVolumeManager.shared.refreshNightMode()
            engine.reconcileVolumeAfterForeground()
        }
        .onChange(of: engine.currentTrack == nil) { _, isEmpty in
            if isEmpty { showPlayer = false }
        }
    }
}

#Preview {
    ContentView()
        .preferredColorScheme(.dark)
}
