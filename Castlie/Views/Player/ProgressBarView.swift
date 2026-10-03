import SwiftUI

struct ProgressBarView: View {
    @State private var audioEngine = AudioEngine.shared
    @State private var isDragging = false
    @State private var dragProgress: Double = 0
    @State private var showRemainingTime = true

    // Display progress: local drag value during drag, engine value when idle
    private var displayProgress: Double {
        isDragging ? dragProgress : audioEngine.progress
    }

    var body: some View {
        VStack(spacing: 8) {
            // MARK: - Інтерактивний Apple Music Scrubber
            GeometryReader { geometry in
                let width = max(1, geometry.size.width)
                let clampedProgress = max(0, min(1, displayProgress))
                let barHeight: CGFloat = isDragging ? 7 : 4
                let thumbDiameter: CGFloat = isDragging ? 16 : 8

                ZStack(alignment: .leading) {
                    // Фонова доріжка
                    Capsule()
                        .fill(Color.white.opacity(0.18))
                        .frame(height: barHeight)

                    // Заповнена частина
                    Capsule()
                        .fill(ThemeManager.shared.accent)
                        .frame(
                            width: width * clampedProgress,
                            height: barHeight
                        )

                    // Apple Scrubber Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: thumbDiameter, height: thumbDiameter)
                        .shadow(color: .black.opacity(isDragging ? 0.35 : 0.15), radius: isDragging ? 4 : 2, y: 1)
                        .offset(x: clampedProgress * (width - thumbDiameter))
                }
                .frame(width: width, height: 44, alignment: .center)
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0, coordinateSpace: .local)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                dragProgress = audioEngine.progress
                                HapticFeedbackService.light()
                            }
                            dragProgress = max(0, min(1, Double(value.location.x / width)))
                        }
                        .onEnded { value in
                            let progress = max(0, min(1, Double(value.location.x / width)))
                            audioEngine.seek(to: audioEngine.duration * progress)
                            withAnimation(.spring(response: 0.22, dampingFraction: 0.8)) {
                                isDragging = false
                            }
                            HapticFeedbackService.light()
                        }
                )
            }
            .frame(height: 44)

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
