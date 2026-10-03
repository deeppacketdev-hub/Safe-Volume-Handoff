import SwiftUI

struct VolumeLimitSettings: View {
    @State private var safeVolume = SafeVolumeManager.shared

    private var safety: SafeVolumeManager.SafetyLevel {
        safeVolume.safetyLevel(for: safeVolume.config.maxVolumeThreshold)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Поріг гучності")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(ThemeManager.shared.primaryText)

                Spacer()

                Text("\(Int(safeVolume.config.maxVolumeThreshold * 100))%")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(safety.color)
            }

            Slider(
                value: $safeVolume.config.maxVolumeThreshold,
                in: 0.1...1.0,
                step: 0.05
            )
            .tint(safety.color)

            HStack(spacing: 6) {
                Circle()
                    .fill(safety.color)
                    .frame(width: 7, height: 7)

                Text(safety.label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(safety.color)

                Spacer()

                Text("Рекомендовано: до 70%")
                    .font(.system(size: 11))
                    .foregroundStyle(ThemeManager.shared.secondaryText.opacity(0.8))
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        Section("Ліміт гучності") {
            VolumeLimitSettings()
        }
    }
    .preferredColorScheme(.dark)
}
