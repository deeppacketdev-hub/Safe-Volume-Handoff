import SwiftUI

struct FadeInSettings: View {
    @State private var safeVolume = SafeVolumeManager.shared
    
    var body: some View {
        Toggle("Увімкнути fade-in", isOn: $safeVolume.config.isFadeInEnabled)
            .tint(ThemeManager.shared.accent)
        
        if safeVolume.config.isFadeInEnabled {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Тривалість")
                    Spacer()
                    Text("\(String(format: "%.1f", safeVolume.config.fadeInDuration)) сек")
                        .foregroundStyle(ThemeManager.shared.accent)
                }
                
                Slider(
                    value: $safeVolume.config.fadeInDuration,
                    in: 0.5...5.0,
                    step: 0.5
                )
                .tint(ThemeManager.shared.accent)
                
                HStack {
                    Text("0.5с")
                        .font(AppFonts.caption2)
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                    Spacer()
                    Text("5.0с")
                        .font(AppFonts.caption2)
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                }
            }
            
            // Пояснення
            Text("Звук плавно наростатиме від 0% до обраного рівня за вказаний час при кожному підключенні до нового пристрою")
                .font(AppFonts.caption)
                .foregroundStyle(ThemeManager.shared.secondaryText)
        }
    }
}

#Preview {
    List {
        Section("Fade-in") {
            FadeInSettings()
        }
    }
    .preferredColorScheme(.dark)
}
