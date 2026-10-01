import SwiftUI

struct VolumeSliderView: View {
    @State private var audioEngine = AudioEngine.shared
    @State private var safeVolume = SafeVolumeManager.shared
    
    var body: some View {
        HStack(spacing: 12) {
            // Іконка тихо
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundStyle(ThemeManager.shared.secondaryText)
            
            // Повзунок
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Фон
                    Capsule()
                        .fill(ThemeManager.shared.cardBackground)
                        .frame(height: 6)
                    
                    // Заповнена частина з кольором безпеки
                    Capsule()
                        .fill(safeVolume.safetyLevel(for: audioEngine.volume).color)
                        .frame(
                            width: geometry.size.width * CGFloat(audioEngine.volume),
                            height: 6
                        )
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newVolume = Float(max(0, min(1, value.location.x / geometry.size.width)))
                            audioEngine.setVolume(newVolume)
                        }
                )
            }
            .frame(height: 6)
            
            // Іконка гучно
            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundStyle(ThemeManager.shared.secondaryText)
        }
    }
}

#Preview {
    VolumeSliderView()
        .padding()
        .preferredColorScheme(.dark)
        .background(ThemeManager.shared.primaryBackground)
}
