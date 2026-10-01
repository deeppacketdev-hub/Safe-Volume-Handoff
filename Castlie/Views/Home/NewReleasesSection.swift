import SwiftUI

struct NewReleasesSection: View {
    let albums: [SpotifyAlbum]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Нові релізи")
                .font(AppFonts.title2)
                .foregroundStyle(ThemeManager.shared.primaryText)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(albums) { album in
                        NavigationLink(destination: AlbumDetailView(album: album)) {
                            AlbumCardView(album: album)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

// MARK: - Album Card

struct AlbumCardView: View {
    let album: SpotifyAlbum
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Обкладинка
            AsyncImage(url: album.images.first.flatMap { URL(string: $0.url) }) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                case .failure:
                    albumPlaceholder
                case .empty:
                    albumPlaceholder
                        .overlay {
                            ProgressView()
                                .tint(ThemeManager.shared.accent)
                        }
                @unknown default:
                    albumPlaceholder
                }
            }
            .frame(width: 160, height: 160)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            // Назва альбому
            Text(album.name)
                .font(AppFonts.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(ThemeManager.shared.primaryText)
                .lineLimit(1)
            
            // Дата релізу
            if let releaseDate = album.releaseDate {
                Text(releaseDate)
                    .font(AppFonts.caption)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
            }
        }
        .frame(width: 160)
    }
    
    private var albumPlaceholder: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(ThemeManager.shared.cardBackground)
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 30))
                    .foregroundStyle(ThemeManager.shared.secondaryText)
            }
    }
}

#Preview {
    NewReleasesSection(albums: [])
        .preferredColorScheme(.dark)
        .background(ThemeManager.shared.primaryBackground)
}
