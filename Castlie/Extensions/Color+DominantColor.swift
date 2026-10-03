import SwiftUI
import UIKit

public struct ArtworkPalette: Equatable, Sendable {
    public var primary: Color
    public var secondary: Color
    public var ambientDark: Color

    public static let `default` = ArtworkPalette(
        primary: Color(hex: "2C2C36"),
        secondary: Color(hex: "1C1C24"),
        ambientDark: Color(hex: "08080C")
    )

    public init(primary: Color, secondary: Color, ambientDark: Color) {
        self.primary = primary
        self.secondary = secondary
        self.ambientDark = ambientDark
    }
}

private final class PaletteCacheBox: @unchecked Sendable {
    let palette: ArtworkPalette
    init(palette: ArtworkPalette) { self.palette = palette }
}

@MainActor
private final class ArtworkPaletteCache {
    static let shared: NSCache<AnyObject, PaletteCacheBox> = {
        let cache = NSCache<AnyObject, PaletteCacheBox>()
        cache.countLimit = 60
        return cache
    }()
}

extension UIImage {
    /// Витягує точну, багату палітру кольорів для атмосферного Apple Music фону (з кешуванням)
    @MainActor
    var artworkPalette: ArtworkPalette {
        if let cached = ArtworkPaletteCache.shared.object(forKey: self) {
            return cached.palette
        }
        let palette = extractArtworkPalette()
        ArtworkPaletteCache.shared.setObject(PaletteCacheBox(palette: palette), forKey: self)
        return palette
    }

    private func extractArtworkPalette() -> ArtworkPalette {
        let targetWidth = 16
        let targetHeight = 16
        let pixelCount = targetWidth * targetHeight
        var rawData = [UInt8](repeating: 0, count: pixelCount * 4)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        // КРИТИЧНО: byteOrder32Big + premultipliedLast гарантує порядок байтів:
        // rawData[0] = RED, rawData[1] = GREEN, rawData[2] = BLUE, rawData[3] = ALPHA
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(
            data: &rawData,
            width: targetWidth,
            height: targetHeight,
            bitsPerComponent: 8,
            bytesPerRow: targetWidth * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return .default
        }

        // Рендеримо зображення у фіксований RGBA-контекст
        guard let cgImg = self.cgImage else {
            return .default
        }
        context.draw(cgImg, in: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        var candidates: [(r: Double, g: Double, b: Double, sat: Double, lum: Double, score: Double)] = []

        for i in 0..<pixelCount {
            let offset = i * 4
            let a = Double(rawData[offset + 3]) / 255.0
            if a < 0.3 { continue } // Прозорі пікселі ігноруємо

            let r = Double(rawData[offset]) / 255.0     // ЧЕРВОНИЙ
            let g = Double(rawData[offset + 1]) / 255.0 // ЗЕЛЕНИЙ
            let b = Double(rawData[offset + 2]) / 255.0 // СИНІЙ

            let maxC = max(r, max(g, b))
            let minC = min(r, min(g, b))
            let delta = maxC - minC
            let sat = maxC > 0.001 ? (delta / maxC) : 0
            let lum = 0.299 * r + 0.587 * g + 0.114 * b

            // Ігноруємо занадто темні (глибокі тіні) або чисто білі безбарвні пікселі
            if lum < 0.08 || (lum > 0.92 && sat < 0.12) {
                continue
            }

            // Пріоритет насиченим, виразним кольорам обкладинки
            let lumBalance = 1.0 - abs(lum - 0.5) * 1.2
            let score = sat * 2.4 + lumBalance * 0.6

            candidates.append((r, g, b, sat, lum, score))
        }

        candidates.sort { $0.score > $1.score }

        guard let best = candidates.first else {
            // Для монохромних чорно-білих обкладинок
            return ArtworkPalette(
                primary: Color(hex: "343440"),
                secondary: Color(hex: "22222C"),
                ambientDark: Color(hex: "08080C")
            )
        }

        // Первинний живий колір обкладинки
        let primaryColor = Color(red: best.r, green: best.g, blue: best.b)

        // Шукаємо виразний вторинний колір, який помітно відрізняється від першого
        let secondaryCandidate = candidates.first(where: { cand in
            let diff = abs(cand.r - best.r) + abs(cand.g - best.g) + abs(cand.b - best.b)
            return diff > 0.45
        })

        let secR: Double
        let secG: Double
        let secB: Double

        if let sec = secondaryCandidate {
            secR = sec.r
            secG = sec.g
            secB = sec.b
        } else {
            // Якщо обкладинка монотонна одного тону (як Mobb Deep червоний),
            // генеруємо гармонійний глибокий відтінок того самого сімейства
            secR = min(1.0, max(0.0, best.r * 0.72 + 0.08))
            secG = min(1.0, max(0.0, best.g * 0.45 + 0.04))
            secB = min(1.0, max(0.0, best.b * 0.45 + 0.04))
        }

        let secondaryColor = Color(red: secR, green: secG, blue: secB)
        let ambientDark = Color(red: best.r * 0.08 + 0.03, green: best.g * 0.08 + 0.03, blue: best.b * 0.08 + 0.04)

        return ArtworkPalette(
            primary: primaryColor,
            secondary: secondaryColor,
            ambientDark: ambientDark
        )
    }

    /// Для зворотної сумісності
    @MainActor
    var dominantColor: Color {
        artworkPalette.primary
    }
}
