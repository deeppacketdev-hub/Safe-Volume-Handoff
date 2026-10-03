import SwiftUI

@MainActor
final class ArtworkImageCache {
    static let shared: NSCache<NSURL, UIImage> = {
        let cache = NSCache<NSURL, UIImage>()
        cache.countLimit = 40
        cache.totalCostLimit = 40 * 1024 * 1024 // 40 MB max
        return cache
    }()
}

struct AlbumArtView: View {
    let track: Track
    var isPlaying: Bool = true
    var size: CGFloat? = nil
    var cornerRadius: CGFloat = 18
    var shadowRadius: CGFloat? = nil
    var shadowY: CGFloat? = nil
    var shadowOpacity: Double? = nil
    var scale: CGFloat? = nil
    var onColorExtracted: ((Color) -> Void)?
    var onPaletteExtracted: ((ArtworkPalette) -> Void)?

    @State private var cachedImage: UIImage?

    private var targetSize: CGFloat {
        size ?? 280
    }

    private var effectiveShadowRadius: CGFloat {
        shadowRadius ?? (isPlaying ? 24 : 10)
    }

    private var effectiveShadowY: CGFloat {
        shadowY ?? (isPlaying ? 12 : 5)
    }

    private var effectiveShadowOpacity: Double {
        shadowOpacity ?? (isPlaying ? 0.45 : 0.20)
    }

    private var effectiveScale: CGFloat {
        scale ?? (isPlaying ? 1.0 : 0.88)
    }

    var body: some View {
        Group {
            if let image = cachedImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                AsyncImage(url: track.albumImageURL) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    case .failure, .empty:
                        albumPlaceholder
                    @unknown default:
                        albumPlaceholder
                    }
                }
            }
        }
        .frame(width: targetSize, height: targetSize)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .shadow(
            color: .black.opacity(effectiveShadowOpacity),
            radius: effectiveShadowRadius,
            y: effectiveShadowY
        )
        .scaleEffect(effectiveScale)
        .animation(.spring(response: 0.38, dampingFraction: 0.75), value: isPlaying)
        .task(id: track.albumImageURL) {
            await loadImageAndExtractColor()
        }
    }

    private var albumPlaceholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(ThemeManager.shared.cardBackground)
            .frame(width: targetSize, height: targetSize)
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: max(14, targetSize * 0.28)))
                    .foregroundStyle(ThemeManager.shared.secondaryText)
            }
    }

    @MainActor
    private func loadImageAndExtractColor() async {
        guard let url = track.albumImageURL else { return }

        if let cached = ArtworkImageCache.shared.object(forKey: url as NSURL) {
            self.cachedImage = cached
            let palette = cached.artworkPalette
            self.onColorExtracted?(palette.primary)
            self.onPaletteExtracted?(palette)
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data) {
                ArtworkImageCache.shared.setObject(uiImage, forKey: url as NSURL)
                self.cachedImage = uiImage
                
                let palette = uiImage.artworkPalette
                self.onColorExtracted?(palette.primary)
                self.onPaletteExtracted?(palette)
            }
        } catch {
            // Placeholder handled by AsyncImage / fallback
        }
    }
}

#Preview {
    AlbumArtView(
        track: Track(
            id: "1", name: "Test", artistName: "Artist",
            albumName: "Album", albumImageURL: nil, previewURL: nil,
            durationMs: 30000, popularity: 50
        )
    )
    .preferredColorScheme(.dark)
    .background(ThemeManager.shared.primaryBackground)
}
