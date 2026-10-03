import SwiftUI

extension View {
    /// Стандартний перехід для карток пристроїв
    func cardStyle() -> some View {
        self
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(ThemeManager.shared.cardBackground)
            )
    }
    
    /// Анімований перехід при появі
    func fadeInTransition(delay: Double = 0) -> some View {
        self
            .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}
