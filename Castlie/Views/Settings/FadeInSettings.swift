import SwiftUI

struct FadeInSettings: View {
    @State private var safeVolume = SafeVolumeManager.shared

    var body: some View {
        VStack(spacing: 12) {
            Toggle(isOn: $safeVolume.config.isFadeInEnabled.animation(.spring(response: 0.35, dampingFraction: 0.8))) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Плавне наростання")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundStyle(ThemeManager.shared.primaryText)
                    Text("Захищає вуха від раптового гучного звуку")
                        .font(.system(size: 12))
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                }
            }
            .tint(ThemeManager.shared.accent)

            if safeVolume.config.isFadeInEnabled {
                Divider()
                    .padding(.vertical, 2)

                VStack(spacing: 8) {
                    HStack {
                        Text("Тривалість наростання")
                            .font(.system(size: 14))
                            .foregroundStyle(ThemeManager.shared.secondaryText)

                        Spacer()

                        Text("\(String(format: "%.1f", safeVolume.config.fadeInDuration)) с")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(ThemeManager.shared.accent)
                    }

                    Slider(
                        value: $safeVolume.config.fadeInDuration,
                        in: 0.5...5.0,
                        step: 0.5
                    )
                    .tint(ThemeManager.shared.accent)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    List {
        Section("Плавний старт") {
            FadeInSettings()
        }
    }
    .preferredColorScheme(.dark)
}
