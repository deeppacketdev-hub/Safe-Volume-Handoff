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
                    // Ваша медіатека (Плейлисти та Улюблені)
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Ваша медіатека")
                                .font(AppFonts.title2)
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
                            LazyHStack(spacing: 16) {
                                // Картка "Улюблені"
                                NavigationLink {
                                    PlaylistView(
                                        title: "Улюблені треки",
                                        subtitle: "Вподобані композиції",
                                        icon: "heart.fill",
                                        tracks: playlistManager.likedTracks
                                    )
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        RoundedRectangle(cornerRadius: 14)
                                            .fill(
                                                LinearGradient(
                                                    colors: [Color(hex: "FF416C"), Color(hex: "FF4B2B")],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 140, height: 140)
                                            .overlay {
                                                Image(systemName: "heart.fill")
                                                    .font(.system(size: 44))
                                                    .foregroundStyle(.white)
                                            }
                                        
                                        Text("Улюблені")
                                            .font(AppFonts.headline)
                                            .foregroundStyle(ThemeManager.shared.primaryText)
                                            .lineLimit(1)
                                        
                                        Text("\(playlistManager.likedTracks.count) треків")
                                            .font(AppFonts.caption)
                                            .foregroundStyle(ThemeManager.shared.secondaryText)
                                    }
                                    .frame(width: 140)
                                }
                                .buttonStyle(.plain)
                                
                                // Користувацькі плейлисти
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
                                        VStack(alignment: .leading, spacing: 8) {
                                            RoundedRectangle(cornerRadius: 14)
                                                .fill(
                                                    LinearGradient(
                                                        colors: [ThemeManager.shared.cardBackground, Color(hex: "2E2E3E")],
                                                        startPoint: .topLeading,
                                                        endPoint: .bottomTrailing
                                                    )
                                                )
                                                .frame(width: 140, height: 140)
                                                .overlay {
                                                    Image(systemName: playlist.customIcon ?? "music.note.list")
                                                        .font(.system(size: 40))
                                                        .foregroundStyle(ThemeManager.shared.accent)
                                                }
                                            
                                            Text(playlist.name)
                                                .font(AppFonts.headline)
                                                .foregroundStyle(ThemeManager.shared.primaryText)
                                                .lineLimit(1)
                                            
                                            Text("\(playlist.trackCount) треків")
                                                .font(AppFonts.caption)
                                                .foregroundStyle(ThemeManager.shared.secondaryText)
                                        }
                                        .frame(width: 140)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    
                    // Нові релізи — горизонтальний скрол
                    if !viewModel.newReleases.isEmpty {
                        NewReleasesSection(
                            albums: viewModel.newReleases
                        )
                    }
                    
                    // Рекомендації — вертикальний список
                    if !viewModel.recommendations.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Рекомендації")
                                .font(AppFonts.title2)
                                .foregroundStyle(ThemeManager.shared.primaryText)
                                .padding(.horizontal)
                            
                            LazyVStack(spacing: 4) {
                                ForEach(viewModel.recommendations) { track in
                                    SpotifyTrackRow(track: track) {
                                        audioEngine.play(
                                            tracks: viewModel.recommendations,
                                            startIndex: viewModel.recommendations.firstIndex(of: track) ?? 0
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
            .navigationTitle("Castlie")
            .alert("Новий плейлист", isPresented: $showCreatePlaylist) {
                TextField("Назва плейлиста", text: $newPlaylistName)
                Button("Створити") {
                    playlistManager.createPlaylist(name: newPlaylistName)
                }
                Button("Скасувати", role: .cancel) {}
            } message: {
                Text("Введіть назву для нового плейлиста")
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(ThemeManager.shared.accent)
                        .scaleEffect(1.5)
                }
                
                if let error = viewModel.errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                        Text(error)
                            .font(AppFonts.subheadline)
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                            .multilineTextAlignment(.center)
                        Button("Повторити") {
                            Task { await viewModel.loadContent() }
                        }
                        .foregroundStyle(ThemeManager.shared.accent)
                    }
                    .padding()
                }
            }
            .task {
                if viewModel.newReleases.isEmpty {
                    await viewModel.loadContent()
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)
}
