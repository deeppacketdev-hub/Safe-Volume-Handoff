import Foundation
import Observation

@Observable
@MainActor
final class SearchViewModel {
    enum Phase: Equatable {
        case idle
        case searching
        case results
        case empty
        case failed(String)
    }

    var query = "" {
        didSet {
            guard query != oldValue else { return }
            scheduleSearch()
        }
    }
    private(set) var results: [Track] = []
    private(set) var recentTracks: [Track] = []
    private(set) var phase: Phase = .idle

    private let api = SpotifyAPIService.shared
    private var searchTask: Task<Void, Never>?
    private let recentKey = "RecentSearchesTracks"

    init() {
        if let data = UserDefaults.standard.data(forKey: recentKey),
           let tracks = try? JSONDecoder().decode([Track].self, from: data) {
            recentTracks = tracks
        }
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Пошук із затримкою, поки користувач друкує.
    private func scheduleSearch() {
        searchTask?.cancel()
        guard !trimmedQuery.isEmpty else {
            results = []
            phase = .idle
            return
        }
        phase = .searching
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await self?.runSearch()
        }
    }

    /// Пошук одразу (кнопка "Пошук" на клавіатурі або "Повторити").
    func searchNow() {
        searchTask?.cancel()
        guard !trimmedQuery.isEmpty else { return }
        phase = .searching
        searchTask = Task { [weak self] in await self?.runSearch() }
    }

    private func runSearch() async {
        let text = trimmedQuery
        do {
            let found = try await api.searchTracks(query: text)
            guard !Task.isCancelled, text == trimmedQuery else { return }
            results = found
            phase = found.isEmpty ? .empty : .results
        } catch {
            guard !Task.isCancelled, (error as? URLError)?.code != .cancelled else { return }
            phase = .failed(SpotifyError.message(for: error))
        }
    }

    // MARK: - Recent

    func addRecent(_ track: Track) {
        recentTracks.removeAll { $0.id == track.id }
        recentTracks.insert(track, at: 0)
        if recentTracks.count > 30 { recentTracks.removeLast(recentTracks.count - 30) }
        saveRecent()
    }

    func removeRecent(_ track: Track) {
        recentTracks.removeAll { $0.id == track.id }
        saveRecent()
    }

    func clearRecent() {
        recentTracks.removeAll()
        saveRecent()
    }

    private func saveRecent() {
        if let data = try? JSONEncoder().encode(recentTracks) {
            UserDefaults.standard.set(data, forKey: recentKey)
        }
    }
}
