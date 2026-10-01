import SwiftUI

struct ProgressBarView: View {
    @State private var audioEngine = AudioEngine.shared
    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    
    var body: some View {
        VStack(spacing: 8) {
            // Прогрес-бар
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Фонова смужка
                    Capsule()
                        .fill(ThemeManager.shared.cardBackground)
                        .frame(height: 4)
                    
                    // Заповнена частина
                    Capsule()
                        .fill(ThemeManager.shared.accent)
                        .frame(
                            width: geometry.size.width * (isDragging ? dragProgress : audioEngine.progress),
                            height: 4
                        )
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDragging = true
                            dragProgress = max(0, min(1, value.location.x / geometry.size.width))
                        }
                        .onEnded { value in
                            let progress = max(0, min(1, value.location.x / geometry.size.width))
                            audioEngine.seek(to: audioEngine.duration * progress)
                            isDragging = false
                        }
                )
            }
            .frame(height: 4)
            
            // Час
            HStack {
                Text(audioEngine.formattedTime.components(separatedBy: " / ").first ?? "0:00")
                    .font(AppFonts.caption2)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
                
                Spacer()
                
                Text(audioEngine.formattedTime.components(separatedBy: " / ").last ?? "0:00")
                    .font(AppFonts.caption2)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
            }
        }
    }
}

#Preview {
    ProgressBarView()
        .padding()
        .preferredColorScheme(.dark)
        .background(ThemeManager.shared.primaryBackground)
}
