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
            .animation(.spring(response: 0.4, dampingFraction: 0.8).delay(delay), value: UUID())
    }
}
