import SwiftUI

struct AlbumDetailView: View {
    let album: SpotifyAlbum

    @State private var tracks: [Track] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    private let engine = AudioEngine.shared

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .padding(.top, 40)
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("Не вдалося завантажити треки", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Спробувати ще раз") { Task { await load() } }
                            .buttonStyle(.glassProminent)
                            .tint(Theme.accent)
                    }
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                            TrackRow(track: track, leading: .number(index + 1)) {
                                engine.play(tracks: tracks, startIndex: index)
                            }
                            .padding(.leading, 16)
                            .padding(.trailing, 8)
                        }
                    }
                    Text(Format.tracks(tracks.count))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
            .padding(.bottom, 24)
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle(album.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { if tracks.isEmpty { await load() } }
    }

    private var header: some View {
        VStack(spacing: 14) {
            ArtworkImage(url: album.imageURL, size: 240, cornerRadius: 14)
                .frame(width: 240, height: 240)
                .shadow(color: .black.opacity(0.4), radius: 20, y: 10)
                .padding(.top, 8)

            VStack(spacing: 4) {
                Text(album.name)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                if let artists = album.artistNames {
                    Text(artists)
                        .font(.title3)
                        .foregroundStyle(Theme.accent)
                        .multilineTextAlignment(.center)
                }
                if let year = album.releaseYear {
                    Text("Альбом · \(year)")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 24)

            HStack(spacing: 12) {
                Button {
                    engine.play(tracks: tracks)
                } label: {
                    Label("Слухати", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(Theme.accent)

                Button {
                    engine.playShuffled(tracks)
                } label: {
                    Label("Перемішати", systemImage: "shuffle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
            .controlSize(.large)
            .font(.body.weight(.semibold))
            .disabled(tracks.isEmpty)
            .padding(.horizontal, 20)
        }
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        do {
            tracks = try await SpotifyAPIService.shared.getAlbumTracks(albumId: album.id)
        } catch {
            errorMessage = SpotifyError.message(for: error)
        }
        isLoading = false
    }
}
