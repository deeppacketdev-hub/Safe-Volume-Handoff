import SwiftUI

struct DevicesView: View {
    @State private var viewModel = DeviceManagerViewModel()
    @State private var showServerSettings = false
    @State private var serverDomainInput = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // MARK: - 1. Поточний звук (Цей пристрій)
                    if let current = viewModel.discovery.currentDevice {
                        currentDeviceSection(current: current)
                    }
                    
                    // MARK: - 2. ПРІОРИТЕТ №1: Castlie Connect
                    castlieConnectSection
                    
                    // MARK: - 3. ПРІОРИТЕТ №2: Альтернативи (AirPlay та Bluetooth)
                    otherDevicesSection
                    
                    // MARK: - 4. Статус захисту
                    safetyStatusFooter
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, AudioEngine.shared.currentTrack != nil ? 90 : 30)
            }
            .background(ThemeManager.shared.primaryBackground.ignoresSafeArea())
            .navigationTitle("Пристрої")
            .sheet(isPresented: $viewModel.showHandoffConfirm) {
                if let device = viewModel.selectedDevice {
                    HandoffConfirmSheet(
                        device: device,
                        adjustedVolume: $viewModel.adjustedVolume,
                        onConfirm: { viewModel.confirmHandoff() },
                        onCancel: { viewModel.cancelHandoff() }
                    )
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                }
            }
            .alert("Сервер Castlie Connect", isPresented: $showServerSettings) {
                TextField("Домен сервера", text: $serverDomainInput)
                Button("Зберегти") {
                    viewModel.connectService.serverDomain = serverDomainInput
                }
                Button("Скасувати", role: .cancel) {}
            } message: {
                Text("Вкажіть домен вашого сервера на Coolify (за замовчуванням castlie.dron.lol).")
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func currentDeviceSection(current: AudioDevice) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Поточний вивід")
                .font(AppFonts.caption)
                .foregroundStyle(ThemeManager.shared.secondaryText)
                .padding(.horizontal, 4)
            
            CurrentDeviceCard(device: current) {
                viewModel.initiateHandoff(to: current)
            }
        }
    }
    
    @ViewBuilder
    private var castlieConnectSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Castlie Connect")
                    .font(AppFonts.headline)
                    .foregroundStyle(ThemeManager.shared.primaryText)
                
                Spacer()
                
                Button {
                    serverDomainInput = viewModel.connectService.serverDomain
                    showServerSettings = true
                } label: {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(viewModel.connectService.isConnected ? Color.green : Color.orange)
                            .frame(width: 7, height: 7)
                        Text(viewModel.connectService.isConnected ? "Онлайн" : "Підключення")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(ThemeManager.shared.cardBackground)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 4)
            
            let receivers = viewModel.connectService.availableReceivers
            if receivers.isEmpty {
                HStack(spacing: 14) {
                    Image(systemName: "laptopcomputer")
                        .font(.title2)
                        .foregroundStyle(ThemeManager.shared.accent.opacity(0.8))
                        .frame(width: 40, height: 40)
                        .background(ThemeManager.shared.accent.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Очікування Mac у мережі")
                            .font(AppFonts.subheadline)
                            .foregroundStyle(ThemeManager.shared.primaryText)
                        Text("Запустіть Castlie Connect на комп'ютері")
                            .font(AppFonts.caption)
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                    }
                    Spacer()
                }
                .cardStyle()
            } else {
                VStack(spacing: 12) {
                    ForEach(receivers) { remote in
                        CastlieRemoteDeviceCard(
                            remote: remote,
                            onHandoff: {
                                viewModel.initiateRemoteHandoff(to: remote)
                            },
                            onVolumeChange: { newVol in
                                viewModel.connectService.setRemoteVolume(deviceId: remote.id, volume: newVol)
                            }
                        )
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var otherDevicesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Інші пристрої")
                .font(AppFonts.caption)
                .foregroundStyle(ThemeManager.shared.secondaryText)
                .padding(.horizontal, 4)
            
            // Акуратний AirPlay рядок
            HStack {
                Image(systemName: "airplayaudio")
                    .font(.title3)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
                    .frame(width: 36, height: 36)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("AirPlay")
                        .font(AppFonts.subheadline)
                        .foregroundStyle(ThemeManager.shared.primaryText)
                    Text("Трансляція на Apple TV або HomePod")
                        .font(AppFonts.caption)
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                }
                
                Spacer()
                
                AirPlayPickerButton()
                    .frame(width: 36, height: 36)
            }
            .padding(12)
            .background(ThemeManager.shared.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Збережені Bluetooth пристрої
            let known = viewModel.discovery.knownDevices
            if !known.isEmpty {
                VStack(spacing: 6) {
                    ForEach(Array(known.prefix(3))) { dev in
                        SavedBluetoothRow(device: dev)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var safetyStatusFooter: some View {
        let maxPercent = Int(SafeVolumeManager.shared.config.effectiveMaxVolume * 100)
        HStack(spacing: 8) {
            Image(systemName: "checkmark.shield.fill")
                .font(.caption2)
                .foregroundStyle(ThemeManager.shared.safeColor)
            Text("Safe Volume: Макс. поріг \(maxPercent)% • Fade-in активний")
                .font(AppFonts.caption2)
                .foregroundStyle(ThemeManager.shared.secondaryText)
        }
        .padding(.top, 4)
    }
}

// MARK: - Saved Bluetooth Row (Винесено для швидкої компіляції)

struct SavedBluetoothRow: View {
    let device: AudioDevice
    
    var body: some View {
        let volPercent = Int((device.lastKnownVolume ?? 0.5) * 100)
        HStack {
            Image(systemName: device.type.sfSymbol)
                .font(.body)
                .foregroundStyle(ThemeManager.shared.secondaryText)
                .frame(width: 28)
            
            Text(device.name)
                .font(AppFonts.subheadline)
                .foregroundStyle(ThemeManager.shared.primaryText)
            
            Spacer()
            
            Text("Остання: \(volPercent)%")
                .font(AppFonts.caption)
                .foregroundStyle(ThemeManager.shared.secondaryText)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(ThemeManager.shared.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Castlie Connect Remote Device Card (Чистий дизайн)

struct CastlieRemoteDeviceCard: View {
    let remote: CastlieRemoteDevice
    let onHandoff: () -> Void
    let onVolumeChange: (Float) -> Void
    
    @State private var safeVolume = SafeVolumeManager.shared
    
    var body: some View {
        let volPercent = Int(remote.volume * 100)
        let safetyColor = safeVolume.safetyLevel(for: remote.volume).color
        
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ThemeManager.shared.accent.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: "laptopcomputer")
                        .font(.title3)
                        .foregroundStyle(ThemeManager.shared.accent)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(remote.name)
                        .font(AppFonts.headline)
                        .foregroundStyle(ThemeManager.shared.primaryText)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("Онлайн (Castlie Connect)")
                            .font(AppFonts.caption2)
                            .foregroundStyle(Color.green)
                    }
                }
                
                Spacer()
                
                Text("\(volPercent)%")
                    .font(AppFonts.subheadline)
                    .fontWeight(.bold)
                    .foregroundStyle(safetyColor)
            }
            
            // Живий повзунок гучності Mac у реальному часі
            HStack(spacing: 10) {
                Image(systemName: "speaker.fill")
                    .font(.caption2)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
                
                Slider(
                    value: Binding(
                        get: { remote.volume },
                        set: { onVolumeChange($0) }
                    ),
                    in: 0...1
                )
                .tint(safetyColor)
                
                Image(systemName: "speaker.wave.3.fill")
                    .font(.caption2)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
            }
            
            // Кнопка передачі звуку з Safe Handoff
            Button {
                onHandoff()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: remote.isPlaying ? "waveform" : "checkmark.shield.fill")
                    Text(remote.isPlaying ? "Грає на Mac (Змінити звук)" : "Безпечна передача (Safe Handoff)")
                }
                .font(AppFonts.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ThemeManager.shared.accent)
                )
            }
            .buttonStyle(.plain)
        }
        .cardStyle()
    }
}

// MARK: - Current Device Card (Цей пристрій)

struct CurrentDeviceCard: View {
    let device: AudioDevice
    var onConfigure: () -> Void = {}
    @State private var safeVolume = SafeVolumeManager.shared
    @State private var audioEngine = AudioEngine.shared
    
    var body: some View {
        let volPercent = Int(audioEngine.volume * 100)
        let safetyColor = safeVolume.safetyLevel(for: audioEngine.volume).color
        
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: device.type.sfSymbol)
                    .font(.title3)
                    .foregroundStyle(ThemeManager.shared.accent)
                    .frame(width: 40, height: 40)
                    .background(ThemeManager.shared.accent.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(AppFonts.headline)
                        .foregroundStyle(ThemeManager.shared.primaryText)
                    
                    Text("\(volPercent)% • Активний")
                        .font(AppFonts.caption)
                        .foregroundStyle(safetyColor)
                }
                
                Spacer()
            }
            
            VolumeSliderView()
        }
        .cardStyle()
    }
}

#Preview {
    DevicesView()
        .preferredColorScheme(.dark)
}
