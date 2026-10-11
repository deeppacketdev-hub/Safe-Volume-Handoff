import SwiftUI

struct NewReleasesSection: View {
    let albums: [SpotifyAlbum]
    let zoom: Namespace.ID

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Нові релізи")

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 14) {
                    ForEach(albums) { album in
                        NavigationLink(value: album) {
                            AlbumCard(album: album)
                                .matchedTransitionSource(id: album.id, in: zoom)
                        }
                        .buttonStyle(.pressable(scale: 0.96))
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
    }
}

private struct AlbumCard: View {
    let album: SpotifyAlbum

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ArtworkImage(url: album.imageURL, size: 160, cornerRadius: 12)
                .frame(width: 160, height: 160)
            Text(album.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(album.artistNames ?? album.releaseYear ?? " ")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 160, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
