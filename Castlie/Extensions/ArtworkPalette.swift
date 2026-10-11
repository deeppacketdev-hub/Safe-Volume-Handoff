import SwiftUI
import CoreGraphics

/// Кольори фону повноекранного плеєра, витягнуті з обкладинки.
struct ArtworkPalette: Equatable, Sendable {
    var primary: Color
    var secondary: Color
    var background: Color

    static let fallback = ArtworkPalette(
        primary: Color(hex: "3A3A48"),
        secondary: Color(hex: "24242E"),
        background: Color(hex: "0C0C12")
    )

    /// Аналізує зменшену копію зображення 16×16. Безпечно викликати з будь-якого потоку.
    nonisolated static func extract(from image: CGImage) -> ArtworkPalette {
        let side = 16
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        let drawn = pixels.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress,
                width: side,
                height: side,
                bitsPerComponent: 8,
                bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: bitmapInfo
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return .fallback }

        struct Candidate { var r, g, b, score: Double }
        var candidates: [Candidate] = []
        candidates.reserveCapacity(side * side)

        for index in 0..<(side * side) {
            let offset = index * 4
            guard pixels[offset + 3] > 76 else { continue }
            let r = Double(pixels[offset]) / 255
            let g = Double(pixels[offset + 1]) / 255
            let b = Double(pixels[offset + 2]) / 255
            let maxC = max(r, g, b)
            let minC = min(r, g, b)
            let saturation = maxC > 0.001 ? (maxC - minC) / maxC : 0
            let luminance = 0.299 * r + 0.587 * g + 0.114 * b
            if luminance < 0.08 || (luminance > 0.92 && saturation < 0.12) { continue }
            let balance = 1 - abs(luminance - 0.5) * 1.2
            candidates.append(Candidate(r: r, g: g, b: b, score: saturation * 2.4 + balance * 0.6))
        }

        candidates.sort { $0.score > $1.score }
        guard let best = candidates.first else {
            return ArtworkPalette(primary: Color(hex: "3A3A48"), secondary: Color(hex: "24242E"), background: Color(hex: "0C0C12"))
        }

        let second = candidates.first {
            abs($0.r - best.r) + abs($0.g - best.g) + abs($0.b - best.b) > 0.45
        } ?? Candidate(
            r: min(1, best.r * 0.72 + 0.08),
            g: min(1, best.g * 0.45 + 0.04),
            b: min(1, best.b * 0.45 + 0.04),
            score: 0
        )

        return ArtworkPalette(
            primary: Color(red: best.r, green: best.g, blue: best.b),
            secondary: Color(red: second.r, green: second.g, blue: second.b),
            background: Color(red: best.r * 0.1 + 0.03, green: best.g * 0.1 + 0.03, blue: best.b * 0.1 + 0.04)
        )
    }
}
