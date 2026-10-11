import SwiftUI
import ImageIO

/// Спільний кеш обкладинок: одне завантаження на URL, декодування та зменшення у фоні.
@MainActor
final class ArtworkStore {
    static let shared = ArtworkStore()

    private let images = NSCache<NSString, UIImage>()
    private let palettes = NSCache<NSURL, PaletteBox>()
    private var inflight: [String: Task<UIImage?, Never>] = [:]

    private final class PaletteBox {
        let palette: ArtworkPalette
        init(_ palette: ArtworkPalette) { self.palette = palette }
    }

    private init() {
        images.totalCostLimit = 64 * 1024 * 1024
        palettes.countLimit = 100
    }

    /// Округлює розмір вгору до одного з кількох "кошиків", щоб не плодити копії.
    static func bucket(forPixels pixels: CGFloat) -> Int {
        let sizes = [128, 256, 512, 1024]
        return sizes.first { CGFloat($0) >= pixels } ?? 1024
    }

    func cachedImage(for url: URL, pixels: Int) -> UIImage? {
        images.object(forKey: key(url, pixels))
    }

    func image(for url: URL, pixels: Int) async -> UIImage? {
        let key = key(url, pixels)
        if let cached = images.object(forKey: key) { return cached }
        if let task = inflight[key as String] { return await task.value }

        let task = Task.detached(priority: .userInitiated) { () -> UIImage? in
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
            return Self.downsample(data, maxPixels: pixels)
        }
        inflight[key as String] = task
        let image = await task.value
        inflight[key as String] = nil

        if let image {
            let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
            images.setObject(image, forKey: key, cost: cost)
        }
        return image
    }

    func cachedPalette(for url: URL) -> ArtworkPalette? {
        palettes.object(forKey: url as NSURL)?.palette
    }

    func palette(for url: URL) async -> ArtworkPalette {
        if let cached = cachedPalette(for: url) { return cached }
        guard let image = await image(for: url, pixels: 128), let cgImage = image.cgImage else {
            return .fallback
        }
        let palette = await Task.detached(priority: .utility) {
            ArtworkPalette.extract(from: cgImage)
        }.value
        palettes.setObject(PaletteBox(palette), forKey: url as NSURL)
        return palette
    }

    private func key(_ url: URL, _ pixels: Int) -> NSString {
        "\(pixels)|\(url.absoluteString)" as NSString
    }

    nonisolated private static func downsample(_ data: Data, maxPixels: Int) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

/// Обкладинка з плавною появою та плейсхолдером. `size` — орієнтовний розмір у пунктах для декодування.
struct ArtworkImage: View {
    let url: URL?
    let size: CGFloat
    let cornerRadius: CGFloat

    @State private var image: UIImage?

    init(url: URL?, size: CGFloat, cornerRadius: CGFloat = 8) {
        self.url = url
        self.size = size
        self.cornerRadius = cornerRadius
        if let url {
            let pixels = ArtworkStore.bucket(forPixels: size * 3)
            _image = State(initialValue: ArtworkStore.shared.cachedImage(for: url, pixels: pixels))
        }
    }

    private var pixels: Int { ArtworkStore.bucket(forPixels: size * 3) }

    var body: some View {
        Rectangle()
            .fill(Theme.card)
            .overlay {
                if image == nil {
                    Image(systemName: "music.note")
                        .font(.system(size: max(12, size * 0.3), weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .task(id: url) { await load() }
            .accessibilityHidden(true)
    }

    private func load() async {
        guard let url else {
            image = nil
            return
        }
        if let cached = ArtworkStore.shared.cachedImage(for: url, pixels: pixels) {
            image = cached
            return
        }
        image = nil
        let loaded = await ArtworkStore.shared.image(for: url, pixels: pixels)
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: 0.25)) { image = loaded }
    }
}
