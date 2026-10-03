import SwiftUI

struct VolumeSliderView: View {
    @State private var audioEngine = AudioEngine.shared
    @State private var safeVolume = SafeVolumeManager.shared
    @State private var isDragging = false
    @State private var localVolume: Float = 0.5
    @State private var lastLevel: SafeVolumeManager.SafetyLevel?

    private var currentDisplayVolume: CGFloat {
        CGFloat(max(0, min(1, isDragging ? localVolume : audioEngine.volume)))
    }

    var body: some View {
        HStack(spacing: 14) {
            // Speaker low icon
            Image(systemName: "speaker.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ThemeManager.shared.secondaryText)
                .frame(width: 20)

            // High-Performance Apple Music Volume Track
            GeometryReader { geometry in
                let width = max(1, geometry.size.width)
                let clamped = currentDisplayVolume
                let barHeight: CGFloat = isDragging ? 8 : 6
                let thumbDiameter: CGFloat = isDragging ? 18 : 10

                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: barHeight)

                    // Filled active track with Safe Volume safety color
                    Capsule()
                        .fill(safeVolume.safetyLevel(for: isDragging ? localVolume : audioEngine.volume).color)
                        .frame(width: width * clamped, height: barHeight)

                    // Apple Thumb: perfectly centered and clamped within bounds
                    Circle()
                        .fill(Color.white)
                        .frame(width: thumbDiameter, height: thumbDiameter)
                        .shadow(color: .black.opacity(isDragging ? 0.35 : 0.15), radius: isDragging ? 4 : 2, y: 1)
                        .offset(x: clamped * (width - thumbDiameter))
                }
                .frame(width: width, height: 44, alignment: .center)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                localVolume = audioEngine.volume
                                HapticFeedbackService.light()
                            }
                            let newVol = Float(max(0.0, min(1.0, value.location.x / width)))
                            localVolume = newVol
                            audioEngine.setVolume(newVol)

                            // Haptic tick when crossing safety threshold
                            let currentLevel = safeVolume.safetyLevel(for: newVol)
                            if let last = lastLevel, last != currentLevel {
                                HapticFeedbackService.medium()
                            }
                            lastLevel = currentLevel
                        }
                        .onEnded { _ in
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                                isDragging = false
                            }
                            lastLevel = nil
                        }
                )
            }
            .frame(height: 44)

            // Speaker high icon
            Image(systemName: "speaker.wave.3.fill")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(ThemeManager.shared.secondaryText)
                .frame(width: 20)
        }
        .onAppear {
            localVolume = audioEngine.volume
        }
    }
}

#Preview {
    VolumeSliderView()
        .padding()
        .preferredColorScheme(.dark)
        .background(ThemeManager.shared.primaryBackground)
}
