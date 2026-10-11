import SwiftUI

struct SearchView: View {
    @State private var model = SearchViewModel()
    private let engine = AudioEngine.shared

    var body: some View {
        NavigationStack {
            content
                .background(Theme.background)
                .navigationTitle("Пошук")
                .searchable(text: $model.query, prompt: "Треки та виконавці")
                .onSubmit(of: .search) { model.searchNow() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.query.trimmingCharacters(in: .whitespaces).isEmpty {
            recentList
        } else {
            switch model.phase {
            case .searching where model.results.isEmpty:
                ProgressView()
                    .controlSize(.large)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .empty:
                ContentUnavailableView.search(text: model.query)
            case .failed(let message):
                ContentUnavailableView {
                    Label("Пошук не вдався", systemImage: "wifi.exclamationmark")
                } description: {
                    Text(message)
                } actions: {
                    Button("Спробувати ще раз") { model.searchNow() }
                        .buttonStyle(.glassProminent)
                        .tint(Theme.accent)
                }
            default:
                resultsList
            }
        }
    }

    private var resultsList: some View {
        List {
            ForEach(Array(model.results.enumerated()), id: \.element.id) { index, track in
                TrackRow(track: track) {
                    model.addRecent(track)
                    engine.play(tracks: model.results, startIndex: index)
                }
                .listRowStyle()
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .overlay(alignment: .top) {
            if model.phase == .searching {
                ProgressView()
                    .padding(10)
                    .glassEffect(.regular, in: .circle)
                    .padding(.top, 8)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: model.phase)
    }

    @ViewBuilder
    private var recentList: some View {
        if model.recentTracks.isEmpty {
            ContentUnavailableView(
                "Шукайте музику",
                systemImage: "magnifyingglass",
                description: Text("Введіть назву треку або ім'я виконавця.")
            )
        } else {
            List {
                Section {
                    ForEach(model.recentTracks) { track in
                        TrackRow(track: track) {
                            // Порядок не змінюємо, щоб рядок не стрибав під пальцем.
                            let snapshot = model.recentTracks
                            engine.play(tracks: snapshot, startIndex: snapshot.firstIndex(of: track) ?? 0)
                        }
                        .listRowStyle()
                        .swipeActions {
                            Button("Видалити", systemImage: "trash", role: .destructive) {
                                withAnimation { model.removeRecent(track) }
                            }
                        }
                    }
                } header: {
                    HStack {
                        Text("Нещодавні")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.primary)
                            .textCase(nil)
                        Spacer()
                        Button("Очистити") {
                            withAnimation { model.clearRecent() }
                        }
                        .font(.subheadline.weight(.semibold))
                        .tint(Theme.accent)
                        .textCase(nil)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDismissesKeyboard(.immediately)
        }
    }
}

private extension View {
    func listRowStyle() -> some View {
        self
            .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 8))
            .listRowBackground(Color.clear)
            .listRowSeparatorTint(.white.opacity(0.08))
            .alignmentGuide(.listRowSeparatorLeading) { _ in 60 }
    }
}

#Preview {
    SearchView()
        .preferredColorScheme(.dark)
}
