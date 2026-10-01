import SwiftUI

struct DevicesView: View {
    @State private var viewModel = DeviceManagerViewModel()
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Поточний пристрій
                    if let current = viewModel.discovery.currentDevice {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Поточний пристрій")
                                .font(AppFonts.caption)
                                .foregroundStyle(ThemeManager.shared.secondaryText)
                                .padding(.horizontal)
                            
                            CurrentDeviceCard(device: current)
                                .padding(.horizontal)
                        }
                    }
                    
                    Divider()
                        .background(ThemeManager.shared.cardBackground)
                        .padding(.horizontal)
                    
                    // AirPlay швидке підключення
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("AirPlay трансляція")
                                .font(AppFonts.headline)
                                .foregroundStyle(ThemeManager.shared.primaryText)
                            Text(viewModel.discovery.isAirPlayAvailable ? "Знайдено доступні маршрути в мережі" : "Передавайте звук на сумісні аудіосистеми")
                                .font(AppFonts.caption)
                                .foregroundStyle(ThemeManager.shared.secondaryText)
                        }
                        
                        Spacer()
                        
                        AirPlayPickerButton()
                            .frame(width: 44, height: 44)
                    }
                    .cardStyle()
                    .padding(.horizontal)
                    
                    // Збережені пристрої
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Збережені пристрої")
                            .font(AppFonts.caption)
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                            .padding(.horizontal)
                        
                        let knownDevices = viewModel.discovery.knownDevices
                        
                        if knownDevices.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "headphones")
                                    .font(.system(size: 36))
                                    .foregroundStyle(ThemeManager.shared.accent)
                                
                                Text("Немає збережених пристроїв")
                                    .font(AppFonts.headline)
                                    .foregroundStyle(ThemeManager.shared.primaryText)
                                
                                Text("Підключіть Bluetooth-навушники, колонку або AirPlay. Safe Volume автоматично захистить ваш слух та запам'ятає пристрій.")
                                    .font(AppFonts.caption)
                                    .foregroundStyle(ThemeManager.shared.secondaryText)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 24)
                            }
                            .padding(.vertical, 32)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(ThemeManager.shared.cardBackground)
                            )
                            .padding(.horizontal)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(knownDevices) { device in
                                    DeviceCardView(device: device) {
                                        viewModel.initiateHandoff(to: device)
                                    }
                                    .padding(.horizontal)
                                }
                            }
                        }
                    }
                    
                    // Night Mode статус
                    NightModeStatusBar()
                        .padding(.horizontal)
                        .padding(.top, 8)
                }
                .padding(.vertical)
            }
            .background(ThemeManager.shared.primaryBackground.ignoresSafeArea())
            .navigationTitle("Пристрої")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    AirPlayPickerButton()
                        .frame(width: 44, height: 44)
                }
            }
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
        }
    }
}

// MARK: - Current Device Card

struct CurrentDeviceCard: View {
    let device: AudioDevice
    @State private var safeVolume = SafeVolumeManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: device.type.sfSymbol)
                .font(.title2)
                .foregroundStyle(ThemeManager.shared.accent)
                .frame(width: 44, height: 44)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(device.name)
                    .font(AppFonts.headline)
                    .foregroundStyle(ThemeManager.shared.primaryText)
                
                HStack(spacing: 4) {
                    Text(device.connectionType.rawValue)
                    if let room = device.roomName {
                        Text("·")
                        Text(room)
                    }
                    if let vol = device.lastKnownVolume ?? safeVolume.lastKnownVolume(for: device.id) {
                        Text("·")
                        Text("\(Int(vol * 100))%")
                    }
                }
                .font(AppFonts.caption)
                .foregroundStyle(ThemeManager.shared.secondaryText)
            }
            
            Spacer()
            
            // Індикатор активного підключення
            Circle()
                .fill(ThemeManager.shared.safeColor)
                .frame(width: 8, height: 8)
        }
        .cardStyle()
    }
}

// MARK: - Night Mode Status

struct NightModeStatusBar: View {
    @State private var safeVolume = SafeVolumeManager.shared
    
    var body: some View {
        HStack(spacing: 16) {
            // Night Mode
            HStack(spacing: 6) {
                Image(systemName: "moon.fill")
                    .font(.caption)
                    .foregroundStyle(
                        safeVolume.config.isNightModeActive
                        ? ThemeManager.shared.accent
                        : ThemeManager.shared.secondaryText
                    )
                Text("Нічний: \(safeVolume.config.isNightModeActive ? "УВІМК" : "ВИМК")")
                    .font(AppFonts.caption)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
            }
            
            Spacer()
            
            // Max Threshold
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.caption)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
                Text("Макс: \(Int(safeVolume.config.effectiveMaxVolume * 100))%")
                    .font(AppFonts.caption)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(ThemeManager.shared.secondaryBackground)
        )
    }
}

#Preview {
    DevicesView()
        .preferredColorScheme(.dark)
}
