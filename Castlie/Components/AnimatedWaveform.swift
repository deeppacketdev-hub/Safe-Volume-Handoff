import SwiftUI

struct AnimatedWaveform: View {
    let isPlaying: Bool
    let color: Color
    let barCount: Int
    var maxHeight: CGFloat = 16
    
    init(
        isPlaying: Bool,
        color: Color = ThemeManager.shared.accent,
        barCount: Int = 4,
        maxHeight: CGFloat = 16
    ) {
        self.isPlaying = isPlaying
        self.color = color
        self.barCount = barCount
        self.maxHeight = maxHeight
    }
    
    var body: some View {
        TimelineView(.animation(paused: !isPlaying)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(color)
                        .frame(width: 3, height: barHeight(for: index, time: time))
                }
            }
        }
        .frame(height: maxHeight, alignment: .bottom)
    }

    private func barHeight(for index: Int, time: Double) -> CGFloat {
        if !isPlaying {
            switch index % 4 {
            case 0: return maxHeight * 0.38
            case 1: return maxHeight * 0.72
            case 2: return maxHeight * 0.48
            default: return maxHeight * 0.88
            }
        }
        let speeds: [Double] = [8.5, 6.2, 9.8, 7.1]
        let speed = speeds[index % speeds.count]
        let offset = Double(index) * 1.35
        let rawWave = sin(time * speed + offset)
        let normalized = (rawWave + 1.0) / 2.0 // 0.0 ... 1.0
        let minH = maxHeight * 0.28
        let maxH = maxHeight * 0.95
        return minH + CGFloat(normalized) * (maxH - minH)
    }
}

#Preview {
    HStack(spacing: 20) {
        AnimatedWaveform(isPlaying: true)
        AnimatedWaveform(isPlaying: false)
        AnimatedWaveform(isPlaying: true, color: ThemeManager.shared.safeColor, barCount: 6, maxHeight: 18)
    }
    .padding()
    .preferredColorScheme(.dark)
    .background(ThemeManager.shared.primaryBackground)
}

