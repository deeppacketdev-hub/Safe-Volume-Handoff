import SwiftUI

struct AlbumDetailView: View {
    let album: SpotifyAlbum
    
    @State private var tracks: [Track] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var audioEngine = AudioEngine.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Album Header
                HStack(spacing: 16) {
                    AsyncImage(url: album.images.first.flatMap { URL(string: $0.url) }) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure, .empty:
                            RoundedRectangle(cornerRadius: 16)
                                .fill(ThemeManager.shared.cardBackground)
                                .overlay {
                                    Image(systemName: "music.note")
                                        .font(.system(size: 36))
                                        .foregroundStyle(ThemeManager.shared.secondaryText)
                                }
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(album.name)
                            .font(AppFonts.title2)
                            .foregroundStyle(ThemeManager.shared.primaryText)
                            .lineLimit(2)
                        
                        if let artists = album.artists, !artists.isEmpty {
                            Text(artists.map(\.name).joined(separator: ", "))
                                .font(AppFonts.subheadline)
                                .foregroundStyle(ThemeManager.shared.secondaryText)
                                .lineLimit(1)
                        } else if let firstTrack = tracks.first {
                            Text(firstTrack.artistName)
                                .font(AppFonts.subheadline)
                                .foregroundStyle(ThemeManager.shared.secondaryText)
                                .lineLimit(1)
                        }
                        
                        if let date = album.releaseDate {
                            Text("Реліз: \(date)")
                                .font(AppFonts.caption)
                                .foregroundStyle(ThemeManager.shared.secondaryText)
                        }
                    }
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Play Button
                if !tracks.isEmpty {
                    HStack {
                        GlowingButton(
                            title: "Відтворити альбом",
                            icon: "play.fill",
                            color: ThemeManager.shared.accent,
                            isFullWidth: true
                        ) {
                            audioEngine.play(tracks: tracks, startIndex: 0)
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Loading / Error / Tracks
                if isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .tint(ThemeManager.shared.accent)
                        Spacer()
                    }
                    .padding(.vertical, 40)
                } else if let error = errorMessage {
                    VStack(spacing: 8) {
                        Text("Не вдалося завантажити треки")
                            .font(AppFonts.headline)
                            .foregroundStyle(ThemeManager.shared.primaryText)
                        Text(error)
                            .font(AppFonts.caption)
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                } else {
                    LazyVStack(spacing: 4) {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                            SpotifyTrackRow(track: track) {
                                audioEngine.play(tracks: tracks, startIndex: index)
                            }
                        }
                    }
                }
            }
            .padding(.top)
            .padding(.bottom, audioEngine.currentTrack != nil ? 80 : 24)
        }
        .background(ThemeManager.shared.primaryBackground.ignoresSafeArea())
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadTracks()
        }
    }
    
    private func loadTracks() async {
        isLoading = true
        errorMessage = nil
        do {
            tracks = try await SpotifyAPIService.shared.getAlbumTracks(albumId: album.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
}

#Preview {
    NavigationStack {
        AlbumDetailView(
            album: SpotifyAlbum(
                id: "sample-album",
                name: "After Hours",
                images: [],
                releaseDate: "2020",
                artists: [SpotifyArtist(id: "1", name: "The Weeknd")]
            )
        )
    }
    .preferredColorScheme(.dark)
}
