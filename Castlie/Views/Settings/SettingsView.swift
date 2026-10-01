import SwiftUI

struct SettingsView: View {
    @State private var viewModel = SettingsViewModel()
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Night Mode
                Section {
                    NightModeSettings()
                } header: {
                    Label("Нічний режим", systemImage: "moon.fill")
                }
                
                // MARK: - Fade-in
                Section {
                    FadeInSettings()
                } header: {
                    Label("Fade-in", systemImage: "waveform.path.ecg")
                }
                
                // MARK: - Volume Limit
                Section {
                    VolumeLimitSettings()
                } header: {
                    Label("Обмеження гучності", systemImage: "chart.bar.fill")
                }
                
                // MARK: - Devices
                Section {
                    Toggle("Показати демо-пристрої", isOn: $viewModel.discovery.showMockDevices)
                        .tint(ThemeManager.shared.accent)
                    
                    Toggle("Підтвердження підключення", isOn: $viewModel.safeVolume.config.requireConfirmation)
                        .tint(ThemeManager.shared.accent)
                } header: {
                    Label("Пристрої", systemImage: "hifispeaker.2.fill")
                }
                
                // MARK: - About
                Section {
                    HStack {
                        Text("Версія")
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                    }
                    
                    HStack {
                        Text("Розробник")
                        Spacer()
                        Text("Castlie Team")
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                    }
                    
                    NavigationLink {
                        AboutView()
                    } label: {
                        Text("Про дослідження")
                    }
                } header: {
                    Label("Про додаток", systemImage: "info.circle.fill")
                }
            }
            .safeAreaInset(edge: .bottom) {
                if AudioEngine.shared.currentTrack != nil {
                    Color.clear.frame(height: 70)
                }
            }
            .scrollContentBackground(.hidden)
            .background(ThemeManager.shared.primaryBackground.ignoresSafeArea())
            .navigationTitle("Налаштування")
            .onChange(of: viewModel.safeVolume.config) { _, _ in
                viewModel.saveAll()
            }
        }
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
