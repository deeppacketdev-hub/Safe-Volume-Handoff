import SwiftUI

struct PlaybackControlsView: View {
    @State private var audioEngine = AudioEngine.shared

    var body: some View {
        HStack(spacing: 0) {
            // MARK: - 1. Shuffle
            Button(action: toggleShuffle) {
                Image(systemName: "shuffle")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(
                        audioEngine.isShuffled
                        ? ThemeManager.shared.accent
                        : ThemeManager.shared.secondaryText.opacity(0.8)
                    )
                    .frame(width: 42, height: 42)
                    .background(
                        audioEngine.isShuffled
                        ? ThemeManager.shared.accent.opacity(0.16)
                        : Color.clear
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.90))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: audioEngine.isShuffled)

            Spacer()

            // MARK: - 2. Previous
            Button(action: playPrevious) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(ThemeManager.shared.primaryText)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.88))

            Spacer()

            // MARK: - 3. Play / Pause — Apple Music Hero Button
            Button(action: togglePlayPause) {
                ZStack {
                    Circle()
                        .fill(ThemeManager.shared.primaryText)
                        .frame(width: 64, height: 64)
                        .shadow(color: .black.opacity(0.22), radius: 8, y: 4)

                    Image(systemName: audioEngine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(ThemeManager.shared.primaryBackground)
                        .offset(x: audioEngine.isPlaying ? 0 : 2)
                }
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.92))
            .animation(.spring(response: 0.32, dampingFraction: 0.7), value: audioEngine.isPlaying)

            Spacer()

            // MARK: - 4. Next
            Button(action: playNext) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(ThemeManager.shared.primaryText)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.88))

            Spacer()

            // MARK: - 5. Repeat
            Button(action: toggleRepeat) {
                Image(systemName: audioEngine.repeatMode.sfSymbol)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(
                        audioEngine.repeatMode != .off
                        ? ThemeManager.shared.accent
                        : ThemeManager.shared.secondaryText.opacity(0.8)
                    )
                    .frame(width: 42, height: 42)
                    .background(
                        audioEngine.repeatMode != .off
                        ? ThemeManager.shared.accent.opacity(0.16)
                        : Color.clear
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.90))
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: audioEngine.repeatMode)
        }
        .padding(.horizontal, 20)
    }

    // MARK: - Actions

    private func toggleShuffle() {
        audioEngine.toggleShuffle()
        HapticFeedbackService.light()
    }

    private func playPrevious() {
        audioEngine.playPrevious()
        HapticFeedbackService.light()
    }

    private func togglePlayPause() {
        audioEngine.togglePlayPause()
        HapticFeedbackService.medium()
    }

    private func playNext() {
        audioEngine.playNext()
        HapticFeedbackService.light()
    }

    private func toggleRepeat() {
        audioEngine.toggleRepeat()
        HapticFeedbackService.light()
    }
}

/// Плавна Apple-style анімація стискання кнопки при натисканні
struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.90

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

#Preview {
    PlaybackControlsView()
        .padding()
        .preferredColorScheme(.dark)
        .background(ThemeManager.shared.primaryBackground)
}
