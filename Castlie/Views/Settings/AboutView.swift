import SwiftUI

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image("AppLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.35), radius: 12, y: 6)
                        .accessibilityHidden(true)
                    Text("Castlie")
                        .font(.largeTitle.weight(.bold))
                    Text("Safe Volume Handoff")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Версія 1.0")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }

            Section {
                Text("Музичний плеєр, створений на основі дослідження проблем Spotify Connect. Головна функція — Safe Volume Handoff: безпечне перемикання звуку на інші пристрої з вибором гучності заздалегідь.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } header: {
                Text("Про проєкт")
            } footer: {
                Text("Курс «Людино-машинна взаємодія»")
            }

            Section("Як це працює") {
                FeatureRow(symbol: "slider.horizontal.3", color: Theme.accent, title: "Гучність до підключення", text: "Обираєте рівень ще до того, як звук піде на пристрій")
                FeatureRow(symbol: "waveform.path", color: .teal, title: "Плавне наростання", text: "Звук стартує з тиші й поступово досягає вибраного рівня")
                FeatureRow(symbol: "clock.arrow.circlepath", color: .blue, title: "Пам'ять пристроїв", text: "Кожен пристрій отримує свою збережену гучність")
                FeatureRow(symbol: "shield.lefthalf.filled", color: .green, title: "Без раптових сюрпризів", text: "Автоматично — не вище жовтої зони; навушники мають суворіші межі")
                FeatureRow(symbol: "moon.fill", color: Theme.night, title: "Нічний ліміт", text: "Жорстке обмеження гучності в нічні години")
                FeatureRow(symbol: "pause.circle.fill", color: .orange, title: "Пауза при відключенні", text: "Якщо навушники чи Mac зникли — музика не заграє з динаміка")
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Про додаток")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FeatureRow: View {
    let symbol: String
    let color: Color
    let title: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .background(color.gradient, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                Text(text)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack { AboutView() }
        .preferredColorScheme(.dark)
}
