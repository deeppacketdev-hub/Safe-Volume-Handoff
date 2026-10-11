import SwiftUI

struct SpotifyTrackRow: View {
    let track: Track
    let onTap: () -> Void
    
    @State private var audioEngine = AudioEngine.shared
    
    @State private var playlistManager = PlaylistManager.shared
    
    /// Чи цей трек зараз грає
    private var isCurrentlyPlaying: Bool {
        audioEngine.currentTrack?.id == track.id && audioEngine.isPlaying
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Обкладинка (маленька) — Color.clear guarantees exact 48×48 layout
                Color.clear
                    .frame(width: 48, height: 48)
                    .overlay {
                        AsyncImage(url: track.albumImageURL) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(ThemeManager.shared.cardBackground)
                                .overlay {
                                    Image(systemName: "music.note")
                                        .font(.caption)
                                        .foregroundStyle(ThemeManager.shared.secondaryText)
                                }
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                // Інформація
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.name)
                        .font(AppFonts.body)
                        .foregroundStyle(
                            isCurrentlyPlaying
                            ? ThemeManager.shared.accent
                            : ThemeManager.shared.primaryText
                        )
                        .lineLimit(1)
                    
                    Text(track.artistName)
                        .font(AppFonts.caption)
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Якщо вподобаний
                if playlistManager.isLiked(track: track) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(ThemeManager.shared.accent)
                }
                
                // Тривалість
                Text(track.formattedDuration)
                    .font(AppFonts.caption)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
                
                // Індикатор "зараз грає"
                if isCurrentlyPlaying {
                    AnimatedWaveform(isPlaying: true, color: ThemeManager.shared.accent, barCount: 3)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                playlistManager.toggleLike(track: track)
            } label: {
                Label(
                    playlistManager.isLiked(track: track) ? "Видалити з улюблених" : "Додати в улюблені",
                    systemImage: playlistManager.isLiked(track: track) ? "heart.slash" : "heart"
                )
            }
            
            if !playlistManager.playlists.isEmpty {
                Menu {
                    ForEach(playlistManager.playlists) { playlist in
                        Button {
                            playlistManager.addTrack(track, to: playlist.id)
                        } label: {
                            Text(playlist.name)
                        }
                    }
                } label: {
                    Label("Додати до плейлиста", systemImage: "plus.rectangle.on.rectangle")
                }
            }
        }
    }
}

#Preview {
    SpotifyTrackRow(
        track: Track(
            id: "preview",
            name: "Bohemian Rhapsody",
            artistName: "Queen",
            albumName: "A Night at the Opera",
            albumImageURL: nil,
            previewURL: nil,
            durationMs: 354000,
            popularity: 95
        ),
        onTap: {}
    )
    .preferredColorScheme(.dark)
    .background(ThemeManager.shared.primaryBackground)
}
