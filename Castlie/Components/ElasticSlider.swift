import SwiftUI

/// Повзунок у стилі Apple Music: тягнеться відносно пальця, потовщується під час жесту
/// і пружно розтягується за межами діапазону.
struct ElasticSlider: View {
    let value: Double
    var tint: Color = .white
    /// Верхня межа, вище якої значення не підніметься (наприклад, нічний ліміт).
    var limit: Double = 1
    var onEditingChanged: (Bool) -> Void = { _ in }
    let onChange: (Double) -> Void

    /// Скидається системою і при завершенні, і при скасуванні жесту (наприклад, коли перемогла прокрутка).
    @GestureState private var isTouching = false
    @State private var dragStart: Double?
    @State private var isVerticalSwipe = false
    @State private var overshoot: CGFloat = 0

    private var isDragging: Bool { dragStart != nil }

    var body: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let height: CGFloat = isDragging ? 12 : 6

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(.white.opacity(0.16))

                if limit < 0.999 {
                    Capsule()
                        .fill(.white.opacity(0.07))
                        .frame(width: width * (1 - limit))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                Capsule()
                    .fill(tint)
                    .frame(width: width * min(max(value, 0), 1))
            }
            .frame(height: height)
            .clipShape(Capsule())
            .scaleEffect(
                x: 1 + abs(overshoot) / width,
                y: 1 - min(abs(overshoot) / 120, 0.25),
                anchor: overshoot < 0 ? .trailing : .leading
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            // Одночасний жест: вертикальний свайп лишається прокрутці / закриттю плеєра.
            .simultaneousGesture(
                DragGesture(minimumDistance: 3)
                    .updating($isTouching) { _, state, _ in state = true }
                    .onChanged { gesture in handleDrag(gesture, width: width) }
            )
        }
        .frame(height: 32)
        .onChange(of: isTouching) { _, touching in
            guard !touching else { return }
            isVerticalSwipe = false
            overshoot = 0
            if dragStart != nil {
                dragStart = nil
                onEditingChanged(false)
            }
        }
        .animation(.spring(duration: 0.35, bounce: 0.35), value: isDragging)
        .animation(.spring(duration: 0.4, bounce: 0.45), value: overshoot == 0)
    }

    private func handleDrag(_ gesture: DragGesture.Value, width: CGFloat) {
        guard !isVerticalSwipe else { return }
        if dragStart == nil {
            // Напрямок визначаємо один раз на початку жесту.
            if abs(gesture.translation.height) > abs(gesture.translation.width) {
                isVerticalSwipe = true
                return
            }
            dragStart = value
            onEditingChanged(true)
        }
        let raw = (dragStart ?? value) + gesture.translation.width / width
        let upper = min(limit, 1)
        let clamped = min(max(raw, 0), upper)
        let excess = raw < 0 ? raw : max(raw - upper, 0)
        overshoot = rubberBand(excess * width)
        onChange(clamped)
    }

    /// Логарифмічний "гумовий" опір — що далі тягнеш, то менше розтягується.
    private func rubberBand(_ distance: CGFloat) -> CGFloat {
        let limit: CGFloat = 14
        let sign: CGFloat = distance < 0 ? -1 : 1
        return sign * limit * (1 - exp(-abs(distance) / (limit * 3)))
    }
}
