import SwiftUI
import UIKit

extension UIImage {
    /// Витягує домінантний (середній) колір з зображення
    /// Алгоритм: зменшуємо зображення до 1x1 піксель і читаємо колір
    var dominantColor: Color {
        // Зменшуємо зображення до 1x1 для швидкості
        let size = CGSize(width: 1, height: 1)
        
        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        defer { UIGraphicsEndImageContext() }
        
        draw(in: CGRect(origin: .zero, size: size))
        
        guard let context = UIGraphicsGetCurrentContext(),
              let cgImage = context.makeImage(),
              let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            return Color(hex: "1A1A24") // Fallback
        }
        
        let r = Double(bytes[0]) / 255.0
        let g = Double(bytes[1]) / 255.0
        let b = Double(bytes[2]) / 255.0
        
        // Затемнюємо колір щоб він був придатний для фону тексту
        return Color(red: r * 0.4, green: g * 0.4, blue: b * 0.4)
    }
}
