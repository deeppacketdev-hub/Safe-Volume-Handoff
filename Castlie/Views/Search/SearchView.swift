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
                
                // Результати
                if viewModel.isSearching {
                    Spacer()
                    ProgressView()
                        .tint(ThemeManager.shared.accent)
                    Spacer()
                } else if viewModel.results.isEmpty && !viewModel.searchText.isEmpty {
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
                } else if viewModel.results.isEmpty {
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
                } else {
                    ScrollView {
                        LazyVStack(spacing: 4) {
                            ForEach(viewModel.results) { track in
                                SpotifyTrackRow(track: track) {
                                    audioEngine.play(
                                        tracks: viewModel.results,
                                        startIndex: viewModel.results.firstIndex(of: track) ?? 0
                                    )
                                }
                            }
                        }
                        .padding(.top, 8)
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
