import SwiftUI

/// Міні-плеєр у системному слоті над таб-баром (Liquid Glass додає сама iOS).
struct MiniPlayer: View {
    let onOpen: () -> Void
    let onDevices: () -> Void

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement
    private let engine = AudioEngine.shared
    private let discovery = DeviceDiscoveryService.shared
    private let connect = CastlieConnectService.shared

    private var isCompact: Bool { placement == .inline }

    private var output: AudioDevice {
        connect.activeRemoteDevice?.audioDevice ?? discovery.currentDevice
    }

    var body: some View {
        if let track = engine.currentTrack {
            HStack(spacing: 10) {
                ArtworkImage(url: track.albumImageURL, size: 34, cornerRadius: 7)
                    .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 1) {
                    Text(track.name)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if output.isBuiltIn {
                        Text(track.artistName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        Label(output.name, systemImage: output.symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.accent)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentTransition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: output)

                if !isCompact {
                    controlButton(output.isBuiltIn ? "airplay.audio" : output.symbol, label: "Пристрої", tint: output.isBuiltIn ? .primary : Theme.accent, action: onDevices)
                }

                playPauseButton

                if !isCompact {
                    controlButton("forward.fill", label: "Наступний трек") { engine.playNext() }
                }
            }
            .padding(.leading, 10)
            .padding(.trailing, 6)
            .contentShape(Rectangle())
            .dynamicTypeSize(...DynamicTypeSize.xLarge)
            .onTapGesture(perform: onOpen)
            .accessibilityElement(children: .contain)
            .accessibilityAction(named: "Відкрити плеєр", onOpen)
        }
    }

    private var playPauseButton: some View {
        Button {
            engine.togglePlayPause()
        } label: {
            ZStack {
                if engine.isBuffering {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                        .contentTransition(.symbolEffect(.replace.downUp))
                }
            }
            .frame(width: 40, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 0.85))
        .foregroundStyle(.primary)
        .accessibilityLabel(engine.isPlaying ? "Пауза" : "Відтворити")
        .sensoryFeedback(.impact(weight: .light), trigger: engine.isPlaying)
    }

    private func controlButton(_ symbol: String, label: String, tint: Color = .primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 38, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.pressable(scale: 0.85))
        .accessibilityLabel(label)
    }
}
