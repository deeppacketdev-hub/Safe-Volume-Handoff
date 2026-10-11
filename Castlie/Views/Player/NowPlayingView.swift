import SwiftUI

/// Повноекранний плеєр. Відкривається zoom-переходом з міні-плеєра, закривається свайпом вниз.
struct NowPlayingView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var palette: ArtworkPalette = .fallback
    @State private var showDevices = false

    private let engine = AudioEngine.shared
    private let playlists = PlaylistManager.shared
    private let discovery = DeviceDiscoveryService.shared
    private let connect = CastlieConnectService.shared

    private var output: AudioDevice {
        connect.activeRemoteDevice?.audioDevice ?? discovery.currentDevice
    }

    var body: some View {
        Group {
            if let track = engine.currentTrack {
                content(for: track)
            } else {
                Color.clear
            }
        }
        .background {
            PlayerBackground(palette: palette)
                .ignoresSafeArea()
        }
        .task(id: engine.currentTrack?.albumImageURL) {
            guard let url = engine.currentTrack?.albumImageURL else {
                palette = .fallback
                return
            }
            if let cached = ArtworkStore.shared.cachedPalette(for: url) {
                palette = cached
                return
            }
            let extracted = await ArtworkStore.shared.palette(for: url)
            guard !Task.isCancelled else { return }
            palette = extracted
        }
        .sheet(isPresented: $showDevices) {
            DevicesView(presentation: .sheet)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .statusBanners()
        .preferredColorScheme(.dark)
        // Плеєр займає рівно один екран — обмежуємо масштаб тексту, щоб керування не випадало за край.
        .dynamicTypeSize(...DynamicTypeSize.xxLarge)
    }

    private func content(for track: Track) -> some View {
        VStack(spacing: 0) {
            header(for: track)

            Spacer(minLength: 16)

            ArtworkImage(url: track.albumImageURL, size: 360, cornerRadius: 16)
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .scaleEffect(engine.isPlaying ? 1 : 0.84)
                .shadow(
                    color: .black.opacity(engine.isPlaying ? 0.45 : 0.25),
                    radius: engine.isPlaying ? 28 : 12,
                    y: engine.isPlaying ? 16 : 6
                )
                .animation(.spring(duration: 0.55, bounce: 0.3), value: engine.isPlaying)
                .id(track.id)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))

            Spacer(minLength: 20)

            VStack(spacing: 18) {
                titleRow(for: track)
                ScrubberView()
                TransportControls()
                    .padding(.vertical, 4)
                PlayerVolumeSection(deviceType: output.type)
                outputBar
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 12)
        .animation(.spring(duration: 0.45, bounce: 0.2), value: track.id)
    }

    // MARK: - Header

    private func header(for track: Track) -> some View {
        VStack(spacing: 10) {
            Capsule()
                .fill(.white.opacity(0.35))
                .frame(width: 38, height: 5)
                .padding(.top, 8)
                .accessibilityHidden(true)

            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.body.weight(.semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Згорнути плеєр")

                Spacer()

                VStack(spacing: 2) {
                    Text("Зараз грає")
                        .font(.caption2.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    Text(track.albumName)
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                }
                .padding(.horizontal, 8)

                Spacer()

                TrackMenu(track: track) {
                    Image(systemName: "ellipsis")
                        .font(.body.weight(.semibold))
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .accessibilityLabel("Більше дій")
            }
        }
    }

    // MARK: - Title

    private func titleRow(for track: Track) -> some View {
        let isLiked = playlists.isLiked(track: track)
        return HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(track.name)
                    .font(.title2.weight(.bold))
                    .lineLimit(1)
                Text(track.artistName)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Button {
                playlists.toggleLike(track: track)
            } label: {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(isLiked ? Theme.like : .primary)
                    .contentTransition(.symbolEffect(.replace))
                    .symbolEffect(.bounce, value: isLiked)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .accessibilityLabel(isLiked ? "Прибрати з улюблених" : "Додати в улюблені")
        }
    }

    // MARK: - Output

    private var outputBar: some View {
        HStack(spacing: 12) {
            Button {
                showDevices = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: output.symbol)
                        .foregroundStyle(output.isBuiltIn ? Color.secondary : Theme.accent)
                    Text(output.isBuiltIn ? "Цей iPhone" : output.name)
                        .lineLimit(1)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.tertiary)
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
            .buttonStyle(.glass)
            .accessibilityLabel("Пристрій відтворення: \(output.name)")

            Image(systemName: "airplay.audio")
                .font(.body.weight(.semibold))
                .frame(width: 30, height: 30)
                .padding(8)
                .glassEffect(.regular.interactive(), in: .circle)
                .opensSystemRoutePicker(accessibilityLabel: "Вибрати аудіовихід")
        }
    }
}

// MARK: - Background

/// Фон із кольорів обкладинки. Статичний градієнт — дешевий для GPU, колір змінюється з анімацією.
private struct PlayerBackground: View {
    let palette: ArtworkPalette

    var body: some View {
        ZStack {
            MeshGradient(
                width: 3,
                height: 3,
                points: [
                    [0, 0], [0.5, 0], [1, 0],
                    [0, 0.45], [0.6, 0.5], [1, 0.4],
                    [0, 1], [0.5, 1], [1, 1]
                ],
                colors: [
                    palette.primary, palette.primary.opacity(0.8), palette.secondary,
                    palette.secondary.opacity(0.9), palette.primary.opacity(0.7), palette.background,
                    palette.background, palette.background, palette.background
                ]
            )
            LinearGradient(
                colors: [.black.opacity(0.15), .black.opacity(0.35), .black.opacity(0.75)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .background(Theme.background)
        .animation(.easeInOut(duration: 0.8), value: palette)
    }
}

// MARK: - Scrubber

private struct ScrubberView: View {
    @State private var scrubValue: Double?
    private let engine = AudioEngine.shared

    var body: some View {
        let duration = max(engine.duration, 0)
        let progress = scrubValue ?? engine.progress
        let elapsed = progress * duration

        VStack(spacing: 4) {
            ElasticSlider(
                value: progress,
                tint: .white,
                onEditingChanged: { editing in
                    if editing {
                        scrubValue = engine.progress
                    } else if let value = scrubValue {
                        engine.seek(to: value * duration)
                        scrubValue = nil
                    }
                },
                onChange: { scrubValue = $0 }
            )
            .disabled(duration <= 0)

            HStack {
                Text(Format.time(elapsed))
                Spacer()
                Text("-" + Format.time(max(0, duration - elapsed)))
            }
            .font(.caption.weight(.medium))
            .monospacedDigit()
            .foregroundStyle(scrubValue == nil ? .secondary : .primary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Позиція у треку")
        .accessibilityValue("\(Format.time(elapsed)) з \(Format.time(duration))")
        .accessibilityAdjustableAction { direction in
            let step = 5.0
            let target = direction == .increment ? engine.currentTime + step : engine.currentTime - step
            engine.seek(to: target)
        }
    }
}

// MARK: - Transport

private struct TransportControls: View {
    private let engine = AudioEngine.shared

    var body: some View {
        HStack {
            toggleButton(
                symbol: "shuffle",
                isOn: engine.isShuffled,
                label: engine.isShuffled ? "Перемішування увімкнено" : "Перемішування вимкнено"
            ) { engine.toggleShuffle() }

            Spacer()

            Button { engine.playPrevious() } label: {
                Image(systemName: "backward.fill")
                    .font(.system(size: 30))
                    .frame(width: 60, height: 60)
            }
            .buttonStyle(.pressable(scale: 0.82))
            .accessibilityLabel("Попередній трек")

            Spacer()

            Button { engine.togglePlayPause() } label: {
                ZStack {
                    if engine.isBuffering {
                        ProgressView()
                            .controlSize(.large)
                            .tint(.white)
                    } else {
                        Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 46))
                            .contentTransition(.symbolEffect(.replace.downUp))
                    }
                }
                .frame(width: 72, height: 72)
                .contentShape(Rectangle())
            }
            .buttonStyle(.pressable(scale: 0.85))
            .accessibilityLabel(engine.isPlaying ? "Пауза" : "Відтворити")
            .sensoryFeedback(.impact(weight: .medium), trigger: engine.isPlaying)

            Spacer()

            Button { engine.playNext() } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 30))
                    .frame(width: 60, height: 60)
            }
            .buttonStyle(.pressable(scale: 0.82))
            .accessibilityLabel("Наступний трек")

            Spacer()

            toggleButton(
                symbol: engine.repeatMode.symbol,
                isOn: engine.repeatMode != .off,
                label: engine.repeatMode.accessibilityLabel
            ) { engine.toggleRepeat() }
        }
        .foregroundStyle(.primary)
    }

    private func toggleButton(symbol: String, isOn: Bool, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(isOn ? Theme.accent : .secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
                .background(isOn ? Theme.accent.opacity(0.18) : .clear, in: Circle())
        }
        .buttonStyle(.pressable(scale: 0.85))
        .animation(.spring(duration: 0.3), value: isOn)
        .sensoryFeedback(.selection, trigger: isOn)
        .accessibilityLabel(label)
    }
}

// MARK: - Volume

private struct PlayerVolumeSection: View {
    let deviceType: DeviceType
    private let engine = AudioEngine.shared
    private let safe = SafeVolumeManager.shared

    var body: some View {
        VStack(spacing: 8) {
            SafeVolumeSlider(value: engine.volume, deviceType: deviceType) { engine.setVolume($0) }

            HStack(spacing: 8) {
                SafetyBadge(level: safe.safetyLevel(for: engine.volume, type: deviceType), compact: true)
                if safe.isNightModeActive {
                    Label("Нічний ліміт \(Format.percent(safe.maxAllowedVolume))", systemImage: "moon.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.night)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.night.opacity(0.15), in: Capsule())
                }
            }
        }
    }
}
