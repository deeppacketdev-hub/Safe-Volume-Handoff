import SwiftUI

struct HomeView: View {
    @State private var viewModel = HomeViewModel()
    @State private var audioEngine = AudioEngine.shared
    @State private var playlistManager = PlaylistManager.shared

    @State private var showCreatePlaylist = false
    @State private var newPlaylistName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // MARK: - Медіатека
                    librarySection

                    // MARK: - Нові релізи
                    if !viewModel.newReleases.isEmpty {
                        NewReleasesSection(albums: viewModel.newReleases)
                    }

                    // MARK: - Рекомендації
                    if !viewModel.recommendations.isEmpty {
                        recommendationsSection
                    }
                }
                .padding(.top, 4)
                .padding(.bottom, audioEngine.currentTrack != nil ? 90 : 32)
            }
            .background(ThemeManager.shared.primaryBackground.ignoresSafeArea())
            .navigationTitle("Castlie")
            .alert("Новий плейлист", isPresented: $showCreatePlaylist) {
                TextField("Назва", text: $newPlaylistName)
                Button("Створити") {
                    playlistManager.createPlaylist(name: newPlaylistName)
                }
                Button("Скасувати", role: .cancel) {}
            }
            .overlay {
                if viewModel.isLoading && viewModel.newReleases.isEmpty {
                    ProgressView()
                        .tint(ThemeManager.shared.accent)
                        .scaleEffect(1.2)
                }

                if let error = viewModel.errorMessage {
                    ContentUnavailableView {
                        Label("Немає з'єднання", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Повторити") {
                            Task { await viewModel.loadContent() }
                        }
                        .buttonStyle(.bordered)
                        .tint(ThemeManager.shared.accent)
                    }
                }
            }
            .task {
                if viewModel.newReleases.isEmpty {
                    await viewModel.loadContent()
                }
            }
        }
    }

    // MARK: - Library Section

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Медіатека")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(ThemeManager.shared.primaryText)

                Spacer()

                Button {
                    newPlaylistName = ""
                    showCreatePlaylist = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .foregroundStyle(ThemeManager.shared.accent)
                }
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    // Улюблені
                    NavigationLink {
                        PlaylistView(
                            title: "Улюблені",
                            subtitle: "\(playlistManager.likedTracks.count) треків",
                            icon: "heart.fill",
                            tracks: playlistManager.likedTracks
                        )
                    } label: {
                        LibraryCard(
                            title: "Улюблені",
                            count: playlistManager.likedTracks.count,
                            icon: "heart.fill",
                            gradient: [Color(hex: "FF416C"), Color(hex: "FF4B2B")]
                        )
                    }
                    .buttonStyle(.plain)

                    // Плейлисти
                    ForEach(playlistManager.playlists) { playlist in
                        NavigationLink {
                            PlaylistView(
                                title: playlist.name,
                                subtitle: "\(playlist.trackCount) треків",
                                icon: playlist.customIcon ?? "music.note.list",
                                tracks: playlist.tracks,
                                playlistId: playlist.id
                            )
                        } label: {
                            LibraryCard(
                                title: playlist.name,
                                count: playlist.trackCount,
                                icon: playlist.customIcon ?? "music.note.list",
                                gradient: [ThemeManager.shared.cardBackground, Color(hex: "2E2E3E")]
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    // MARK: - Recommendations Section

    private var recommendationsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Рекомендації")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(ThemeManager.shared.primaryText)
                .padding(.horizontal)

            LazyVStack(spacing: 2) {
                ForEach(Array(viewModel.recommendations.enumerated()), id: \.element.id) { index, track in
                    SpotifyTrackRow(track: track) {
                        audioEngine.play(
                            tracks: viewModel.recommendations,
                            startIndex: index
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Library Card

private struct LibraryCard: View {
    let title: String
    let count: Int
    let icon: String
    let gradient: [Color]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: gradient,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 140, height: 140)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 38, weight: .medium))
                        .foregroundStyle(.white.opacity(icon == "heart.fill" ? 1 : 0.65))
                }

            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(ThemeManager.shared.primaryText)
                .lineLimit(1)

            Text("\(count) треків")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(ThemeManager.shared.secondaryText)
        }
        .frame(width: 140)
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
