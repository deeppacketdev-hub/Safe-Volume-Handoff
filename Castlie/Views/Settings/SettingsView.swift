import SwiftUI

struct SettingsView: View {
    // MARK: - Properties
    @State private var viewModel = SettingsViewModel()

    // MARK: - Body
    var body: some View {
        NavigationStack {
            List {
                // 1. Безпека слуху
                Section {
                    VolumeLimitSettings()
                } header: {
                    SettingsSectionHeader(
                        title: "Безпека слуху",
                        icon: "speaker.wave.3.fill",
                        badgeColor: Color(hex: "FF6B35")
                    )
                }

                // 2. Нічний режим
                Section {
                    NightModeSettings()
                } header: {
                    SettingsSectionHeader(
                        title: "Нічний режим",
                        icon: "moon.fill",
                        badgeColor: Color(hex: "5856D6")
                    )
                }

                // 3. Плавний старт
                Section {
                    FadeInSettings()
                } header: {
                    SettingsSectionHeader(
                        title: "Плавний старт",
                        icon: "waveform.path",
                        badgeColor: Color(hex: "00C7BE")
                    )
                }

                // 4. Підключення та Handoff
                Section {
                    Toggle("Запитувати підтвердження", isOn: $viewModel.safeVolume.config.requireConfirmation)
                        .tint(ThemeManager.shared.accent)

                    Toggle("Показувати демо-пристрої", isOn: $viewModel.discovery.showMockDevices)
                        .tint(ThemeManager.shared.accent)

                    HStack {
                        Text("Сервер Connect")
                            .foregroundStyle(ThemeManager.shared.primaryText)
                        Spacer()
                        TextField("castlie.dron.lol", text: Binding(
                            get: { CastlieConnectService.shared.serverDomain },
                            set: { CastlieConnectService.shared.serverDomain = $0 }
                        ))
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(ThemeManager.shared.accent)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    }
                } header: {
                    SettingsSectionHeader(
                        title: "Підключення",
                        icon: "antenna.radiowaves.left.and.right",
                        badgeColor: Color(hex: "007AFF")
                    )
                } footer: {
                    Text("Контроль гучності перед перенесенням аудіо на інший пристрій")
                        .font(.system(size: 12))
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                }

                // 5. Про додаток
                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        HStack {
                            Text("Про Castlie")
                                .foregroundStyle(ThemeManager.shared.primaryText)
                            Spacer()
                            Text("1.0.0")
                                .font(.system(size: 14))
                                .foregroundStyle(ThemeManager.shared.secondaryText)
                        }
                    }
                } header: {
                    SettingsSectionHeader(
                        title: "Інформація",
                        icon: "info.circle.fill",
                        badgeColor: Color(hex: "8E8E93")
                    )
                }
            }
            .listStyle(.insetGrouped)
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

// MARK: - Dedicated Subviews

private struct SettingsSectionHeader: View {
    let title: String
    let icon: String
    let badgeColor: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(badgeColor)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

            Text(title)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(ThemeManager.shared.secondaryText)
                .textCase(nil)
        }
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
