import SwiftUI

struct HandoffConfirmSheet: View {
    let device: AudioDevice
    @Binding var adjustedVolume: Float
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var safeVolume = SafeVolumeManager.shared
    
    private var safety: SafeVolumeManager.SafetyLevel {
        safeVolume.safetyLevel(for: adjustedVolume)
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            VStack(spacing: 6) {
                Capsule()
                    .fill(Color.white.opacity(0.24))
                    .frame(width: 36, height: 4)
                    .padding(.top, 4)
                    .padding(.bottom, 8)

                HStack(spacing: 10) {
                    Image(systemName: device.type.sfSymbol)
                        .font(.title3)
                        .foregroundStyle(ThemeManager.shared.accent)
                        .frame(width: 38, height: 38)
                        .background(ThemeManager.shared.accent.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(device.name)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(ThemeManager.shared.primaryText)
                            .lineLimit(1)

                        Text("Безпечна гучність перед підключенням")
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                    }

                    Spacer()
                }
            }

            // Volume Control Card
            VStack(spacing: 16) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Рівень виводу")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(ThemeManager.shared.secondaryText)

                    Spacer()

                    Text("\(Int(adjustedVolume * 100))%")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(safety.color)
                }

                Slider(
                    value: $adjustedVolume,
                    in: 0...1,
                    step: 0.01
                ) {
                    Text("Гучність")
                } minimumValueLabel: {
                    Image(systemName: "speaker.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                } maximumValueLabel: {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                }
                .tint(safety.color)

                SafetyIndicator(level: safety)

                if adjustedVolume > safeVolume.config.effectiveMaxVolume {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "FF9500"))
                        Text("Вище ліміту (\(Int(safeVolume.config.effectiveMaxVolume * 100))%)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color(hex: "FF9500"))
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 12)
                    .background(Color(hex: "FF9500").opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            .padding(16)
            .background(ThemeManager.shared.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            // Safe Volume Meta Badges
            HStack(spacing: 8) {
                if safeVolume.config.isFadeInEnabled {
                    ConfigBadge(
                        icon: "waveform.path",
                        title: "Fade-in \(String(format: "%.1f", safeVolume.config.fadeInDuration))с"
                    )
                }

                if safeVolume.config.isNightModeActive {
                    ConfigBadge(
                        icon: "moon.fill",
                        title: "Нічний ліміт"
                    )
                }

                ConfigBadge(
                    icon: "shield.fill",
                    title: "Поріг \(Int(safeVolume.config.effectiveMaxVolume * 100))%"
                )
            }

            Spacer(minLength: 8)

            // Actions
            VStack(spacing: 10) {
                Button {
                    onConfirm()
                    HapticFeedbackService.medium()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Підключити з цією гучністю")
                    }
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(safety.color)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Button("Скасувати") {
                    onCancel()
                    HapticFeedbackService.light()
                }
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(ThemeManager.shared.secondaryText)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
        .background(ThemeManager.shared.primaryBackground.ignoresSafeArea())
        .onChange(of: adjustedVolume) { oldValue, newValue in
            let threshold = safeVolume.config.effectiveMaxVolume
            if oldValue <= threshold && newValue > threshold {
                HapticFeedbackService.warning()
            }
        }
    }
}

// MARK: - Config Badge

private struct ConfigBadge: View {
    let icon: String
    let title: String

    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(ThemeManager.shared.secondaryText)
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(ThemeManager.shared.secondaryText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(ThemeManager.shared.cardBackground)
        .clipShape(Capsule())
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(ThemeManager.shared.secondaryText)
                .frame(width: 20)
            
            Text(label)
                .font(AppFonts.subheadline)
                .foregroundStyle(ThemeManager.shared.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(AppFonts.subheadline)
                .foregroundStyle(ThemeManager.shared.primaryText)
        }
    }
}

#Preview {
    HandoffConfirmSheet(
        device: AudioDevice(
            id: "1", name: "JBL Flip 6", type: .speaker,
            connectionType: .bluetooth, roomName: "Кімната",
            lastKnownVolume: 0.35
        ),
        adjustedVolume: .constant(0.35),
        onConfirm: {},
        onCancel: {}
    )
    .preferredColorScheme(.dark)
}
