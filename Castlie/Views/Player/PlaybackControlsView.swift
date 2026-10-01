import SwiftUI

struct PlaybackControlsView: View {
    @State private var audioEngine = AudioEngine.shared
    
    var body: some View {
        HStack(spacing: 40) {
            // Previous
            Button {
                audioEngine.playPrevious()
                HapticFeedbackService.light()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(ThemeManager.shared.primaryText)
            }
            
            // Play / Pause
            Button {
                audioEngine.togglePlayPause()
                HapticFeedbackService.medium()
            } label: {
                Image(systemName: audioEngine.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(ThemeManager.shared.primaryText)
            }
            
            // Next
            Button {
                audioEngine.playNext()
                HapticFeedbackService.light()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(ThemeManager.shared.primaryText)
            }
        }
    }
}

#Preview {
    PlaybackControlsView()
        .padding()
        .preferredColorScheme(.dark)
        .background(ThemeManager.shared.primaryBackground)
}
