import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @State private var audioEngine = AudioEngine.shared
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Поле пошуку
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                    
                    TextField("Пошук треків...", text: $viewModel.searchText)
                        .foregroundStyle(ThemeManager.shared.primaryText)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onChange(of: viewModel.searchText) { _, _ in
                            viewModel.performSearch()
                        }
                    
                    if !viewModel.searchText.isEmpty {
                        Button {
                            viewModel.searchText = ""
                            viewModel.results = []
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(ThemeManager.shared.secondaryText)
                        }
                    }
                }
                .padding(12)
                .background(ThemeManager.shared.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Контент
                if !viewModel.searchText.isEmpty {
                    if viewModel.isSearching {
                        Spacer()
                        ProgressView()
                            .tint(ThemeManager.shared.accent)
                        Spacer()
                    } else if viewModel.results.isEmpty {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "music.note.list")
                                .font(.system(size: 40))
                                .foregroundStyle(ThemeManager.shared.secondaryText)
                            Text("Нічого не знайдено")
                                .font(AppFonts.body)
                                .foregroundStyle(ThemeManager.shared.secondaryText)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 4) {
                                ForEach(viewModel.results) { track in
                                    SpotifyTrackRow(track: track) {
                                        viewModel.addRecentTrack(track)
                                        audioEngine.play(
                                            tracks: viewModel.results,
                                            startIndex: viewModel.results.firstIndex(of: track) ?? 0
                                        )
                                    }
                                }
                            }
                            .padding(.top, 8)
                            .padding(.bottom, audioEngine.currentTrack != nil ? 80 : 24)
                        }
                    }
                } else {
                    if !viewModel.recentTracks.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Останній пошук")
                                    .font(AppFonts.headline)
                                    .foregroundStyle(ThemeManager.shared.primaryText)
                                
                                Spacer()
                                
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        viewModel.clearRecentTracks()
                                    }
                                } label: {
                                    Text("Очистити все")
                                        .font(AppFonts.caption)
                                        .foregroundStyle(ThemeManager.shared.accent)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.top, 16)
                            
                            ScrollView {
                                LazyVStack(spacing: 4) {
                                    ForEach(viewModel.recentTracks) { track in
                                        HStack(spacing: 0) {
                                            SpotifyTrackRow(track: track) {
                                                viewModel.addRecentTrack(track)
                                                audioEngine.play(
                                                    tracks: viewModel.recentTracks,
                                                    startIndex: viewModel.recentTracks.firstIndex(of: track) ?? 0
                                                )
                                            }
                                            
                                            Button {
                                                withAnimation(.easeInOut(duration: 0.2)) {
                                                    viewModel.removeRecentTrack(track)
                                                }
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.caption2.weight(.bold))
                                                    .foregroundStyle(ThemeManager.shared.secondaryText)
                                                    .frame(width: 32, height: 32)
                                                    .background(Color.white.opacity(0.06))
                                                    .clipShape(Circle())
                                            }
                                            .padding(.trailing, 16)
                                        }
                                        .contextMenu {
                                            Button(role: .destructive) {
                                                withAnimation {
                                                    viewModel.removeRecentTrack(track)
                                                }
                                            } label: {
                                                Label("Видалити з пошуку", systemImage: "trash")
                                            }
                                        }
                                    }
                                }
                                .padding(.top, 4)
                                .padding(.bottom, audioEngine.currentTrack != nil ? 80 : 24)
                            }
                        }
                    } else {
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundStyle(ThemeManager.shared.secondaryText)
                            Text("Введіть назву треку або виконавця")
                                .font(AppFonts.body)
                                .foregroundStyle(ThemeManager.shared.secondaryText)
                        }
                        Spacer()
                    }
                }
            }
            .background(ThemeManager.shared.primaryBackground.ignoresSafeArea())
            .navigationTitle("Пошук")
        }
    }
}

#Preview {
    SearchView()
        .preferredColorScheme(.dark)
}
