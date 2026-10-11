import SwiftUI

struct PlaylistView: View {
    enum Source: Hashable {
        case liked
        case playlist(UUID)
    }

    let source: Source

    @Environment(\.dismiss) private var dismiss
    @State private var showRename = false
    @State private var renameText = ""
    @State private var showDeleteConfirm = false

    private let engine = AudioEngine.shared
    private let playlists = PlaylistManager.shared

    private var playlist: Playlist? {
        guard case .playlist(let id) = source else { return nil }
        return playlists.playlists.first { $0.id == id }
    }

    private var title: String {
        switch source {
        case .liked: "Улюблені"
        case .playlist: playlist?.name ?? "Плейлист"
        }
    }

    private var tracks: [Track] {
        switch source {
        case .liked: playlists.likedTracks
        case .playlist: playlist?.tracks ?? []
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                header

                if tracks.isEmpty {
                    ContentUnavailableView {
                        Label("Тут поки порожньо", systemImage: source == .liked ? "heart" : "music.note.list")
                    } description: {
                        Text(source == .liked
                             ? "Натисніть ♥ у плеєрі або в меню треку, щоб додати його сюди."
                             : "Додавайте треки через меню «…» біля будь-якого треку.")
                    }
                    .padding(.top, 12)
                } else {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                            TrackRow(track: track, playlistId: playlist?.id) {
                                engine.play(tracks: tracks, startIndex: index)
                            }
                            .padding(.leading, 20)
                            .padding(.trailing, 8)
                        }
                    }
                }
            }
            .padding(.bottom, 24)
            .animation(.default, value: tracks.map(\.id))
        }
        .scrollIndicators(.hidden)
        .background(Theme.background)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let playlist {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Перейменувати", systemImage: "pencil") {
                            renameText = playlist.name
                            showRename = true
                        }
                        Button("Видалити плейлист", systemImage: "trash", role: .destructive) {
                            showDeleteConfirm = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                    .accessibilityLabel("Дії з плейлистом")
                }
            }
        }
        .alert("Перейменувати плейлист", isPresented: $showRename) {
            TextField("Назва", text: $renameText)
            Button("Зберегти") {
                if let id = playlist?.id { playlists.renamePlaylist(id: id, to: renameText) }
            }
            Button("Скасувати", role: .cancel) {}
        }
        .confirmationDialog("Видалити «\(title)»?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Видалити", role: .destructive) {
                // Екран закриється сам через onChange нижче.
                if let id = playlist?.id { playlists.deletePlaylist(id: id) }
            }
        } message: {
            Text("Треки залишаться в каталозі, видалиться лише плейлист.")
        }
        .onChange(of: playlist == nil) { _, removed in
            if removed, case .playlist = source { dismiss() }
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(LinearGradient(
                    colors: source == .liked
                        ? [Color(hex: "FF375F"), Color(hex: "FF6B35")]
                        : [Color(hex: "3A3A4E"), Color(hex: "1E1E28")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 200, height: 200)
                .overlay {
                    Image(systemName: source == .liked ? "heart.fill" : (playlist?.customIcon ?? "music.note.list"))
                        .font(.system(size: 64, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.92))
                }
                .shadow(color: .black.opacity(0.35), radius: 18, y: 10)
                .padding(.top, 8)
                .accessibilityHidden(true)

            VStack(spacing: 4) {
                Text(title)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                Text(Format.tracks(tracks.count))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }

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
}
