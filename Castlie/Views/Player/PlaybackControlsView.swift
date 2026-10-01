import SwiftUI

struct PlaybackControlsView: View {
    @State private var audioEngine = AudioEngine.shared
    
    var body: some View {
        HStack(spacing: 0) {
            // MARK: - 1. Shuffle
            Button {
                audioEngine.toggleShuffle()
                HapticFeedbackService.light()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        audioEngine.isShuffled
                        ? ThemeManager.shared.accent
                        : ThemeManager.shared.secondaryText.opacity(0.8)
                    )
                    .frame(width: 44, height: 44)
                    .background(
                        audioEngine.isShuffled
                        ? ThemeManager.shared.accent.opacity(0.16)
                        : Color.clear
                    )
                    .clipShape(Circle())
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: audioEngine.isShuffled)
            
            Spacer()
            
            // MARK: - 2. Previous
            Button {
                audioEngine.playPrevious()
                HapticFeedbackService.light()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(ThemeManager.shared.primaryText)
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
            
            // MARK: - 3. Play / Pause
            Button {
                audioEngine.togglePlayPause()
                HapticFeedbackService.medium()
            } label: {
                ZStack {
                    Circle()
                        .fill(ThemeManager.shared.primaryText)
                        .frame(width: 68, height: 68)
                        .shadow(color: .black.opacity(0.25), radius: 10, y: 5)
                    
                    Image(systemName: audioEngine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(ThemeManager.shared.primaryBackground)
                        .offset(x: audioEngine.isPlaying ? 0 : 2) // оптичне центрування для трикутника play
                }
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.92))
            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: audioEngine.isPlaying)
            
            Spacer()
            
            // MARK: - 4. Next
            Button {
                audioEngine.playNext()
                HapticFeedbackService.light()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(ThemeManager.shared.primaryText)
                    .frame(width: 52, height: 52)
            }
            .buttonStyle(ScaleButtonStyle())
            
            Spacer()
            
            // MARK: - 5. Repeat
            Button {
                audioEngine.toggleRepeat()
                HapticFeedbackService.light()
            } label: {
                Image(systemName: audioEngine.repeatMode.sfSymbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(
                        audioEngine.repeatMode != .off
                        ? ThemeManager.shared.accent
                        : ThemeManager.shared.secondaryText.opacity(0.8)
                    )
                    .frame(width: 44, height: 44)
                    .background(
                        audioEngine.repeatMode != .off
                        ? ThemeManager.shared.accent.opacity(0.16)
                        : Color.clear
                    )
                    .clipShape(Circle())
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: audioEngine.repeatMode)
        }
        .padding(.horizontal, 20)
    }
}

/// Плавна Apple-style анімація стискання кнопки при натисканні
struct ScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.90
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

#Preview {
    PlaybackControlsView()
        .padding()
        .preferredColorScheme(.dark)
        .background(ThemeManager.shared.primaryBackground)
}
