import SwiftUI

struct SettingsView: View {
    @Bindable private var safe = SafeVolumeManager.shared
    @State private var serverDraft = CastlieConnectService.shared.serverDomain
    @State private var showForgetConfirm = false
    @FocusState private var serverFocused: Bool

    private let connect = CastlieConnectService.shared

    var body: some View {
        NavigationStack {
            Form {
                safeVolumeSection
                nightModeSection
                devicesSection
                connectSection

                Section {
                    NavigationLink {
                        AboutView()
                    } label: {
                        SettingsLabel("Про Castlie", symbol: "info.circle.fill", color: .gray)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Налаштування")
            .confirmationDialog("Забути всі пристрої?", isPresented: $showForgetConfirm, titleVisibility: .visible) {
                Button("Забути всі", role: .destructive) {
                    safe.forgetAll()
                }
            } message: {
                Text("Збережена гучність для кожного пристрою буде видалена.")
            }
        }
    }

    // MARK: - Sections

    private var safeVolumeSection: some View {
        Section {
            Toggle(isOn: $safe.config.requireConfirmation) {
                SettingsLabel("Підтверджувати гучність", symbol: "checkmark.shield.fill", color: .green)
            }

            Toggle(isOn: $safe.config.isFadeInEnabled.animation()) {
                SettingsLabel("Плавне наростання", symbol: "waveform.path", color: .teal)
            }

            if safe.config.isFadeInEnabled {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Тривалість")
                        Spacer()
                        Text("\(String(format: "%.1f", safe.config.fadeInDuration)) с")
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                            .contentTransition(.numericText(value: safe.config.fadeInDuration))
                            .animation(.snappy, value: safe.config.fadeInDuration)
                    }
                    Slider(value: $safe.config.fadeInDuration, in: 0.5...5, step: 0.5) {
                        Text("Тривалість наростання")
                    }
                    .tint(Theme.accent)
                }
            }
        } header: {
            Text("Безпечна гучність")
        } footer: {
            Text("Перед підключенням пристрою Castlie показує вибір гучності. Звук стартує з тиші й плавно наростає до вибраного рівня.")
        }
    }

    private var nightModeSection: some View {
        Section {
            Toggle(isOn: $safe.config.isNightModeEnabled.animation()) {
                SettingsLabel("Нічний режим", symbol: "moon.fill", color: Theme.night)
            }

            if safe.config.isNightModeEnabled {
                Picker("Початок", selection: $safe.config.nightModeStartHour) {
                    ForEach(0..<24, id: \.self) { Text(Self.hourText($0)).tag($0) }
                }
                Picker("Кінець", selection: $safe.config.nightModeEndHour) {
                    ForEach(0..<24, id: \.self) { Text(Self.hourText($0)).tag($0) }
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Максимальна гучність")
                        Spacer()
                        Text(Format.percent(safe.config.nightModeMaxVolume))
                            .monospacedDigit()
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $safe.config.nightModeMaxVolume, in: 0.1...0.8, step: 0.05) {
                        Text("Максимальна гучність уночі")
                    }
                    .tint(Theme.night)
                }
            }
        } header: {
            Text("Нічний режим")
        } footer: {
            if safe.config.isNightModeEnabled {
                Text(safe.isNightModeActive
                     ? "Діє зараз: гучність не підніметься вище \(Format.percent(safe.config.nightModeMaxVolume)), навіть кнопками iPhone."
                     : "Увімкнеться о \(Self.hourText(safe.config.nightModeStartHour)).")
            } else {
                Text("Обмежує максимальну гучність у нічні години.")
            }
        }
    }

    private var devicesSection: some View {
        Section {
            LabeledContent {
                Text("\(safe.knownDevices.count)")
                    .monospacedDigit()
            } label: {
                SettingsLabel("Збережені пристрої", symbol: "hifispeaker.2.fill", color: Theme.accent)
            }

            Button("Забути всі пристрої", role: .destructive) {
                showForgetConfirm = true
            }
            .disabled(safe.knownDevices.isEmpty)
        } header: {
            Text("Пристрої")
        }
    }

    private var connectSection: some View {
        Section {
            HStack {
                SettingsLabel("Сервер", symbol: "antenna.radiowaves.left.and.right", color: .blue)
                Spacer()
                TextField("castlie.dron.lol", text: $serverDraft)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .submitLabel(.done)
                    .focused($serverFocused)
                    .onSubmit { connect.updateServerDomain(serverDraft) }
            }

            LabeledContent("Стан") {
                HStack(spacing: 6) {
                    Circle()
                        .fill(connect.isConnected ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(connect.isConnected ? "На зв'язку" : "Підключення…")
                }
            }
        } header: {
            Text("Castlie Connect")
        } footer: {
            Text("Релей-сервер для передачі звуку на Castlie для Mac.")
        }
        .toolbar {
            if serverFocused {
                ToolbarItem(placement: .keyboard) {
                    Button("Готово") {
                        connect.updateServerDomain(serverDraft)
                        serverFocused = false
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        }
    }

    private static func hourText(_ hour: Int) -> String {
        String(format: "%02d:00", hour)
    }
}

/// Рядок з кольоровою іконкою, як у системних Параметрах.
struct SettingsLabel: View {
    let title: String
    let symbol: String
    let color: Color

    init(_ title: String, symbol: String, color: Color) {
        self.title = title
        self.symbol = symbol
        self.color = color
    }

    var body: some View {
        Label {
            Text(title)
        } icon: {
            Image(systemName: symbol)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 29, height: 29)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}
