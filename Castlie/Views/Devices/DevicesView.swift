import SwiftUI
import AVKit

struct DevicesView: View {
    // MARK: - Properties
    var currentDetent: Binding<PresentationDetent>? = nil

    @State private var viewModel = DeviceManagerViewModel()
    @State private var safeVolume = SafeVolumeManager.shared
    @State private var theme = ThemeManager.shared
    @State private var showServerSettings = false
    @State private var showSessionSheet = false
    @State private var serverDomainInput = ""
    @State private var isDraggingVolume = false
    @State private var localVolume: Float = 0.5
    @AppStorage("autoInviteSession") private var autoInviteSession = true

    // MARK: - Computed State
    private var isExternalActive: Bool {
        viewModel.connectService.activeRemoteDevice != nil ||
        (viewModel.discovery.currentDevice != nil && viewModel.discovery.currentDevice?.type != .iPhone)
    }

    private var activeDeviceName: String {
        if let activeRemote = viewModel.connectService.activeRemoteDevice {
            return activeRemote.name
        }
        return viewModel.discovery.currentDevice?.name ?? "Цей iPhone"
    }

    private var activeDeviceIcon: String {
        if viewModel.connectService.activeRemoteDevice != nil {
            return "laptopcomputer"
        }
        guard let current = viewModel.discovery.currentDevice else { return "iphone.gen3" }
        switch current.type {
        case .iPhone: return "iphone.gen3"
        case .mac: return "laptopcomputer"
        case .speaker: return "hifispeaker.fill"
        case .headphones: return "headphones"
        case .tv: return "tv.fill"
        default: return "airplayaudio"
        }
    }

    private var activeDeviceBadge: String {
        if viewModel.connectService.activeRemoteDevice != nil {
            return "Castlie Connect"
        }
        guard let current = viewModel.discovery.currentDevice else { return "Безпечна" }
        if current.type == .iPhone {
            let vol = viewModel.audioEngine.volume
            switch safeVolume.safetyLevel(for: vol) {
            case .safe: return "Безпечна"
            case .warning: return "Середня"
            case .danger: return "Висока"
            }
        }
        return current.connectionType.rawValue
    }

    private var activeVolume: Float {
        if isDraggingVolume {
            return localVolume
        }
        if let activeRemote = viewModel.connectService.activeRemoteDevice {
            return activeRemote.volume
        }
        return viewModel.audioEngine.volume
    }

    private var currentTrackDisplay: String {
        if let track = viewModel.audioEngine.currentTrack {
            return "\(track.name) – \(track.artistName)"
        }
        return "Зараз нічого не грає"
    }

    private var isExpanded: Bool {
        if let detent = currentDetent?.wrappedValue {
            return detent == .large
        }
        return true
    }

    // MARK: - Body
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Brand background
                theme.primaryBackground.ignoresSafeArea()

                // Scrollable Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 1. Header: "Castlie Connect"
                        Text("Castlie Connect")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(theme.primaryText)
                            .padding(.top, 4)

                        // 2. Hero Active Device Card
                        activeDeviceHeroCard

                        // 3. Castlie Session Auto-Invite Row
                        sessionToggleRow

                        // Divider line
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 0.8)
                            .padding(.vertical, 2)

                        // 4. Devices List (Castlie Connect + Bluetooth + AirPlay)
                        devicesListSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, isExpanded ? 130 : 28)
                }

                // 5. Pinned Bottom Action Buttons (Спільний сеанс + Bluetooth і Airplay)
                // Only shown when menu is fully opened / expanded (large detent or full tab)!
                if isExpanded {
                    bottomActionButtons
                        .transition(.asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .move(edge: .bottom).combined(with: .opacity)
                        ))
                }
            }
            .navigationBarHidden(true)
            .background(theme.primaryBackground.ignoresSafeArea())
            .animation(.spring(response: 0.36, dampingFraction: 0.84), value: isExpanded)
            .sheet(isPresented: $viewModel.showHandoffConfirm) {
                if let device = viewModel.selectedDevice {
                    HandoffConfirmSheet(
                        device: device,
                        adjustedVolume: $viewModel.adjustedVolume,
                        onVolumeChanged: { newVol in
                            viewModel.handleAdjustedVolumeChange(newVol)
                        },
                        onConfirm: { viewModel.confirmHandoff() },
                        onCancel: { viewModel.cancelHandoff() }
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $showSessionSheet) {
                CastlieSessionSheet(
                    roomName: "default",
                    serverDomain: viewModel.connectService.serverDomain
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
            .alert("Сервер Castlie Connect", isPresented: $showServerSettings) {
                TextField("Домен сервера", text: $serverDomainInput)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                Button("Зберегти", action: saveServerSettings)
                Button("Скасувати", role: .cancel) {}
            } message: {
                Text("Вкажіть домен сервера для локальної мережі (напр. castlie.dron.lol).")
            }
        }
        .background(theme.primaryBackground.ignoresSafeArea())
    }

    // MARK: - Hero Active Device Card
    private var activeDeviceHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(activeDeviceName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(theme.primaryText)
                            .lineLimit(1)

                        // Safety / Status Badge
                        Text(activeDeviceBadge)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(theme.secondaryText)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    }

                    // Playing Track Line in Castlie Accent
                    HStack(spacing: 6) {
                        Image(systemName: viewModel.audioEngine.currentTrack != nil && viewModel.audioEngine.isPlaying ? "speaker.wave.2.fill" : "music.note")
                            .font(.system(size: 12))
                        Text(currentTrackDisplay)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(theme.accent)
                }

                Spacer()

                // Active Device Icon with Castlie Accent
                Image(systemName: activeDeviceIcon)
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(theme.accent)
                    .frame(width: 44, height: 44)
            }

            // Interactive Volume Control for Active Output
            HStack(spacing: 10) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.secondaryText)

                Slider(
                    value: Binding(
                        get: { activeVolume },
                        set: { newVol in
                            localVolume = newVol
                            handleActiveVolumeChange(newVol)
                        }
                    ),
                    in: 0...1,
                    onEditingChanged: { editing in
                        isDraggingVolume = editing
                        if editing {
                            SystemVolumeController.shared.beginVolumeInteraction()
                            localVolume = activeVolume
                        } else {
                            SystemVolumeController.shared.endVolumeInteraction()
                        }
                    }
                )
                .tint(safeVolume.safetyLevel(for: activeVolume).color)

                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.secondaryText)

                Text("\(Int(activeVolume * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(safeVolume.safetyLevel(for: activeVolume).color)
                    .frame(minWidth: 32, alignment: .trailing)
            }
            .padding(.top, 2)
        }
        .padding(18)
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.accent.opacity(0.18), lineWidth: 1)
        )
    }

    // MARK: - Castlie Session Auto-Invite Row
    private var sessionToggleRow: some View {
        HStack(spacing: 14) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 17))
                .foregroundStyle(theme.accent)
                .frame(width: 32, height: 32)
                .background(theme.accent.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text("Автоматично запрошувати слухачів поблизу")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(theme.primaryText)
                .lineLimit(2)

            Spacer()

            Toggle("", isOn: $autoInviteSession)
                .labelsHidden()
                .tint(theme.accent)
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Devices List Section
    private var devicesListSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            let receivers = viewModel.connectService.availableReceivers.filter {
                $0.id != viewModel.connectService.activeRemoteDevice?.id
            }
            let liveBluetooth = viewModel.discovery.connectedBluetoothDevices.filter {
                $0.name.lowercased() != activeDeviceName.lowercased()
            }
            let hasDevices = !receivers.isEmpty || !liveBluetooth.isEmpty || isExternalActive

            if !hasDevices {
                VStack(spacing: 8) {
                    Image(systemName: "antenna.radiowaves.left.and.right.slash")
                        .font(.system(size: 24))
                        .foregroundStyle(theme.secondaryText.opacity(0.6))
                        .padding(.top, 6)
                    
                    Text("Немає пристроїв онлайн")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.primaryText)
                    
                    Text("Увімкніть Castlie на Mac або підключіть Bluetooth-пристрій через кнопку нижче.")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(theme.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(theme.cardBackground.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                Text("Виберіть пристрій")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
                    .padding(.leading, 4)

                VStack(spacing: 10) {
                    // A. Castlie Connect Receivers (Macs - ONLY ONLINE)
                    ForEach(receivers) { remote in
                        CastlieDeviceRow(
                            icon: "laptopcomputer",
                            name: remote.name,
                            subtitle: "Castlie Connect • \(Int(remote.volume * 100))%",
                            volume: remote.volume,
                            isActive: false,
                            onTap: {
                                viewModel.initiateRemoteHandoff(to: remote)
                            }
                        )
                    }

                    // B. "Цей iPhone" (when external device is active, to switch back)
                    if isExternalActive {
                        let iphoneVol = safeVolume.lastKnownVolume(for: "builtin-speaker")
                            ?? safeVolume.lastKnownVolume(forDeviceName: "iPhone")
                            ?? 0.35
                        CastlieDeviceRow(
                            icon: "iphone.gen3",
                            name: "Цей iPhone",
                            subtitle: "Вбудований динамік • \(Int(iphoneVol * 100))%",
                            volume: iphoneVol,
                            isActive: false,
                            onTap: {
                                let iphoneDev = AudioDevice(
                                    id: "builtin-speaker",
                                    name: "Цей iPhone",
                                    type: .iPhone,
                                    connectionType: .builtIn,
                                    lastKnownVolume: iphoneVol,
                                    isConnected: false
                                )
                                viewModel.initiateHandoff(to: iphoneDev)
                            }
                        )
                    }

                    // C. Live Connected Bluetooth Devices (AirPods, Speakers physically connected right now)
                    ForEach(liveBluetooth) { dev in
                        let vol = dev.lastKnownVolume ?? safeVolume.recommendedVolume(for: dev)
                        CastlieDeviceRow(
                            icon: dev.type.sfSymbol,
                            name: dev.name,
                            subtitle: "\(dev.connectionType.rawValue) • \(Int(vol * 100))%",
                            volume: vol,
                            isActive: false,
                            onTap: {
                                viewModel.initiateHandoff(to: dev)
                            }
                        )
                    }
                }
            }
        }
    }

    // MARK: - Bottom Action Buttons
    private var bottomActionButtons: some View {
        HStack(spacing: 12) {
            // 1. Спільний сеанс
            Button(action: {
                HapticFeedbackService.light()
                showSessionSheet = true
            }) {
                VStack(spacing: 6) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(theme.accent)

                    Text("Спільний сеанс")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.primaryText)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 68)
                .background(theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // 2. Bluetooth і Airplay (with overlayed native AirPlay picker)
            ZStack {
                VStack(spacing: 6) {
                    Image(systemName: "airplayaudio")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(theme.accent)

                    Text("Bluetooth і Airplay")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.primaryText)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 68)
                .background(theme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )

                // Invisible native AVRoutePickerView covers button for instant 1-tap route sheet
                AirPlayPickerButton()
                    .frame(maxWidth: .infinity, maxHeight: 68)
                    .opacity(0.012)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 68)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 16)
        .background(
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [
                        theme.primaryBackground.opacity(0.0),
                        theme.primaryBackground.opacity(0.85),
                        theme.primaryBackground
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 24)

                theme.primaryBackground
            }
            .ignoresSafeArea()
        )
    }

    // MARK: - Helpers
    private func handleActiveVolumeChange(_ newVol: Float) {
        if let activeRemote = viewModel.connectService.activeRemoteDevice {
            viewModel.connectService.setRemoteVolume(deviceId: activeRemote.id, volume: newVol)
        } else {
            viewModel.audioEngine.setVolume(newVol)
        }
    }

    private func openServerSettings() {
        serverDomainInput = viewModel.connectService.serverDomain
        showServerSettings = true
    }

    private func saveServerSettings() {
        viewModel.connectService.serverDomain = serverDomainInput
    }
}

// MARK: - Castlie Device Row Component
private struct CastlieDeviceRow: View {
    let icon: String
    let name: String
    let subtitle: String
    let volume: Float
    let isActive: Bool
    let onTap: () -> Void

    @State private var safeVolume = SafeVolumeManager.shared
    @State private var theme = ThemeManager.shared

    var body: some View {
        Button(action: {
            HapticFeedbackService.light()
            onTap()
        }) {
            HStack(spacing: 14) {
                // Device Icon
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(isActive ? theme.accent : theme.primaryText)
                    .frame(width: 40, height: 40)
                    .background(isActive ? theme.accent.opacity(0.14) : Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                // Name & Subtitle with saved / system sound
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(isActive ? theme.accent : theme.primaryText)
                        .lineLimit(1)

                    Text(subtitle)
                        .font(.system(size: 12.5, weight: .regular))
                        .foregroundStyle(theme.secondaryText)
                        .lineLimit(1)
                }

                Spacer()

                // Volume percentage badge with Safe Volume Color
                Text("\(Int(volume * 100))%")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(safeVolume.safetyLevel(for: volume).color)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(safeVolume.safetyLevel(for: volume).color.opacity(0.14))
                    .clipShape(Capsule())

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.24))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Castlie Session Sheet
private struct CastlieSessionSheet: View {
    let roomName: String
    let serverDomain: String
    @Environment(\.dismiss) private var dismiss
    @State private var copied: Bool = false
    @State private var theme = ThemeManager.shared
    @State private var connectService = CastlieConnectService.shared

    var body: some View {
        VStack(spacing: 20) {
            // Drag Indicator
            RoundedRectangle(cornerRadius: 2.5)
                .fill(Color.white.opacity(0.2))
                .frame(width: 36, height: 5)
                .padding(.top, 8)

            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 42))
                .foregroundStyle(theme.accent)
                .padding(.top, 8)

            VStack(spacing: 6) {
                Text("Спільний сеанс Castlie")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(theme.primaryText)

                Text("Слухайте разом та синхронізуйте звук на всіх пристроях у реальному часі")
                    .font(.system(size: 13.5))
                    .foregroundStyle(theme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            // Room Info Box
            VStack(spacing: 10) {
                HStack {
                    Text("Кімната:")
                        .foregroundStyle(theme.secondaryText)
                    Spacer()
                    Text(roomName)
                        .fontWeight(.bold)
                        .foregroundStyle(theme.primaryText)
                }
                .font(.system(size: 14))

                HStack {
                    Text("Сервер:")
                        .foregroundStyle(theme.secondaryText)
                    Spacer()
                    HStack(spacing: 6) {
                        Circle()
                            .fill(connectService.isConnected ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                        Text(serverDomain)
                            .foregroundStyle(theme.accent)
                    }
                }
                .font(.system(size: 14))
            }
            .padding(14)
            .background(theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .padding(.horizontal, 24)

            // Action: Copy Share Link
            Button(action: {
                UIPasteboard.general.string = "https://\(serverDomain)/?room=\(roomName)"
                HapticFeedbackService.success()
                withAnimation {
                    copied = true
                }
                Task {
                    try? await Task.sleep(for: .seconds(2))
                    withAnimation {
                        copied = false
                    }
                }
            }) {
                HStack(spacing: 8) {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc.fill")
                    Text(copied ? "Посилання скопійовано!" : "Копіювати посилання")
                        .fontWeight(.semibold)
                }
                .font(.system(size: 15))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(theme.accent)
                .clipShape(Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)

            Spacer()
        }
        .background(theme.primaryBackground.ignoresSafeArea())
    }
}

#Preview {
    DevicesView()
        .preferredColorScheme(.dark)
}
