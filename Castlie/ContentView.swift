import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @State private var audioEngine = AudioEngine.shared
    @State private var showFullPlayer = false
    @State private var showDevicesSheet = false
    @State private var devicesSheetDetent: PresentationDetent = .medium

    var body: some View {
        GeometryReader { windowGeo in
            let screenWidth = windowGeo.size.width
            let screenHeight = windowGeo.size.height
            let safeTop = windowGeo.safeAreaInsets.top > 0 ? windowGeo.safeAreaInsets.top : 59
            let safeBottom = windowGeo.safeAreaInsets.bottom > 0 ? windowGeo.safeAreaInsets.bottom : 34

            ZStack(alignment: .topLeading) {
                // 1. TabView
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
                .frame(width: screenWidth, height: screenHeight)

                // 2. Apple Interactive Morphing Player
                if audioEngine.currentTrack != nil {
                    FullPlayerView(
                        isPresented: $showFullPlayer,
                        showDevicesSheet: $showDevicesSheet,
                        devicesSheetDetent: $devicesSheetDetent,
                        selectedTab: selectedTab,
                        screenWidth: screenWidth,
                        screenHeight: screenHeight,
                        safeTop: safeTop,
                        safeBottom: safeBottom
                    )
                    .zIndex(20)
                }
            }
            .preferredColorScheme(.dark)
            .animation(.spring(response: 0.38, dampingFraction: 0.84), value: audioEngine.currentTrack != nil)
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showDevicesSheet) {
            DevicesView(currentDetent: $devicesSheetDetent)
                .presentationDetents([.medium, .large], selection: $devicesSheetDetent)
                .presentationDragIndicator(.visible)
                .presentationBackground(ThemeManager.shared.primaryBackground)
                .ignoresSafeArea(edges: .bottom)
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
