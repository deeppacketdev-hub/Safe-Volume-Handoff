import SwiftUI

/// Рядок треку: обкладинка або номер, назва, виконавець і меню дій.
struct TrackRow: View {
    enum Leading {
        case artwork
        case number(Int)
    }

    let track: Track
    var leading: Leading = .artwork
    /// Плейлист, з якого трек можна прибрати через меню.
    var playlistId: UUID? = nil
    let onTap: () -> Void

    private let engine = AudioEngine.shared
    private let playlists = PlaylistManager.shared

    private var isCurrent: Bool { engine.currentTrack?.id == track.id }

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onTap) {
                HStack(spacing: 12) {
                    leadingView

                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.name)
                            .font(.body.weight(isCurrent ? .semibold : .regular))
                            .foregroundStyle(isCurrent ? Theme.accent : .primary)
                            .lineLimit(1)
                        Text(track.artistName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    if playlists.isLiked(track: track) {
                        Image(systemName: "heart.fill")
                            .font(.caption)
                            .foregroundStyle(Theme.like)
                            .accessibilityLabel("В улюблених")
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(track.name), \(track.artistName)")
            .accessibilityValue(isCurrent ? (engine.isPlaying ? "Зараз грає" : "На паузі") : "")

            TrackMenu(track: track, playlistId: playlistId) {
                Image(systemName: "ellipsis")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Дії з треком")
        }
        .padding(.vertical, 4)
        .contextMenu {
            TrackMenuItems(track: track, playlistId: playlistId)
        }
    }

    @ViewBuilder
    private var leadingView: some View {
        switch leading {
        case .artwork:
            ArtworkImage(url: track.albumImageURL, size: 48, cornerRadius: 8)
                .frame(width: 48, height: 48)
                .overlay {
                    if isCurrent {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(.black.opacity(0.45))
                        NowPlayingIndicator(isPlaying: engine.isPlaying, color: .white)
                    }
                }
        case .number(let number):
            ZStack {
                if isCurrent {
                    NowPlayingIndicator(isPlaying: engine.isPlaying)
                } else {
                    Text("\(number)")
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 28)
        }
    }
}

/// Кнопка-меню з діями для треку.
struct TrackMenu<Label: View>: View {
    let track: Track
    var playlistId: UUID? = nil
    @ViewBuilder let label: () -> Label

    var body: some View {
        Menu {
            TrackMenuItems(track: track, playlistId: playlistId)
        } label: {
            label()
        }
    }
}

struct TrackMenuItems: View {
    let track: Track
    var playlistId: UUID? = nil

    private let playlists = PlaylistManager.shared

    var body: some View {
        let isLiked = playlists.isLiked(track: track)
        Button {
            playlists.toggleLike(track: track)
        } label: {
            Label(isLiked ? "Прибрати з улюблених" : "Додати в улюблені", systemImage: isLiked ? "heart.slash" : "heart")
        }

        let targets = playlists.playlists.filter { $0.id != playlistId }
        if !targets.isEmpty {
            Menu {
                ForEach(targets) { playlist in
                    Button(playlist.name) {
                        playlists.addTrack(track, to: playlist.id)
                    }
                }
            } label: {
                Label("Додати до плейлиста", systemImage: "text.badge.plus")
            }
        }

        if let playlistId {
            Button(role: .destructive) {
                playlists.removeTrack(trackId: track.id, from: playlistId)
            } label: {
                Label("Прибрати з плейлиста", systemImage: "minus.circle")
            }
        }
    }
}
