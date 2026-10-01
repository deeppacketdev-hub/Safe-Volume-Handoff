import SwiftUI

struct ProgressBarView: View {
    @State private var audioEngine = AudioEngine.shared
    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    @State private var showRemainingTime = true
    
    var body: some View {
        VStack(spacing: 8) {
            // MARK: - Інтерактивний Apple Music Scrubber
            GeometryReader { geometry in
                let currentProgress = isDragging ? dragProgress : audioEngine.progress
                let clampedProgress = max(0, min(1, currentProgress))
                let barHeight: CGFloat = isDragging ? 7 : 4
                
                ZStack(alignment: .leading) {
                    // Фонова доріжка
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: barHeight)
                    
                    // Заповнена частина
                    Capsule()
                        .fill(ThemeManager.shared.accent)
                        .frame(
                            width: geometry.size.width * clampedProgress,
                            height: barHeight
                        )
                    
                    // Apple Scrubber Thumb (з'являється та плавно збільшується при перетягуванні)
                    Circle()
                        .fill(Color.white)
                        .frame(width: isDragging ? 14 : 0, height: isDragging ? 14 : 0)
                        .shadow(color: .black.opacity(0.3), radius: 4, y: 1)
                        .offset(x: max(0, min(geometry.size.width - 14, geometry.size.width * clampedProgress - 7)))
                }
                .frame(height: 14)
                .contentShape(Rectangle())
                .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isDragging)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                HapticFeedbackService.light()
                            }
                            dragProgress = max(0, min(1, value.location.x / geometry.size.width))
                        }
                        .onEnded { value in
                            let progress = max(0, min(1, value.location.x / geometry.size.width))
                            audioEngine.seek(to: audioEngine.duration * progress)
                            isDragging = false
                            HapticFeedbackService.light()
                        }
                )
            }
            .frame(height: 14)
            
            // MARK: - Час (Пройдений час зліва, Залишок зі знаком мінус справа у стилі Apple)
            HStack {
                Text(elapsedTimeText)
                    .font(AppFonts.caption2.monospacedDigit())
                    .fontWeight(.medium)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
                
                Spacer()
                
                // Натискання перемикає між залишком часу (-0:15) та повною тривалістю (0:30)
                Button {
                    showRemainingTime.toggle()
                    HapticFeedbackService.light()
                } label: {
                    Text(rightTimeText)
                        .font(AppFonts.caption2.monospacedDigit())
                        .fontWeight(.medium)
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var currentPositionSeconds: Double {
        if isDragging {
            return audioEngine.duration * dragProgress
        }
        return audioEngine.currentTime
    }
    
    private var elapsedTimeText: String {
        formatTime(currentPositionSeconds)
    }
    
    private var rightTimeText: String {
        if showRemainingTime {
            let remaining = max(0, audioEngine.duration - currentPositionSeconds)
            return "-\(formatTime(remaining))"
        } else {
            return formatTime(audioEngine.duration)
        }
    }
    
    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN && seconds >= 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    ProgressBarView()
        .padding()
        .preferredColorScheme(.dark)
        .background(ThemeManager.shared.primaryBackground)
}
