import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Логотип
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 84, height: 84)
                            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .shadow(color: .black.opacity(0.3), radius: 10, y: 5)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        
                        Text("Castlie")
                            .font(AppFonts.largeTitle)
                            .foregroundStyle(ThemeManager.shared.primaryText)
                        
                        Text("Safe Volume Handoff")
                            .font(AppFonts.subheadline)
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
                
                // Опис
                VStack(alignment: .leading, spacing: 12) {
                    Text("Про проєкт")
                        .font(AppFonts.title2)
                        .foregroundStyle(ThemeManager.shared.primaryText)
                    
                    Text("Castlie — це музичний плеєр, створений на основі дослідження проблем взаємодії користувачів з системою Spotify Connect. Головна функція додатку — Safe Volume Handoff — забезпечує безпечне перемикання аудіо на зовнішні пристрої з попереднім контролем гучності.")
                        .font(AppFonts.body)
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                    
                    Text("Курс: Людино-машинна взаємодія")
                        .font(AppFonts.subheadline)
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                }
                
                // Ключові функції
                VStack(alignment: .leading, spacing: 12) {
                    Text("Ключові функції")
                        .font(AppFonts.title2)
                        .foregroundStyle(ThemeManager.shared.primaryText)
                    
                    FeatureRow(icon: "speaker.wave.2.fill", title: "Попередній перегляд гучності", description: "Бачте рівень гучності ДО підключення")
                    FeatureRow(icon: "waveform.path.ecg", title: "Fade-in", description: "Плавне наростання звуку")
                    FeatureRow(icon: "moon.fill", title: "Нічний режим", description: "Автоматичне обмеження ввечері")
                    FeatureRow(icon: "checkmark.shield.fill", title: "Діалог підтвердження", description: "Контроль перед підключенням")
                    FeatureRow(icon: "chart.bar.fill", title: "Максимальний поріг", description: "Захист від небезпечної гучності")
                    FeatureRow(icon: "clock.arrow.circlepath", title: "Історія пристроїв", description: "Запам'ятовує вподобаний рівень")
                }
            }
            .padding()
        }
        .background(ThemeManager.shared.primaryBackground.ignoresSafeArea())
        .navigationTitle("Про додаток")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(ThemeManager.shared.accent)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppFonts.headline)
                    .foregroundStyle(ThemeManager.shared.primaryText)
                Text(description)
                    .font(AppFonts.caption)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
            }
        }
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
    .preferredColorScheme(.dark)
}
