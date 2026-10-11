import SwiftUI

/// Палітра Castlie. Додаток завжди працює в темній темі.
enum Theme {
    static let accent = Color(hex: "FF6B35")
    static let background = Color(hex: "0A0A0F")
    static let elevated = Color(hex: "16161E")
    static let card = Color(hex: "1E1E28")
    static let like = Color(hex: "FF375F")
    static let night = Color(hex: "5E5CE6")
}

/// Легке стискання при натисканні з пружною анімацією (як у системних кнопках).
struct PressableButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.94

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .opacity(configuration.isPressed ? 0.8 : 1)
            .animation(.spring(duration: 0.25, bounce: 0.35), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == PressableButtonStyle {
    static var pressable: PressableButtonStyle { PressableButtonStyle() }
    static func pressable(scale: CGFloat) -> PressableButtonStyle { PressableButtonStyle(scale: scale) }
}
