import SwiftUI

struct NightModeSettings: View {
    @State private var safeVolume = SafeVolumeManager.shared
    
    var body: some View {
        Toggle("Увімкнути нічний режим", isOn: $safeVolume.config.isNightModeEnabled)
            .tint(ThemeManager.shared.accent)
        
        if safeVolume.config.isNightModeEnabled {
            // Час початку
            HStack {
                Image(systemName: "sunset.fill")
                    .foregroundStyle(ThemeManager.shared.accent)
                Text("Початок")
                Spacer()
                Picker("", selection: $safeVolume.config.nightModeStartHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text("\(hour):00").tag(hour)
                    }
                }
                .pickerStyle(.menu)
                .tint(ThemeManager.shared.accent)
            }
            
            // Час кінця
            HStack {
                Image(systemName: "sunrise.fill")
                    .foregroundStyle(ThemeManager.shared.accent)
                Text("Кінець")
                Spacer()
                Picker("", selection: $safeVolume.config.nightModeEndHour) {
                    ForEach(0..<24, id: \.self) { hour in
                        Text("\(hour):00").tag(hour)
                    }
                }
                .pickerStyle(.menu)
                .tint(ThemeManager.shared.accent)
            }
            
            // Макс. гучність у нічному режимі
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Макс. гучність вночі")
                    Spacer()
                    Text("\(Int(safeVolume.config.nightModeMaxVolume * 100))%")
                        .foregroundStyle(ThemeManager.shared.accent)
                }
                
                Slider(
                    value: $safeVolume.config.nightModeMaxVolume,
                    in: 0.1...1.0,
                    step: 0.05
                )
                .tint(ThemeManager.shared.accent)
                
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
            
            // Статус
            HStack {
                Image(systemName: safeVolume.config.isNightModeActive ? "moon.fill" : "sun.max.fill")
                    .foregroundStyle(
                        safeVolume.config.isNightModeActive
                        ? ThemeManager.shared.accent
                        : ThemeManager.shared.secondaryText
                    )
                Text(safeVolume.config.isNightModeActive ? "Зараз активний" : "Зараз неактивний")
                    .font(AppFonts.caption)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
            }
        }
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
