import SwiftUI

struct VolumeSliderView: View {
    @State private var audioEngine = AudioEngine.shared
    @State private var safeVolume = SafeVolumeManager.shared
    @State private var isDragging = false
    @State private var lastLevel: SafeVolumeManager.SafetyLevel?
    
    var body: some View {
        HStack(spacing: 14) {
            // Іконка тихо (Apple Music стиль)
            Image(systemName: "speaker.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ThemeManager.shared.secondaryText)
                .frame(width: 20)
            
            // Інтерактивний Apple Music повзунок
            GeometryReader { geometry in
                let currentVolume = CGFloat(audioEngine.volume)
                let clamped = max(0, min(1, currentVolume))
                let sliderHeight: CGFloat = isDragging ? 8 : 6
                
                ZStack(alignment: .leading) {
                    // Фонова доріжка
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: sliderHeight)
                    
                    // Заповнена частина з кольором безпеки Safe Volume
                    Capsule()
                        .fill(safeVolume.safetyLevel(for: audioEngine.volume).color)
                        .frame(
                            width: geometry.size.width * clamped,
                            height: sliderHeight
                        )
                    
                    // Apple Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: isDragging ? 16 : 0, height: isDragging ? 16 : 0)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 1)
                        .offset(x: max(0, min(geometry.size.width - 16, geometry.size.width * clamped - 8)))
                }
                .frame(height: 16)
                .contentShape(Rectangle())
                .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isDragging)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                HapticFeedbackService.light()
                            }
                            let newVolume = Float(max(0, min(1, value.location.x / geometry.size.width)))
                            audioEngine.setVolume(newVolume)
                            
                            // Тактильний відгук при переході між безпечними та небезпечними рівнями
                            let currentLevel = safeVolume.safetyLevel(for: newVolume)
                            if let last = lastLevel, last != currentLevel {
                                HapticFeedbackService.medium()
                            }
                            lastLevel = currentLevel
                        }
                        .onEnded { _ in
                            isDragging = false
                            lastLevel = nil
                        }
                )
            }
            .frame(height: 16)
            
            // Іконка гучно
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ThemeManager.shared.secondaryText)
                .frame(width: 20)
        }
    }
}

#Preview {
    VolumeSliderView()
        .padding()
        .preferredColorScheme(.dark)
        .background(ThemeManager.shared.primaryBackground)
}
