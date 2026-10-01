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
        VStack(spacing: 24) {
            // Заголовок
            VStack(spacing: 8) {
                Text("Безпечна гучність")
                    .font(AppFonts.subheadline)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
                
                HStack(spacing: 8) {
                    Image(systemName: device.type.sfSymbol)
                        .font(.title2)
                    Text(device.name)
                        .font(AppFonts.title2)
                }
                .foregroundStyle(ThemeManager.shared.primaryText)
            }
            
            Divider()
                .background(ThemeManager.shared.cardBackground)
            
            // Повзунок гучності (МОЖНА ЗМІНИТИ ДО ПІДКЛЮЧЕННЯ)
            VStack(spacing: 12) {
                Text("Гучність пристрою:")
                    .font(AppFonts.body)
                    .foregroundStyle(ThemeManager.shared.primaryText)
                
                // Значення
                Text("\(Int(adjustedVolume * 100))%")
                    .font(AppFonts.largeTitle)
                    .foregroundStyle(safety.color)
                
                // Повзунок
                Slider(
                    value: $adjustedVolume,
                    in: 0...1,
                    step: 0.01
                ) {
                    Text("Гучність")
                } minimumValueLabel: {
                    Image(systemName: "speaker.fill")
                        .font(.caption)
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                } maximumValueLabel: {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.caption)
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                }
                .tint(safety.color)
                
                // Індикатор безпеки
                SafetyIndicator(level: safety)
                
                if adjustedVolume > safeVolume.config.effectiveMaxVolume {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(Color(hex: "FF9500"))
                        Text("Вище рекомендованого порогу (\(Int(safeVolume.config.effectiveMaxVolume * 100))%)")
                            .font(AppFonts.caption2)
                            .foregroundStyle(Color(hex: "FF9500"))
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 10)
                    .background(Color(hex: "FF9500").opacity(0.12))
                    .clipShape(Capsule())
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ThemeManager.shared.cardBackground)
            )
            
            // Інфо
            VStack(spacing: 8) {
                if safeVolume.config.isFadeInEnabled {
                    InfoRow(
                        icon: "timer",
                        label: "Fade-in",
                        value: "\(String(format: "%.1f", safeVolume.config.fadeInDuration)) сек"
                    )
                }
                
                if safeVolume.config.isNightModeActive {
                    InfoRow(
                        icon: "moon.fill",
                        label: "Нічний режим",
                        value: "увімкнено"
                    )
                }
                
                InfoRow(
                    icon: "chart.bar.fill",
                    label: "Макс. поріг",
                    value: "\(Int(safeVolume.config.effectiveMaxVolume * 100))%"
                )
            }
            
            Spacer()
            
            // Кнопки
            VStack(spacing: 12) {
                GlowingButton(
                    title: "Зберегти рівень гучності",
                    icon: "checkmark.shield.fill",
                    color: safety.color,
                    isFullWidth: true,
                    action: onConfirm
                )
                
                Button("Скасувати") {
                    onCancel()
                }
                .font(AppFonts.body)
                .foregroundStyle(ThemeManager.shared.secondaryText)
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .background(ThemeManager.shared.primaryBackground.ignoresSafeArea())
        .onChange(of: adjustedVolume) { oldValue, newValue in
            let threshold = safeVolume.config.effectiveMaxVolume
            if oldValue <= threshold && newValue > threshold {
                HapticFeedbackService.warning()
            }
        }
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
