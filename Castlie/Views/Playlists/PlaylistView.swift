import SwiftUI

struct PlaylistView: View {
    let title: String
    let subtitle: String?
    let icon: String
    let tracks: [Track]
    var playlistId: UUID? = nil
    
    @State private var audioEngine = AudioEngine.shared
    @State private var playlistManager = PlaylistManager.shared
    
    var currentTracks: [Track] {
        if let id = playlistId {
            return playlistManager.playlists.first(where: { $0.id == id })?.tracks ?? tracks
        }
        return tracks
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [ThemeManager.shared.accent, Color(hex: "8E2DE2")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 90, height: 90)
                        .overlay {
                            Image(systemName: icon)
                                .font(.system(size: 40))
                                .foregroundStyle(.white)
                        }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(AppFonts.title2)
                            .foregroundStyle(ThemeManager.shared.primaryText)
                        
                        if let sub = subtitle {
                            Text(sub)
                                .font(AppFonts.caption)
                                .foregroundStyle(ThemeManager.shared.secondaryText)
                        }
                        
                        Text("\(currentTracks.count) треків")
                            .font(AppFonts.caption)
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Play All Button
                if !currentTracks.isEmpty {
                    HStack {
                        GlowingButton(
                            title: "Відтворити все",
                            icon: "play.fill",
                            color: ThemeManager.shared.accent,
                            isFullWidth: true
                        ) {
                            audioEngine.play(tracks: currentTracks, startIndex: 0)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Tracks List
                if currentTracks.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 44))
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                        
                        Text("Плейлист порожній")
                            .font(AppFonts.headline)
                            .foregroundStyle(ThemeManager.shared.primaryText)
                        
                        Text("Додавайте треки за допомогою сердечка під час прослуховування або пошуку")
                            .font(AppFonts.caption)
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .cardStyle()
                    .padding(.horizontal)
                } else {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(currentTracks.enumerated()), id: \.element.id) { index, track in
                            SpotifyTrackRow(track: track) {
                                audioEngine.play(tracks: currentTracks, startIndex: index)
                            }
                            .contextMenu {
                                if let pId = playlistId {
                                    Button(role: .destructive) {
                                        playlistManager.removeTrack(trackId: track.id, from: pId)
                                    } label: {
                                        Label("Видалити з плейлиста", systemImage: "trash")
                                    }
                                }
                                
                                Button {
                                    playlistManager.toggleLike(track: track)
                                } label: {
                                    Label(
                                        playlistManager.isLiked(track: track) ? "Видалити з улюблених" : "Додати в улюблені",
                                        systemImage: playlistManager.isLiked(track: track) ? "heart.slash" : "heart"
                                    )
                                }
                            }
                        }
                    }
                }
            }
            .padding(.top)
            .padding(.bottom, audioEngine.currentTrack != nil ? 80 : 24)
        }
        .background(ThemeManager.shared.primaryBackground.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        PlaylistView(
            title: "Улюблені треки",
            subtitle: "Ваша особиста колекція",
            icon: "heart.fill",
            tracks: [
                Track(
                    id: "sample-1",
                    name: "Blinding Lights",
                    artistName: "The Weeknd",
                    albumName: "After Hours",
                    albumImageURL: nil,
                    previewURL: nil,
                    durationMs: 200000,
                    popularity: 90
                )
            ]
        )
    }
    .preferredColorScheme(.dark)
}
