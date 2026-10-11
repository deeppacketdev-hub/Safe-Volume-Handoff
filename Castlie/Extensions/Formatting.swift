import Foundation

enum Format {
    /// Українські форми множини: 1 трек, 2 треки, 5 треків.
    static func plural(_ count: Int, one: String, few: String, many: String) -> String {
        let mod10 = count % 10
        let mod100 = count % 100
        if mod10 == 1 && mod100 != 11 { return one }
        if (2...4).contains(mod10) && !(12...14).contains(mod100) { return few }
        return many
    }

    static func tracks(_ count: Int) -> String {
        "\(count) \(plural(count, one: "трек", few: "треки", many: "треків"))"
    }

    /// "0:15" / "3:24"
    static func time(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    static func percent(_ volume: Float) -> String {
        "\(Int((volume * 100).rounded()))%"
    }

    /// "5 хв тому", "вчора"
    static func relative(_ date: Date) -> String {
        if Date().timeIntervalSince(date) < 60 { return "щойно" }
        return date.formatted(
            Date.RelativeFormatStyle(presentation: .named, unitsStyle: .wide)
                .locale(Locale(identifier: "uk_UA"))
        )
    }
}
