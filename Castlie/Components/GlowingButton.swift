import SwiftUI

struct GlowingButton: View {
    let title: String
    let icon: String
    let color: Color
    var isFullWidth: Bool = false
    let action: () -> Void
    
    var body: some View {
        PhaseAnimator([false, true]) { isGlowing in
            Button(action: {
                action()
                HapticFeedbackService.medium()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                    Text(title)
                }
                .font(AppFonts.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: isFullWidth ? .infinity : nil)
                .padding(.horizontal, isFullWidth ? 16 : 24)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(color)
                        .shadow(color: color.opacity(isGlowing ? 0.55 : 0.20), radius: isGlowing ? 12 : 4)
                )
            }
            .buttonStyle(.plain)
        } animation: { _ in
            .easeInOut(duration: 1.5)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        GlowingButton(title: "Підключити", icon: "checkmark.shield.fill", color: ThemeManager.shared.safeColor, action: {})
        GlowingButton(title: "Обережно", icon: "exclamationmark.triangle.fill", color: ThemeManager.shared.warningColor, action: {})
        GlowingButton(title: "На всю ширину", icon: "speaker.wave.2.fill", color: ThemeManager.shared.accent, isFullWidth: true, action: {})
    }
    .padding()
    .preferredColorScheme(.dark)
    .background(ThemeManager.shared.primaryBackground)
}
