import SwiftUI

/// Діалог Safe Volume Handoff: вибір гучності ДО того, як звук піде на пристрій.
struct HandoffSheet: View {
    @Bindable var model: DeviceManagerViewModel
    let target: DeviceManagerViewModel.Target

    @State private var isWaitingForPicker = false
    private let safe = SafeVolumeManager.shared
    private let discovery = DeviceDiscoveryService.shared

    private enum Mode {
        /// Пристрій уже є виходом iPhone — гучність застосовується одразу.
        case applyNow
        /// Потрібно вибрати пристрій у системному меню iOS.
        case systemPicker
        /// Mac через Castlie Connect.
        case remote
    }

    private var device: AudioDevice { target.device }

    private var mode: Mode {
        if case .remote = target { return .remote }
        return model.isLocalRoute(device) ? .applyNow : .systemPicker
    }

    private var level: SafeVolumeManager.SafetyLevel {
        safe.safetyLevel(for: model.draftVolume, type: device.type)
    }

    private var recommended: Float { safe.safeStartVolume(for: device) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 22) {
                    header
                    volumeBlock
                    badges
                    if level == .danger {
                        Label("Тривале прослуховування на такій гучності може пошкодити слух.", systemImage: "ear.trianglebadge.exclamationmark")
                            .font(.footnote)
                            .foregroundStyle(level.color)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(level.color.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .animation(.spring(duration: 0.35), value: level)
            }
            .scrollBounceBehavior(.basedOnSize)
            .safeAreaInset(edge: .bottom) { actionArea }
            .background(Theme.elevated)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Скасувати", systemImage: "xmark") { model.cancel() }
                }
            }
        }
        .sensoryFeedback(.selection, trigger: level)
        .onChange(of: discovery.currentDevice) {
            // iOS перемкнула вихід після вибору в системному меню — закриваємо діалог.
            if isWaitingForPicker { model.handoffCompleted() }
        }
    }

    // MARK: - Parts

    private var header: some View {
        VStack(spacing: 10) {
            Image(systemName: device.symbol)
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 68, height: 68)
                .background(Theme.accent.opacity(0.16), in: Circle())

            Text(device.isBuiltIn ? "Цей iPhone" : device.name)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(2)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var subtitle: String {
        switch mode {
        case .remote: "Гучність Mac змінюється наживо"
        case .applyNow: "\(device.connection.label) · вибрана гучність застосується одразу"
        case .systemPicker: "\(device.connection.label) · гучність до підключення"
        }
    }

    private var volumeBlock: some View {
        VStack(spacing: 14) {
            Text(Format.percent(model.draftVolume))
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(level.color)
                .contentTransition(.numericText(value: Double(model.draftVolume)))
                .animation(.snappy(duration: 0.2), value: model.draftVolume)
                .accessibilityHidden(true)

            SafetyBadge(level: level)

            SafeVolumeSlider(value: model.draftVolume, deviceType: device.type) { model.draftChanged($0) }
                .padding(.top, 4)
        }
        .padding(20)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var badges: some View {
        HStack(spacing: 8) {
            if abs(model.draftVolume - recommended) > 0.005 {
                Button {
                    withAnimation(.snappy) { model.resetDraftToRecommended() }
                } label: {
                    Label("Рекомендовано \(Format.percent(recommended))", systemImage: "wand.and.stars")
                }
                .buttonStyle(.glass)
                .controlSize(.small)
                .transition(.scale.combined(with: .opacity))
            }
            if safe.config.isFadeInEnabled {
                InfoChip(symbol: "waveform.path", text: "Плавно \(String(format: "%.1f", safe.config.fadeInDuration)) с")
            }
            if safe.isNightModeActive {
                InfoChip(symbol: "moon.fill", text: "Ліміт \(Format.percent(safe.maxAllowedVolume))", tint: Theme.night)
            }
        }
        .font(.caption.weight(.semibold))
        .animation(.spring(duration: 0.3), value: abs(model.draftVolume - recommended) > 0.005)
    }

    // MARK: - Action

    @ViewBuilder
    private var actionArea: some View {
        VStack(spacing: 10) {
            switch mode {
            case .remote:
                primaryButton("Підключити Mac · \(Format.percent(model.draftVolume))", symbol: "laptopcomputer") {
                    model.confirmRemote()
                }
            case .applyNow:
                primaryButton(
                    model.activeRemote != nil ? "Повернути звук сюди" : "Застосувати \(Format.percent(model.draftVolume))",
                    symbol: "checkmark"
                ) {
                    model.confirmLocalCurrent()
                }
            case .systemPicker:
                Text(isWaitingForPicker
                     ? "Оберіть «\(device.name)» у меню. Гучність застосується автоматично."
                     : "Відкриється меню iOS — оберіть у ньому «\(device.name)».")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .contentTransition(.opacity)

                primaryLabel("Підключити · \(Format.percent(model.draftVolume))", symbol: "airplay.audio")
                    .opensSystemRoutePicker(
                        accessibilityLabel: "Підключити \(device.name) з гучністю \(Format.percent(model.draftVolume))",
                        onWillPresent: {
                            model.armForSystemPicker()
                            isWaitingForPicker = true
                        }
                    )
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(Theme.elevated)
    }

    private func primaryButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.glassProminent)
        .tint(level == .danger ? level.color : Theme.accent)
        .controlSize(.large)
    }

    /// Вигляд кнопки без власної дії — натискання перехоплює системне меню.
    private func primaryLabel(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .glassEffect(.regular.tint(level == .danger ? level.color : Theme.accent).interactive(), in: .capsule)
    }
}

private struct InfoChip: View {
    let symbol: String
    let text: String
    var tint: Color = .secondary

    var body: some View {
        Label(text, systemImage: symbol)
            .foregroundStyle(tint)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(.white.opacity(0.07), in: Capsule())
    }
}
