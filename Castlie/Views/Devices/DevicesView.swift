import SwiftUI

struct DevicesView: View {
    enum Presentation { case tab, sheet }

    var presentation: Presentation = .tab

    @Environment(\.dismiss) private var dismiss
    @State private var model = DeviceManagerViewModel()

    private let engine = AudioEngine.shared
    private let safe = SafeVolumeManager.shared
    private let connect = CastlieConnectService.shared
    private let discovery = DeviceDiscoveryService.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ActiveOutputCard(model: model)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                if let pending = discovery.pendingHandoff {
                    Section {
                        PendingHandoffRow(pending: pending) { discovery.cancelPendingHandoff() }
                    }
                    .transition(.opacity)
                }

                connectSection
                knownDevicesSection
                otherDeviceSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Пристрої")
            .navigationBarTitleDisplayMode(presentation == .sheet ? .inline : .large)
            .toolbar {
                if presentation == .sheet {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Готово", systemImage: "checkmark") { dismiss() }
                    }
                }
            }
            .animation(.default, value: discovery.pendingHandoff)
            .animation(.default, value: safe.knownDevices.map(\.id))
            .animation(.default, value: connect.availableReceivers.map(\.id))
            .sheet(item: $model.target, onDismiss: model.sheetDismissed) { target in
                HandoffSheet(model: model, target: target)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Castlie Connect

    private var connectSection: some View {
        Section {
            if model.receivers.isEmpty {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(connect.isConnected ? "Mac не знайдено" : "Немає зв'язку з сервером")
                            .font(.subheadline.weight(.medium))
                        Text("Відкрийте Castlie на Mac у тій самій кімнаті.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "laptopcomputer")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(model.receivers) { remote in
                    Button {
                        if safe.config.requireConfirmation {
                            model.select(remote)
                        } else {
                            model.select(remote)
                            model.confirmRemote()
                        }
                    } label: {
                        DeviceRow(
                            symbol: "laptopcomputer",
                            name: remote.name,
                            detail: remote.isPlaying ? "Castlie Connect · грає" : "Castlie Connect",
                            volume: remote.volume,
                            type: .mac
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        } header: {
            HStack(spacing: 6) {
                Text("Castlie Connect")
                Circle()
                    .fill(connect.isConnected ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                    .accessibilityLabel(connect.isConnected ? "Сервер на зв'язку" : "Сервер недоступний")
            }
        }
    }

    // MARK: - Known devices

    @ViewBuilder
    private var knownDevicesSection: some View {
        let devices = model.otherKnownDevices
        if !devices.isEmpty {
            Section {
                ForEach(devices) { known in
                    knownDeviceRow(known)
                        .swipeActions {
                            Button("Забути", systemImage: "trash", role: .destructive) {
                                model.forget(known)
                            }
                        }
                }
            } header: {
                Text("Мої пристрої")
            } footer: {
                Text("Castlie пам'ятає гучність кожного пристрою й застосовує її при підключенні — але не вище жовтої зони.")
            }
        }
    }

    @ViewBuilder
    private func knownDeviceRow(_ known: KnownDevice) -> some View {
        let device = known.device
        let isLocalRoute = model.isLocalRoute(device)
        let detail = isLocalRoute
            ? "Вихід iPhone · повернути звук сюди"
            : "\(device.connection.label) · \(Format.relative(known.lastUsed))"
        let row = DeviceRow(symbol: device.symbol, name: device.name, detail: detail, volume: known.volume, type: device.type)

        if safe.config.requireConfirmation || isLocalRoute {
            Button {
                if safe.config.requireConfirmation {
                    model.select(device)
                } else {
                    model.select(device)
                    model.draftVolume = safe.safeStartVolume(for: device)
                    model.confirmLocalCurrent()
                }
            } label: { row }
            .buttonStyle(.plain)
        } else {
            row.opensSystemRoutePicker(accessibilityLabel: "Підключити \(device.name)") {
                model.armWithoutConfirmation(device)
            }
        }
    }

    // MARK: - System picker

    private var otherDeviceSection: some View {
        Section {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Інший пристрій")
                        .font(.body.weight(.medium))
                    Text("AirPlay або Bluetooth")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: "airplay.audio")
                    .foregroundStyle(Theme.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .opensSystemRoutePicker(accessibilityLabel: "Вибрати інший пристрій AirPlay або Bluetooth")
        } footer: {
            Text("Після вибору Castlie приглушить звук, виставить безпечну гучність і плавно її підніме.")
        }
    }
}

// MARK: - Active output

private struct ActiveOutputCard: View {
    let model: DeviceManagerViewModel

    private let engine = AudioEngine.shared
    private let safe = SafeVolumeManager.shared

    var body: some View {
        let device = model.activeOutput
        let level = safe.safetyLevel(for: engine.volume, type: device.type)

        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(systemName: device.symbol)
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 56, height: 56)
                    .background(Theme.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .contentTransition(.symbolEffect(.replace))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Зараз грає на")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(device.isBuiltIn ? "Цей iPhone" : device.name)
                        .font(.title3.weight(.bold))
                        .lineLimit(1)
                    Text(device.connection.label)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }

            if let track = engine.currentTrack {
                HStack(spacing: 8) {
                    NowPlayingIndicator(isPlaying: engine.isPlaying)
                    Text("\(track.name) — \(track.artistName)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.accent)
                        .lineLimit(1)
                }
            }

            VStack(spacing: 10) {
                SafeVolumeSlider(value: engine.volume, deviceType: device.type) { engine.setVolume($0) }
                HStack {
                    SafetyBadge(level: level, compact: true)
                    Spacer()
                    Text(Format.percent(engine.volume))
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                        .foregroundStyle(level.color)
                        .contentTransition(.numericText(value: Double(engine.volume)))
                        .animation(.snappy, value: engine.volume)
                }
            }

            if model.activeRemote != nil {
                Button {
                    model.disconnectRemote()
                } label: {
                    Label("Повернути звук на iPhone", systemImage: "iphone")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
                .controlSize(.large)
            }
        }
        .padding(20)
        .glassEffect(.regular.tint(Theme.accent.opacity(0.08)), in: .rect(cornerRadius: 26))
        .animation(.spring(duration: 0.4), value: device)
    }
}

// MARK: - Rows

struct DeviceRow: View {
    let symbol: String
    let name: String
    let detail: String
    let volume: Float
    let type: DeviceType

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 40, height: 40)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 11, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VolumePill(volume: volume, deviceType: type)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Двічі торкніться, щоб підключити з безпечною гучністю")
    }
}

private struct PendingHandoffRow: View {
    let pending: DeviceDiscoveryService.PendingHandoff
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            ProgressView()
                .frame(width: 40, height: 40)
            VStack(alignment: .leading, spacing: 2) {
                Text("Очікуємо \(pending.device.name)")
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                Text("Гучність \(Format.percent(pending.volume)) застосується при підключенні")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Button("Скасувати", action: onCancel)
                .font(.subheadline.weight(.semibold))
                .buttonStyle(.borderless)
                .tint(Theme.accent)
        }
    }
}

#Preview {
    DevicesView()
        .preferredColorScheme(.dark)
}
