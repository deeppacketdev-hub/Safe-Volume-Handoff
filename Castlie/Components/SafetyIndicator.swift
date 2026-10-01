import SwiftUI

struct SafetyIndicator: View {
    let level: SafeVolumeManager.SafetyLevel
    var showLabel = true
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: level.sfSymbol)
                .font(.caption)
            
            if showLabel {
                Text(level.label)
                    .font(AppFonts.caption)
            }
        }
        .foregroundStyle(level.color)
    }
}

#Preview {
    VStack(spacing: 12) {
        SafetyIndicator(level: .safe)
        SafetyIndicator(level: .warning)
        SafetyIndicator(level: .danger)
        SafetyIndicator(level: .safe, showLabel: false)
    }
    .padding()
    .preferredColorScheme(.dark)
    .background(ThemeManager.shared.primaryBackground)
}
