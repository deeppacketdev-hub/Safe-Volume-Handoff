import SwiftUI

struct VolumeLimitSettings: View {
    @State private var safeVolume = SafeVolumeManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Максимальний поріг")
                Spacer()
                Text("\(Int(safeVolume.config.maxVolumeThreshold * 100))%")
                    .foregroundStyle(
                        safeVolume.safetyLevel(for: safeVolume.config.maxVolumeThreshold).color
                    )
            }
            
            Slider(
                value: $safeVolume.config.maxVolumeThreshold,
                in: 0.1...1.0,
                step: 0.05
            )
            .tint(safeVolume.safetyLevel(for: safeVolume.config.maxVolumeThreshold).color)
            
            HStack {
                Text("10%")
                    .font(AppFonts.caption2)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
                Spacer()
                Text("100%")
                    .font(AppFonts.caption2)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
            }
        }
        
        // Безпека індикатор
        SafetyIndicator(level: safeVolume.safetyLevel(for: safeVolume.config.maxVolumeThreshold))
        
        Text("При підключенні до нового пристрою гучність не перевищить цей рівень, навіть якщо попередня гучність пристрою була вищою")
            .font(AppFonts.caption)
            .foregroundStyle(ThemeManager.shared.secondaryText)
    }
}

#Preview {
    List {
        Section("Обмеження гучності") {
            VolumeLimitSettings()
        }
    }
    .preferredColorScheme(.dark)
}
