import SwiftUI

/// Повзунок гучності з кольором зони безпеки, нічним лімітом та тактильним відгуком на межах зон.
struct SafeVolumeSlider: View {
    let value: Float
    let deviceType: DeviceType
    var showsIcons = true
    var onEditingChanged: (Bool) -> Void = { _ in }
    let onChange: (Float) -> Void

    @State private var dragValue: Float?
    private let safe = SafeVolumeManager.shared

    private var displayed: Float { dragValue ?? value }
    private var level: SafeVolumeManager.SafetyLevel { safe.safetyLevel(for: displayed, type: deviceType) }

    var body: some View {
        HStack(spacing: 12) {
            if showsIcons {
                Image(systemName: "speaker.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(width: 18)
            }

            ElasticSlider(
                value: Double(displayed),
                tint: level.color,
                limit: Double(safe.maxAllowedVolume),
                onEditingChanged: { editing in
                    if editing {
                        dragValue = value
                        SystemVolumeController.shared.beginInteraction()
                    } else {
                        dragValue = nil
                        SystemVolumeController.shared.endInteraction()
                    }
                    onEditingChanged(editing)
                },
                onChange: { newValue in
                    dragValue = Float(newValue)
                    onChange(Float(newValue))
                }
            )
            .animation(.easeInOut(duration: 0.2), value: level)

            if showsIcons {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(width: 22)
            }
        }
        .sensoryFeedback(.selection, trigger: level)
        .accessibilityRepresentation {
            Slider(
                value: Binding(get: { Double(value) }, set: { onChange(Float($0)) }),
                in: 0...Double(safe.maxAllowedVolume),
                step: 0.05
            ) {
                Text("Гучність")
            }
            .accessibilityValue("\(Format.percent(value)), \(level.label)")
        }
    }
}

/// Капсула з позначкою зони безпеки.
struct SafetyBadge: View {
    let level: SafeVolumeManager.SafetyLevel
    var compact = false

    var body: some View {
        Label(level.label, systemImage: level.symbol)
            .labelStyle(.titleAndIcon)
            .font(compact ? .caption.weight(.semibold) : .footnote.weight(.semibold))
            .foregroundStyle(level.color)
            .padding(.horizontal, compact ? 8 : 10)
            .padding(.vertical, compact ? 4 : 6)
            .background(level.color.opacity(0.15), in: Capsule())
            .contentTransition(.symbolEffect(.replace))
            .animation(.easeInOut(duration: 0.2), value: level)
    }
}

/// Відсоток гучності кольору зони безпеки.
struct VolumePill: View {
    let volume: Float
    let deviceType: DeviceType

    var body: some View {
        let level = SafeVolumeManager.shared.safetyLevel(for: volume, type: deviceType)
        Text(Format.percent(volume))
            .font(.caption.weight(.bold))
            .monospacedDigit()
            .foregroundStyle(level.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(level.color.opacity(0.15), in: Capsule())
    }
}
