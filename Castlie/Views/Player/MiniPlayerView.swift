import SwiftUI

struct MiniPlayerView: View {
    @Binding var showFullPlayer: Bool
    @State private var audioEngine = AudioEngine.shared
    
    var body: some View {
        if let track = audioEngine.currentTrack {
            HStack(spacing: 12) {
                // Обкладинка
                AsyncImage(url: track.albumImageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(ThemeManager.shared.cardBackground)
                        .overlay {
                            Image(systemName: "music.note")
                                .foregroundStyle(ThemeManager.shared.secondaryText)
                        }
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                
                // Назва та виконавець
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name)
                        .font(AppFonts.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(ThemeManager.shared.primaryText)
                        .lineLimit(1)
                    
                    Text(track.artistName)
                        .font(AppFonts.caption2)
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Анімована аудіохвиля
                AnimatedWaveform(isPlaying: audioEngine.isPlaying, color: ThemeManager.shared.accent, barCount: 4)
                    .padding(.trailing, 4)
                
                // Play / Pause
                Button {
                    audioEngine.togglePlayPause()
                    HapticFeedbackService.light()
                } label: {
                    Image(systemName: audioEngine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .foregroundStyle(ThemeManager.shared.primaryText)
                        .frame(width: 44, height: 44)
                }
                
                // Next
                Button {
                    audioEngine.playNext()
                    HapticFeedbackService.light()
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.body)
                        .foregroundStyle(ThemeManager.shared.primaryText)
                        .frame(width: 36, height: 44)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(ThemeManager.shared.secondaryBackground.opacity(0.8))
                    )
            )
            .padding(.horizontal, 8)
            .onTapGesture {
                showFullPlayer = true
                HapticFeedbackService.light()
            }
            // Прогрес-бар внизу міні-плеєра
            .overlay(alignment: .bottom) {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(ThemeManager.shared.accent)
                        .frame(
                            width: geometry.size.width * audioEngine.progress,
                            height: 2
                        )
                }
                .frame(height: 2)
                .clipShape(Capsule())
                .padding(.horizontal, 20)
            }
        }
    }
}

#Preview {
    ZStack {
        ThemeManager.shared.primaryBackground
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            MiniPlayerView(showFullPlayer: .constant(false))
        }
    }
    .preferredColorScheme(.dark)
}
