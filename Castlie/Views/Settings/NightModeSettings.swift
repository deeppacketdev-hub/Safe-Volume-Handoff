import SwiftUI

struct NightModeSettings: View {
    @State private var safeVolume = SafeVolumeManager.shared

    var body: some View {
        VStack(spacing: 12) {
            Toggle(isOn: $safeVolume.config.isNightModeEnabled.animation(.spring(response: 0.35, dampingFraction: 0.8))) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Нічний режим")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(ThemeManager.shared.primaryText)

                    if safeVolume.config.isNightModeActive {
                        HStack(spacing: 5) {
                            Circle()
                                .fill(Color(hex: "5856D6"))
                                .frame(width: 6, height: 6)
                            Text("Активний зараз")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Color(hex: "5856D6"))
                        }
                    }
                }
            }
            .tint(ThemeManager.shared.accent)

            if safeVolume.config.isNightModeEnabled {
                Divider()
                    .padding(.vertical, 2)

                // Schedule: Start & End hours
                HStack(spacing: 16) {
                    // Start
                    HStack(spacing: 8) {
                        Image(systemName: "sunset.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                        Text("З")
                            .font(.system(size: 14))
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                        Spacer()
                        Picker("", selection: $safeVolume.config.nightModeStartHour) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(String(format: "%02d:00", hour)).tag(hour)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(ThemeManager.shared.accent)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(ThemeManager.shared.cardBackground.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    // End
                    HStack(spacing: 8) {
                        Image(systemName: "sunrise.fill")
                            .font(.system(size: 13))
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                        Text("До")
                            .font(.system(size: 14))
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                        Spacer()
                        Picker("", selection: $safeVolume.config.nightModeEndHour) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text(String(format: "%02d:00", hour)).tag(hour)
                            }
                        }
                        .pickerStyle(.menu)
                        .tint(ThemeManager.shared.accent)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(ThemeManager.shared.cardBackground.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                // Night Volume Limit Slider
                VStack(spacing: 8) {
                    HStack {
                        Text("Макс. гучність уночі")
                            .font(.system(size: 14))
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                        Spacer()
                        Text("\(Int(safeVolume.config.nightModeMaxVolume * 100))%")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(ThemeManager.shared.accent)
                    }

                    Slider(
                        value: $safeVolume.config.nightModeMaxVolume,
                        in: 0.1...1.0,
                        step: 0.05
                    )
                    .tint(ThemeManager.shared.accent)
                }
                .padding(.top, 4)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        Section("Нічний режим") {
            NightModeSettings()
        }
    }
    .preferredColorScheme(.dark)
}
