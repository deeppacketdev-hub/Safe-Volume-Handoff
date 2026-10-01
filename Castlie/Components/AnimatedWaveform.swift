import SwiftUI

struct AnimatedWaveform: View {
    let isPlaying: Bool
    let color: Color
    let barCount: Int
    
    @State private var animationPhases: [CGFloat]
    
    init(isPlaying: Bool, color: Color = ThemeManager.shared.accent, barCount: Int = 4) {
        self.isPlaying = isPlaying
        self.color = color
        self.barCount = barCount
        self._animationPhases = State(initialValue: Array(repeating: 0.3, count: barCount))
    }
    
    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(color)
                    .frame(width: 3, height: max(3, animationPhases[index] * 20))
            }
        }
        .frame(height: 20)
        .onAppear {
            if isPlaying { startAnimation() }
        }
        .onChange(of: isPlaying) { _, newValue in
            if newValue {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
    }
    
    private func startAnimation() {
        for i in 0..<barCount {
            withAnimation(
                .easeInOut(duration: Double.random(in: 0.3...0.6))
                .repeatForever(autoreverses: true)
                .delay(Double(i) * 0.1)
            ) {
                animationPhases[i] = CGFloat.random(in: 0.3...1.0)
            }
        }
    }
    
    private func stopAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            for i in 0..<barCount {
                animationPhases[i] = 0.3
            }
        }
    }
}

#Preview {
    HStack(spacing: 20) {
        AnimatedWaveform(isPlaying: true)
        AnimatedWaveform(isPlaying: false)
        AnimatedWaveform(isPlaying: true, color: ThemeManager.shared.safeColor, barCount: 6)
    }
    .padding()
    .preferredColorScheme(.dark)
    .background(ThemeManager.shared.primaryBackground)
}
