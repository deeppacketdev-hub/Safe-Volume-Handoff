import SwiftUI

struct FullPlayerView: View {
    // MARK: - Properties
    @Binding var isPresented: Bool
    @Binding var showDevicesSheet: Bool
    @Binding var devicesSheetDetent: PresentationDetent
    var selectedTab: AppTab = .home
    let screenWidth: CGFloat
    let screenHeight: CGFloat
    let safeTop: CGFloat
    let safeBottom: CGFloat

    @Environment(\.scenePhase) private var scenePhase

    @State private var audioEngine = AudioEngine.shared
    @State private var safeVolume = SafeVolumeManager.shared
    @State private var discovery = DeviceDiscoveryService.shared
    @State private var playlistManager = PlaylistManager.shared
    @State private var connectService = CastlieConnectService.shared
    @State private var palette = ArtworkPalette.default

    // Local high-performance 120 FPS gesture state (no root invalidation)
    @State private var internalProgress: CGFloat = 1.0 // 0.0 = full player, 1.0 = mini player
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging: Bool = false
    @State private var dragInitialProgress: CGFloat = 1.0

    // Spotify-style floating device callout state
    @State private var isCalloutVisible: Bool = false
    @State private var calloutDismissTask: Task<Void, Never>? = nil
    @State private var lastCalloutShowTime: Date = .distantPast
    @State private var tabChangeCounter: Int = 0

    // MARK: - Computed Properties
    private var p: CGFloat {
        min(1.0, max(0.0, internalProgress))
    }

    private func updateProgress(_ value: CGFloat) {
        internalProgress = min(1.0, max(0.0, value))
    }

    private var isRemoteActive: Bool {
        connectService.activeRemoteDevice != nil
    }

    private var activeDeviceSymbol: String {
        if isRemoteActive {
            return "laptopcomputer"
        }
        return discovery.currentDevice?.type.sfSymbol ?? "airplayaudio"
    }

    private var activeDeviceName: String {
        if let activeRemote = connectService.activeRemoteDevice {
            return activeRemote.name
        }
        return discovery.currentDevice?.name ?? "Цей iPhone"
    }

    private var isExternalDevice: Bool {
        isRemoteActive || (discovery.currentDevice != nil && discovery.currentDevice?.type != .iPhone)
    }

    // MARK: - Body
    var body: some View {
        let miniHeight: CGFloat = 56
        let miniInset: CGFloat = 16
        let miniWidth = screenWidth - (miniInset * 2)

        // TabBar sits from (screenHeight - safeBottom - 49) to screenHeight
        // Mini player rests 8pt above the TabBar
        let miniBottomY = screenHeight - safeBottom - 49 - 8
        let miniTopY = miniBottomY - miniHeight
        let travelDistance = miniTopY

        // Interpolated Card Frame
        let cardWidth = lerp(screenWidth, miniWidth, p)
        let cardHeight = lerp(screenHeight, miniHeight, p)
        let cardX = lerp(0, miniInset, p)
        let cardCornerRadius = lerp(p > 0.005 ? 38 : 0, 28, p)

        // Interpolated Card Y with rubber-banding on overscroll
        let currentCardY: CGFloat = {
            if isDragging {
                if dragInitialProgress < 0.5 {
                    // Pulling down from full player
                    if dragOffset > travelDistance {
                        return travelDistance + (dragOffset - travelDistance) * 0.22
                    } else if dragOffset < 0 {
                        return dragOffset * 0.22
                    } else {
                        return dragOffset
                    }
                } else {
                    // Pulling up from mini player
                    let targetY = travelDistance + dragOffset
                    if targetY < 0 {
                        return targetY * 0.22
                    } else if targetY > travelDistance {
                        return travelDistance + (targetY - travelDistance) * 0.22
                    } else {
                        return targetY
                    }
                }
            } else {
                return lerp(0, travelDistance, p)
            }
        }()

        // GPU-accelerated Hero Artwork scaling & coordinates
        // Header occupies safeTop + 67; bottom controls occupy safeBottom + 242
        let headerBottomY = safeTop + 67
        let bottomControlsTopY = screenHeight - safeBottom - 242

        // Prominent Apple Music Hero Artwork size: screenWidth - 44 (22pt padding each side)
        let maxArtAllowed = max(220, bottomControlsTopY - headerBottomY - 44)
        let fullArtSize = min(screenWidth - 44, min(348, maxArtAllowed))
        let miniArtSize: CGFloat = 40
        let miniArtLeading: CGFloat = 14
        let currentArtSize = lerp(fullArtSize, miniArtSize, p)
        let artScale = currentArtSize / fullArtSize

        // Center artwork precisely between header and bottom controls
        let fullArtCenterY = headerBottomY + ((bottomControlsTopY - headerBottomY) / 2)
        let miniArtCenterY: CGFloat = miniHeight / 2 // 28
        let currentArtCenterY = lerp(fullArtCenterY, miniArtCenterY, p)

        let miniArtCenterX: CGFloat = miniArtLeading + (miniArtSize / 2) // 14 + 20 = 34
        let currentArtCenterX = lerp(cardWidth / 2, miniArtCenterX, p)

        // Controls crossfade opacity (gentle Apple fluid crossfade)
        let fullControlsOpacity = max(0.0, min(1.0, 1.0 - p * 1.8))
        let miniControlsOpacity = max(0.0, min(1.0, (p - 0.25) / 0.75))

        let isHiddenOnDevicesTab = (selectedTab == .devices && !isPresented) || (showDevicesSheet && !isPresented)

        ZStack(alignment: .topLeading) {
            if !isHiddenOnDevicesTab {
                ZStack(alignment: .topLeading) {
                    // 1. Morphing Background Surface (Hardware Ambient Glow -> Liquid Glass)
                    cardBackground(
                        width: cardWidth,
                        height: cardHeight,
                        cornerRadius: cardCornerRadius,
                        p: p
                    )
                    .contentShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
                    .onTapGesture {
                        if p > 0.8 {
                            expandToFullPlayer()
                        }
                    }

                    // 2. Full Player Content (Header, scrubber, volume, device bar)
                    // Silky overlapping crossfade
                    if p < 0.60 {
                        fullPlayerContent(
                            screenWidth: screenWidth,
                            screenHeight: screenHeight,
                            safeTop: safeTop,
                            safeBottom: safeBottom,
                            fullArtSize: fullArtSize,
                            opacity: fullControlsOpacity,
                            p: p
                        )
                        .position(x: cardWidth / 2, y: screenHeight / 2)
                        .allowsHitTesting(p < 0.1)
                    }

                    // 3. Mini Player Content Bar (compact track title, waveform, buttons, bottom track)
                    // Silky overlapping crossfade
                    if p > 0.25, let track = audioEngine.currentTrack {
                        miniPlayerContentBar(
                            width: cardWidth,
                            miniHeight: miniHeight,
                            miniArtSize: miniArtSize,
                            miniArtLeading: miniArtLeading,
                            track: track
                        )
                        .opacity(miniControlsOpacity)
                        .position(x: cardWidth / 2, y: currentArtCenterY)
                        .allowsHitTesting(p > 0.85)
                    }

                    // 4. Hero Album Artwork (Continuously shrinks & glides from center to left slot with GPU scaling)
                    if let track = audioEngine.currentTrack {
                        AlbumArtView(
                            track: track,
                            isPlaying: audioEngine.isPlaying,
                            size: fullArtSize,
                            cornerRadius: lerp(24, 8 / artScale, p),
                            shadowRadius: lerp(audioEngine.isPlaying ? 28 : 12, 3, p),
                            shadowY: lerp(audioEngine.isPlaying ? 14 : 6, 1.5, p),
                            shadowOpacity: lerp(audioEngine.isPlaying ? 0.45 : 0.20, 0.25, p),
                            scale: lerp(audioEngine.isPlaying ? 1.0 : 0.88, 1.0, p),
                            onPaletteExtracted: handlePaletteExtracted
                        )
                        .shadow(
                            color: palette.primary.opacity(lerp(audioEngine.isPlaying ? 0.32 : 0.12, 0.0, p)),
                            radius: lerp(audioEngine.isPlaying ? 36 : 14, 0, p),
                            x: 0,
                            y: lerp(audioEngine.isPlaying ? 18 : 6, 0, p)
                        )
                        .scaleEffect(artScale)
                        .position(x: currentArtCenterX, y: currentArtCenterY)
                        .onTapGesture {
                            if p > 0.8 {
                                expandToFullPlayer()
                            }
                        }
                        .zIndex(15)
                    }
                }
                .frame(width: cardWidth, height: cardHeight)
                .clipShape(RoundedRectangle(cornerRadius: cardCornerRadius, style: .continuous))
                .shadow(color: Color.black.opacity(0.35 * p), radius: 18 * p, x: 0, y: 8 * p)
                .shadow(color: ThemeManager.shared.accent.opacity(0.14 * p), radius: 10 * p, x: 0, y: 2 * p)
                .overlay(alignment: .top) {
                    if isCalloutVisible && p > 0.75 {
                        let calloutHeight: CGFloat = 45
                        SpotifyDeviceCalloutView(
                            deviceName: activeDeviceName,
                            deviceSymbol: activeDeviceSymbol,
                            onChange: {
                                dismissCalloutImmediately()
                                openDevicesSheet()
                            },
                            onDismiss: {
                                dismissCalloutImmediately()
                            }
                        )
                        .offset(y: -calloutHeight - 6)
                        .transition(
                            .asymmetric(
                                insertion: .scale(scale: 0.88, anchor: .bottom)
                                    .combined(with: .opacity)
                                    .combined(with: .offset(y: 6)),
                                removal: .scale(scale: 0.92, anchor: .bottom)
                                    .combined(with: .opacity)
                                    .combined(with: .offset(y: 4))
                            )
                        )
                    }
                }
                .offset(x: cardX, y: currentCardY)
                .gesture(
                    DragGesture(minimumDistance: 4, coordinateSpace: .global)
                        .onChanged { value in
                            if !isDragging {
                                isDragging = true
                                dragInitialProgress = p
                                dismissCalloutImmediately()
                            }

                            let dy = value.translation.height
                            dragOffset = dy

                            if dragInitialProgress < 0.5 {
                                // Dragging down from Full Player:
                                if dy > 0 {
                                    let fraction = min(1.0, max(0.0, dy / travelDistance))
                                    updateProgress(fraction)
                                } else {
                                    updateProgress(0.0)
                                }
                            } else {
                                // Dragging up from Mini Player:
                                if dy < 0 {
                                    let upward = -dy
                                    let fraction = min(1.0, max(0.0, 1.0 - (upward / travelDistance)))
                                    updateProgress(fraction)
                                } else {
                                    updateProgress(1.0)
                                }
                            }
                        }
                        .onEnded { value in
                            isDragging = false
                            let dy = value.translation.height
                            let velocityY = value.predictedEndTranslation.height - dy

                            if dragInitialProgress < 0.5 {
                                // Full Player dismiss: downward flick or dragged past 24%
                                if velocityY > 220 || p > 0.24 {
                                    dismissToMiniPlayer()
                                } else {
                                    bounceBackToFullPlayer()
                                }
                            } else {
                                // Mini Player expand: upward flick or dragged up past 24%
                                if velocityY < -220 || p < 0.76 {
                                    expandToFullPlayer()
                                } else {
                                    dismissToMiniPlayer()
                                }
                            }
                        }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .move(edge: .bottom).combined(with: .opacity)
                ))
            }
        }
        .frame(width: screenWidth, height: screenHeight, alignment: .topLeading)
        .allowsHitTesting(!isHiddenOnDevicesTab || showDevicesSheet || isPresented)
        .animation(.spring(response: 0.36, dampingFraction: 0.84), value: isHiddenOnDevicesTab)
        .onAppear {
            updateProgress(isPresented ? 0.0 : 1.0)
            syncPaletteFromCache()
            if !isPresented {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(600))
                    triggerDeviceCallout(reason: .appOpen)
                }
            }
        }
        .task(id: audioEngine.currentTrack?.id) {
            syncPaletteFromCache()
        }
        .onChange(of: isPresented) { _, newValue in
            withAnimation(.spring(response: newValue ? 0.40 : 0.38, dampingFraction: newValue ? 0.86 : 0.88)) {
                updateProgress(newValue ? 0.0 : 1.0)
                dragOffset = 0
            }
            if !newValue {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(360))
                    triggerDeviceCallout(reason: .playerDismissed)
                }
            } else {
                dismissCalloutImmediately()
            }
        }
        .onChange(of: selectedTab) { _, _ in
            triggerDeviceCallout(reason: .tabChanged)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(400))
                    triggerDeviceCallout(reason: .appOpen)
                }
            }
        }
        .onChange(of: connectService.activeRemoteDevice) { _, _ in
            triggerDeviceCallout(reason: .deviceChanged)
        }
        .onChange(of: discovery.currentDevice) { _, _ in
            triggerDeviceCallout(reason: .deviceChanged)
        }
    }

    // MARK: - Morphing Card Surface Background (Hardware Accelerated & Liquid Glass)

    @ViewBuilder
    private func cardBackground(
        width: CGFloat,
        height: CGFloat,
        cornerRadius: CGFloat,
        p: CGFloat
    ) -> some View {
        ZStack {
            // A. Full Player Ambient Backdrop (Dynamic Apple Music Atmosphere with Equatable caching)
            if p < 0.85 {
                FullPlayerAmbientBackdrop(palette: palette, width: width)
                    .equatable()
                    .opacity(max(0.0, 1.0 - p * 1.4))
            }

            // B. Mini Player Apple Liquid Glass Surface (iOS 26+ native glassEffect in capsule)
            if p > 0.15 {
                miniPlayerGlassSurface()
                    .opacity(min(1.0, max(0.0, (p - 0.20) / 0.80)))
            }
        }
        .frame(width: width, height: height)
    }

    // MARK: - Apple Liquid Glass Surface Component

    @ViewBuilder
    private func miniPlayerGlassSurface() -> some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 0) {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .glassEffect(.regular.interactive(), in: .capsule)
            }
            .overlay(miniPlayerSpecularAndRim(cornerRadius: 28))
        } else {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(miniPlayerSpecularAndRim(cornerRadius: 28))
        }
    }

    @ViewBuilder
    private func miniPlayerSpecularAndRim(cornerRadius: CGFloat) -> some View {
        ZStack {
            // Specular reflection highlight
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // High-contrast translucent tint for legibility over content
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(hex: "12121A").opacity(0.48))

            // Delicate Liquid Glass rim stroke
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.48),
                            Color.white.opacity(0.14)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.8
                )
        }
    }

    // MARK: - Full Player Content

    @ViewBuilder
    private func fullPlayerContent(
        screenWidth: CGFloat,
        screenHeight: CGFloat,
        safeTop: CGFloat,
        safeBottom: CGFloat,
        fullArtSize: CGFloat,
        opacity: CGFloat,
        p: CGFloat
    ) -> some View {
        let verticalSpacing: CGFloat = screenHeight < 720 ? 8 : 14

        VStack(spacing: 0) {
            // Header Bar
            VStack(spacing: 0) {
                // Top drag grabber indicator capsule
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: 36, height: 5)
                    .padding(.top, safeTop + 8)
                    .padding(.bottom, 10)

                FullPlayerHeaderView(
                    isPlaying: audioEngine.isPlaying,
                    isRemoteActive: isRemoteActive,
                    deviceSymbol: activeDeviceSymbol,
                    onDismiss: dismissToMiniPlayer,
                    onDevicePicker: openDevicesSheet
                )
                .padding(.horizontal, 24)
                .padding(.bottom, 4)
            }
            .offset(y: -p * 25)

            Spacer(minLength: 4)

            // Transparent reservation for the morphing artwork
            Color.clear
                .frame(width: fullArtSize, height: fullArtSize)
                .padding(.vertical, 4)

            Spacer(minLength: 4)

            // Bottom Controls
            VStack(spacing: 0) {
                if let track = audioEngine.currentTrack {
                    FullPlayerTrackInfoView(
                        track: track,
                        isLiked: playlistManager.isLiked(track: track),
                        onLikeToggle: { handleLikeToggle(for: track) }
                    )
                    .padding(.horizontal, 24)
                }

                ProgressBarView()
                    .padding(.horizontal, 24)
                    .padding(.top, verticalSpacing)

                PlaybackControlsView()
                    .padding(.top, verticalSpacing * 0.7)

                VolumeSliderView()
                    .padding(.horizontal, 28)
                    .padding(.top, verticalSpacing)

                FullPlayerDeviceBar(
                    deviceName: activeDeviceName,
                    deviceSymbol: activeDeviceSymbol,
                    isHighlighted: isRemoteActive || (discovery.currentDevice?.type != .iPhone && discovery.currentDevice != nil),
                    onTap: openDevicesSheet
                )
                .padding(.horizontal, 24)
                .padding(.top, verticalSpacing)
                .padding(.bottom, safeBottom + 4)
            }
            .offset(y: p * 40)
            .scaleEffect(max(0.92, 1.0 - p * 0.08))
        }
        .frame(width: screenWidth, height: screenHeight)
        .opacity(opacity)
    }

    // MARK: - Mini Player Content Bar

    @ViewBuilder
    private func miniPlayerContentBar(
        width: CGFloat,
        miniHeight: CGFloat,
        miniArtSize: CGFloat,
        miniArtLeading: CGFloat,
        track: Track
    ) -> some View {
        ZStack(alignment: .bottom) {
            HStack(spacing: 10) {
                // Interactive tap area for opening full player (artwork thumbnail + track info + entire empty space)
                HStack(spacing: 12) {
                    // Clear placeholder reserving space for the morphing artwork thumbnail
                    Color.clear
                        .frame(width: miniArtSize, height: miniHeight)

                    // Track Title, Artist & Animated Waveform
                    MiniPlayerTrackInfo(
                        track: track,
                        isPlaying: audioEngine.isPlaying,
                        isExternalDevice: isExternalDevice,
                        deviceName: activeDeviceName,
                        deviceSymbol: activeDeviceSymbol
                    )
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .contentShape(Rectangle())
                .onTapGesture {
                    expandToFullPlayer()
                }

                // Mini Player Controls: Connect, Play/Pause, Next
                MiniPlayerControls(
                    isPlaying: audioEngine.isPlaying,
                    isRemoteActive: isExternalDevice,
                    deviceSymbol: activeDeviceSymbol,
                    onCastlieConnect: openDevicesSheet,
                    onPlayPause: togglePlayPause,
                    onNext: playNext
                )
            }
            .padding(.leading, miniArtLeading)
            .padding(.trailing, 10)
            .frame(width: width, height: miniHeight)

            // Delicate progress line along bottom edge
            MiniPlayerProgressTrack()
                .allowsHitTesting(false)
        }
        .frame(width: width, height: miniHeight)
        .contentShape(Rectangle())
        .onTapGesture {
            expandToFullPlayer()
        }
        .zIndex(20)
    }

    // MARK: - Actions

    private func handlePaletteExtracted(_ newPalette: ArtworkPalette) {
        withAnimation(.easeInOut(duration: 0.7)) {
            palette = newPalette
        }
    }

    private func syncPaletteFromCache() {
        guard let url = audioEngine.currentTrack?.albumImageURL else { return }
        if let cached = ArtworkImageCache.shared.object(forKey: url as NSURL) {
            handlePaletteExtracted(cached.artworkPalette)
        }
    }

    private func handleLikeToggle(for track: Track) {
        playlistManager.toggleLike(track: track)
        HapticFeedbackService.light()
    }

    private func openDevicesSheet() {
        dismissCalloutImmediately()
        devicesSheetDetent = .medium
        showDevicesSheet = true
        HapticFeedbackService.light()
    }

    private func togglePlayPause() {
        audioEngine.togglePlayPause()
        HapticFeedbackService.light()
    }

    private func playNext() {
        audioEngine.playNext()
        HapticFeedbackService.light()
    }

    private func dismissToMiniPlayer() {
        HapticFeedbackService.light()
        withAnimation(.spring(response: 0.38, dampingFraction: 0.88)) {
            updateProgress(1.0)
            isPresented = false
            dragOffset = 0
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(360))
            triggerDeviceCallout(reason: .playerDismissed)
        }
    }

    private func expandToFullPlayer() {
        dismissCalloutImmediately()
        HapticFeedbackService.medium()
        withAnimation(.spring(response: 0.40, dampingFraction: 0.86)) {
            updateProgress(0.0)
            isPresented = true
            dragOffset = 0
        }
    }

    private func bounceBackToFullPlayer() {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.84)) {
            updateProgress(0.0)
            dragOffset = 0
        }
    }

    // MARK: - Spotify-Style Device Callout Methods

    private enum CalloutTriggerReason {
        case appOpen
        case playerDismissed
        case tabChanged
        case deviceChanged
    }

    private func triggerDeviceCallout(reason: CalloutTriggerReason) {
        // 1. Only show if an external device is connected (Castlie Connect Mac, Bluetooth speaker, AirPods, AirPlay)
        guard isExternalDevice else {
            if isCalloutVisible {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    isCalloutVisible = false
                }
            }
            return
        }

        // 2. Only show when resting in Mini Player mode (p > 0.8) and full player is not presented
        guard p > 0.8, !isPresented else { return }

        let now = Date()
        let timeSinceLast = now.timeIntervalSince(lastCalloutShowTime)

        // 3. Spotify-style frequency throttling ("через раз" / non-intrusive)
        switch reason {
        case .deviceChanged:
            // Immediate announcement when device actually switches (short cooldown)
            guard timeSinceLast > 3 else { return }

        case .playerDismissed:
            // When closing full player: show if at least 12 seconds have passed
            guard timeSinceLast > 12 else { return }

        case .appOpen:
            // When opening the app or returning to foreground: show if at least 15 seconds have passed
            guard timeSinceLast > 15 else { return }

        case .tabChanged:
            // When switching tabs: alternate ("через раз") with 20s cooldown
            tabChangeCounter += 1
            guard tabChangeCounter % 2 == 1, timeSinceLast > 20 else { return }
        }

        lastCalloutShowTime = now
        calloutDismissTask?.cancel()

        withAnimation(.spring(response: 0.38, dampingFraction: 0.74)) {
            isCalloutVisible = true
        }

        // Auto-dismiss after 3.8 seconds with smooth exit animation
        calloutDismissTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3.8))
            if !Task.isCancelled {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                    isCalloutVisible = false
                }
            }
        }
    }

    private func dismissCalloutImmediately() {
        calloutDismissTask?.cancel()
        calloutDismissTask = nil
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            isCalloutVisible = false
        }
    }

    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat {
        a + (b - a) * t
    }
}

// MARK: - Dedicated Subviews

private struct FullPlayerHeaderView: View {
    let isPlaying: Bool
    let isRemoteActive: Bool
    let deviceSymbol: String
    let onDismiss: () -> Void
    let onDevicePicker: () -> Void

    var body: some View {
        HStack {
            // Dismiss button
            Button(action: onDismiss) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(ThemeManager.shared.secondaryText)
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.88))

            Spacer()

            // "Now Playing" pill
            nowPlayingBadge

            Spacer()

            // Device picker button
            Button(action: onDevicePicker) {
                Image(systemName: deviceSymbol)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isRemoteActive ? ThemeManager.shared.accent : ThemeManager.shared.secondaryText)
                    .frame(width: 40, height: 40)
                    .background(
                        isRemoteActive
                        ? ThemeManager.shared.accent.opacity(0.18)
                        : Color.white.opacity(0.08)
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.88))
        }
    }

    private var nowPlayingBadge: some View {
        HStack(spacing: 8) {
            AnimatedWaveform(
                isPlaying: isPlaying,
                color: ThemeManager.shared.accent,
                barCount: 4,
                maxHeight: 12
            )
            Text("Зараз грає")
                .font(AppFonts.caption)
                .fontWeight(.medium)
                .foregroundStyle(ThemeManager.shared.secondaryText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.08))
        .clipShape(Capsule())
    }
}

private struct FullPlayerTrackInfoView: View {
    let track: Track
    let isLiked: Bool
    let onLikeToggle: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(track.name)
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .foregroundStyle(ThemeManager.shared.primaryText)
                    .lineLimit(1)

                Text(track.artistName)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundStyle(ThemeManager.shared.secondaryText)
                    .lineLimit(1)
            }

            Spacer()

            Button(action: onLikeToggle) {
                Image(systemName: isLiked ? "heart.fill" : "heart")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(isLiked ? Color(hex: "FF3B30") : ThemeManager.shared.secondaryText.opacity(0.8))
                    .frame(width: 44, height: 44)
                    .background(
                        isLiked ? Color(hex: "FF3B30").opacity(0.14) : Color.white.opacity(0.08)
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.86))
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isLiked)
        }
    }
}

private struct FullPlayerDeviceBar: View {
    let deviceName: String
    let deviceSymbol: String
    let isHighlighted: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Image(systemName: deviceSymbol)
                    .font(.callout)
                    .foregroundStyle(isHighlighted ? ThemeManager.shared.accent : ThemeManager.shared.secondaryText)

                Text("Грає на: \(deviceName)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(isHighlighted ? ThemeManager.shared.accent : ThemeManager.shared.primaryText)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ThemeManager.shared.secondaryText.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Equatable Ambient Mesh Backdrop (Isolated from gesture & layout state)

private struct FullPlayerAmbientBackdrop: View, Equatable {
    let palette: ArtworkPalette
    let width: CGFloat

    nonisolated static func == (lhs: FullPlayerAmbientBackdrop, rhs: FullPlayerAmbientBackdrop) -> Bool {
        lhs.palette == rhs.palette && lhs.width == rhs.width
    }

    var body: some View {
        ZStack {
            // Deep rich canvas base
            Color(hex: "08080C")

            // 1. Primary Vibrant Radial Glow (around artwork & top-left)
            RadialGradient(
                colors: [
                    palette.primary.opacity(0.85),
                    palette.primary.opacity(0.35),
                    Color.clear
                ],
                center: .init(x: 0.38, y: 0.28),
                startRadius: 20,
                endRadius: width * 0.95
            )

            // 2. Secondary Harmonic Radial Glow (mid-right / behind controls)
            RadialGradient(
                colors: [
                    palette.secondary.opacity(0.68),
                    palette.secondary.opacity(0.22),
                    Color.clear
                ],
                center: .init(x: 0.76, y: 0.46),
                startRadius: 30,
                endRadius: width * 0.85
            )

            // 3. Subtle third depth orb (bottom left accent bounce)
            RadialGradient(
                colors: [
                    palette.primary.opacity(0.40),
                    Color.clear
                ],
                center: .init(x: 0.20, y: 0.65),
                startRadius: 10,
                endRadius: width * 0.70
            )

            // 4. Atmospheric linear gradient with deep dark vignette at bottom for perfect readability
            LinearGradient(
                colors: [
                    palette.primary.opacity(0.35),
                    Color.clear,
                    Color(hex: "08080C").opacity(0.75),
                    Color(hex: "08080C")
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }
}
