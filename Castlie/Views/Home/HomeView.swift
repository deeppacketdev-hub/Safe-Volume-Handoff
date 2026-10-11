import SwiftUI

enum LibraryRoute: Hashable {
    case liked
    case playlist(UUID)
}

struct HomeView: View {
    @State private var model = HomeViewModel()
    @State private var showNewPlaylist = false
    @State private var newPlaylistName = ""
    @Namespace private var zoom

    private let engine = AudioEngine.shared
    private let playlists = PlaylistManager.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 32) {
                    librarySection

                    if model.isLoading && !model.hasContent {
                        loadingPlaceholder
                    } else {
                        if !model.newReleases.isEmpty {
                            NewReleasesSection(albums: model.newReleases, zoom: zoom)
                        }
                        if !model.recommendations.isEmpty {
                            recommendationsSection
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .background(Theme.background)
            .navigationTitle("Головна")
            .refreshable { await model.load() }
            .overlay {
                if let error = model.errorMessage, !model.hasContent, !model.isLoading {
                    ContentUnavailableView {
                        Label("Не вдалося завантажити", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Спробувати ще раз") {
                            Task { await model.load() }
                        }
                        .buttonStyle(.glassProminent)
                        .tint(Theme.accent)
                    }
                }
            }
            .task {
                if !model.hasContent { await model.load() }
            }
            .navigationDestination(for: SpotifyAlbum.self) { album in
                AlbumDetailView(album: album)
                    .navigationTransition(.zoom(sourceID: album.id, in: zoom))
            }
            .navigationDestination(for: LibraryRoute.self) { route in
                switch route {
                case .liked: PlaylistView(source: .liked)
                case .playlist(let id): PlaylistView(source: .playlist(id))
                }
            }
            .alert("Новий плейлист", isPresented: $showNewPlaylist) {
                TextField("Назва", text: $newPlaylistName)
                Button("Створити") { playlists.createPlaylist(name: newPlaylistName) }
                Button("Скасувати", role: .cancel) {}
            }
        }
    }

    // MARK: - Library

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Медіатека")

            ScrollView(.horizontal) {
                LazyHStack(spacing: 14) {
                    NavigationLink(value: LibraryRoute.liked) {
                        LibraryCard(
                            title: "Улюблені",
                            subtitle: Format.tracks(playlists.likedTracks.count),
                            symbol: "heart.fill",
                            colors: [Color(hex: "FF375F"), Color(hex: "FF6B35")]
                        )
                    }
                    .buttonStyle(.pressable(scale: 0.96))

                    ForEach(playlists.playlists) { playlist in
                        NavigationLink(value: LibraryRoute.playlist(playlist.id)) {
                            LibraryCard(
                                title: playlist.name,
                                subtitle: Format.tracks(playlist.trackCount),
                                symbol: playlist.customIcon ?? "music.note.list",
                                colors: [Color(hex: "3A3A4E"), Color(hex: "22222E")]
                            )
                        }
                        .buttonStyle(.pressable(scale: 0.96))
                    }

                    Button {
                        newPlaylistName = ""
                        showNewPlaylist = true
                    } label: {
                        LibraryCard(title: "Новий плейлист", subtitle: "Створити", symbol: "plus", colors: [Theme.card, Theme.card])
                    }
                    .buttonStyle(.pressable(scale: 0.96))
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Recommendations

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Рекомендації")
            LazyVStack(spacing: 0) {
                ForEach(Array(model.recommendations.enumerated()), id: \.element.id) { index, track in
                    TrackRow(track: track) {
                        engine.play(tracks: model.recommendations, startIndex: index)
                    }
                    .padding(.leading, 20)
                    .padding(.trailing, 8)
                }
            }
        }
    }

    private var loadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Нові релізи")
            HStack(spacing: 14) {
                ForEach(0..<3, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 6) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Theme.card)
                            .frame(width: 160, height: 160)
                        Text("Назва альбому").font(.subheadline)
                        Text("Виконавець").font(.caption)
                    }
                }
            }
            .padding(.horizontal, 20)
            .redacted(reason: .placeholder)
            .opacity(0.6)
        }
        .accessibilityLabel("Завантаження")
    }
}

struct SectionHeader: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.title2.weight(.bold))
            .padding(.horizontal, 20)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct LibraryCard: View {
    let title: String
    let subtitle: String
    let symbol: String
    let colors: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: 136, height: 136)
                .overlay {
                    Image(systemName: symbol)
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 136, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
