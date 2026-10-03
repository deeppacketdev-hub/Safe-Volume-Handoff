import SwiftUI

struct MiniPlayerView: View {
    // MARK: - Properties
    @Binding var showFullPlayer: Bool
    var animationNamespace: Namespace.ID

    @State private var audioEngine = AudioEngine.shared
    @State private var discovery = DeviceDiscoveryService.shared
    @State private var connectService = CastlieConnectService.shared
    @State private var showDevicesSheet = false
    @State private var devicesSheetDetent: PresentationDetent = .medium

    private var isRemoteActive: Bool {
        connectService.activeRemoteDevice != nil
    }

    private var activeDeviceSymbol: String {
        if isRemoteActive {
            return "laptopcomputer"
        }
        return discovery.currentDevice?.type.sfSymbol ?? "airplayaudio"
    }

    // MARK: - Body
    var body: some View {
        if let track = audioEngine.currentTrack {
            miniPlayerSurface(track: track)
                .padding(.horizontal, 16)
                .sheet(isPresented: $showDevicesSheet) {
                    DevicesView(currentDetent: $devicesSheetDetent)
                        .presentationDetents([.medium, .large], selection: $devicesSheetDetent)
                        .presentationDragIndicator(.visible)
                }
        }
    }

    // MARK: - Liquid Glass Mini Player Surface

    @ViewBuilder
    private func miniPlayerSurface(track: Track) -> some View {
        if #available(iOS 26, *) {
            GlassEffectContainer(spacing: 8) {
                miniPlayerCardContent(track: track)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .glassEffectID("miniPlayerCard", in: animationNamespace)
            }
            .matchedGeometryEffect(id: "playerCardSurface", in: animationNamespace)
            .shadow(color: Color.black.opacity(0.32), radius: 18, x: 0, y: 8)
            .shadow(color: ThemeManager.shared.accent.opacity(0.14), radius: 10, x: 0, y: 2)
        } else {
            miniPlayerCardContent(track: track)
                .background(
                    liquidGlassBackground
                        .matchedGeometryEffect(id: "playerCardSurface", in: animationNamespace)
                )
                .clipShape(Capsule())
                .overlay(liquidGlassRim)
                .shadow(color: Color.black.opacity(0.32), radius: 18, x: 0, y: 8)
                .shadow(color: ThemeManager.shared.accent.opacity(0.14), radius: 10, x: 0, y: 2)
        }
    }

    @ViewBuilder
    private func miniPlayerCardContent(track: Track) -> some View {
        ZStack(alignment: .bottom) {
            // Main content row
            HStack(spacing: 10) {
                // Morphing Album Art
                MiniPlayerArtwork(track: track, isPlaying: audioEngine.isPlaying)
                    .matchedGeometryEffect(id: "playerArtworkHero", in: animationNamespace)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: openFullPlayer)

                // Track Info & Waveform
                let isExternal = isRemoteActive || (discovery.currentDevice?.type != .iPhone && discovery.currentDevice != nil)
                let activeName = isRemoteActive ? (connectService.activeRemoteDevice?.name ?? "") : (discovery.currentDevice?.name ?? "")

                MiniPlayerTrackInfo(
                    track: track,
                    isPlaying: audioEngine.isPlaying,
                    isExternalDevice: isExternal,
                    deviceName: activeName,
                    deviceSymbol: activeDeviceSymbol
                )
                .contentShape(Rectangle())
                .onTapGesture(perform: openFullPlayer)

                Spacer(minLength: 4)

                // Apple Controls + Castlie Connect Quick Button
                MiniPlayerControls(
                    isPlaying: audioEngine.isPlaying,
                    isRemoteActive: isExternal,
                    deviceSymbol: activeDeviceSymbol,
                    onCastlieConnect: openDevicesSheet,
                    onPlayPause: togglePlayPause,
                    onNext: playNext
                )
            }
            .padding(.leading, 8)
            .padding(.trailing, 10)
            .frame(height: 56)

            // Inset Progress Bar along the flat bottom edge
            MiniPlayerProgressTrack()
        }
        .frame(height: 56)
    }

    private var liquidGlassBackground: some View {
        ZStack {
            Capsule()
                .fill(.ultraThinMaterial)

            // Dynamic ambient glass luminance (Apple Liquid Glass frosted refraction)
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.16),
                            Color.white.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Delicate tinted layer ensuring high contrast for text over any background while maintaining translucent glass refraction
            Capsule()
                .fill(Color(hex: "12121A").opacity(0.40))
        }
    }

    private var liquidGlassRim: some View {
        Capsule()
            .stroke(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.45),
                        Color.white.opacity(0.12)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 0.8
            )
    }

    // MARK: - Actions

    private func openFullPlayer() {
        showFullPlayer = true
        HapticFeedbackService.light()
    }

    private func openDevicesSheet() {
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
}

// MARK: - Reusable MiniPlayer Subviews

struct MiniPlayerArtwork: View {
    let track: Track
    let isPlaying: Bool

    var body: some View {
        AsyncImage(url: track.albumImageURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(ThemeManager.shared.secondaryBackground)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 13))
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                }
        }
        .frame(width: 40, height: 40)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.2), radius: 3, y: 1)
        .scaleEffect(isPlaying ? 1.0 : 0.92)
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isPlaying)
    }
}

struct MiniPlayerTrackInfo: View {
    let track: Track
    let isPlaying: Bool
    var isExternalDevice: Bool = false
    var deviceName: String = ""
    var deviceSymbol: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(track.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ThemeManager.shared.primaryText)
                    .lineLimit(1)

                if isPlaying {
                    AnimatedWaveform(
                        isPlaying: isPlaying,
                        color: ThemeManager.shared.accent,
                        barCount: 3,
                        maxHeight: 11
                    )
                }
            }

            if isExternalDevice && !deviceName.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: deviceSymbol.isEmpty ? "speaker.wave.2.fill" : deviceSymbol)
                        .font(.system(size: 10, weight: .bold))
                    Text(deviceName)
                        .font(.system(size: 12, weight: .semibold))
                        .lineLimit(1)
                }
                .foregroundStyle(ThemeManager.shared.accent)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                Text(track.artistName)
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(ThemeManager.shared.secondaryText)
                    .lineLimit(1)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.22), value: isExternalDevice)
        .animation(.easeInOut(duration: 0.22), value: deviceName)
    }
}

struct MiniPlayerControls: View {
    let isPlaying: Bool
    let isRemoteActive: Bool
    let deviceSymbol: String
    let onCastlieConnect: () -> Void
    let onPlayPause: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            // 1. Castlie Connect / AirPlay Quick Button
            Button(action: onCastlieConnect) {
                Image(systemName: deviceSymbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(isRemoteActive ? ThemeManager.shared.accent : ThemeManager.shared.secondaryText)
                    .frame(width: 32, height: 32)
                    .background(
                        isRemoteActive
                        ? ThemeManager.shared.accent.opacity(0.18)
                        : Color.white.opacity(0.06)
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(MiniPlayerScaleButtonStyle())

            // 2. Play / Pause — Apple Music style
            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(ThemeManager.shared.primaryText)
                    .frame(width: 34, height: 34)
                    .contentShape(Rectangle())
            }
            .buttonStyle(MiniPlayerScaleButtonStyle())

            // 3. Next Track — Apple Music muted secondary style
            Button(action: onNext) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(ThemeManager.shared.secondaryText)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(MiniPlayerScaleButtonStyle())
        }
    }
}

// MARK: - Spotify-Style Floating Device Callout & Arrow

struct SpotifyDeviceCalloutView: View {
    let deviceName: String
    let deviceSymbol: String
    let onChange: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // 1. Device Icon Badge
            ZStack {
                Circle()
                    .fill(ThemeManager.shared.accent.opacity(0.18))
                    .frame(width: 22, height: 22)

                Image(systemName: deviceSymbol.isEmpty ? "speaker.wave.2.fill" : deviceSymbol)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ThemeManager.shared.accent)
            }

            // 2. Callout Label: "Слухайте на [Device]"
            HStack(spacing: 4) {
                Text("Слухайте на")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(ThemeManager.shared.secondaryText)

                Text(deviceName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(ThemeManager.shared.primaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            // 3. "Змінити" Action Button
            Button(action: onChange) {
                Text("Змінити")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(ThemeManager.shared.accent)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(ThemeManager.shared.accent.opacity(0.14))
                    .clipShape(Capsule())
            }
            .buttonStyle(MiniPlayerScaleButtonStyle())
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 15) // 8pt padding + 7pt beak height = 15pt
        .frame(maxWidth: 320)
        .background(
            CalloutBubbleShape(cornerRadius: 13, beakWidth: 14, beakHeight: 7)
                .fill(Color(hex: "181822").opacity(0.96))
                .overlay(
                    CalloutBubbleShape(cornerRadius: 13, beakWidth: 14, beakHeight: 7)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.24),
                                    Color.white.opacity(0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.8
                        )
                )
        )
        .shadow(color: Color.black.opacity(0.42), radius: 14, x: 0, y: 5)
        .shadow(color: ThemeManager.shared.accent.opacity(0.15), radius: 8, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture {
            onChange()
        }
    }
}

/// Seamless bubble shape with an integrated downward pointing triangle beak for Spotify-style callout
struct CalloutBubbleShape: Shape {
    var cornerRadius: CGFloat = 13
    var beakWidth: CGFloat = 14
    var beakHeight: CGFloat = 7
    var beakPosition: CGFloat = 0.5 // 0.0 to 1.0 (centered at 0.5)

    func path(in rect: CGRect) -> Path {
        let bubbleBottom = rect.maxY - beakHeight
        let r = min(cornerRadius, min(rect.width / 2, bubbleBottom / 2))
        let beakCenter = rect.minX + (rect.width * beakPosition)
        let beakLeft = max(rect.minX + r + 2, min(rect.maxX - r - beakWidth - 2, beakCenter - beakWidth / 2))
        let beakRight = beakLeft + beakWidth
        let beakTipX = beakLeft + beakWidth / 2

        var path = Path()
        // Top-left starting point
        path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
        // Top edge
        path.addLine(to: CGPoint(x: rect.maxX - r, y: rect.minY))
        // Top-right corner
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: rect.minY),
            tangent2End: CGPoint(x: rect.maxX, y: rect.minY + r),
            radius: r
        )
        // Right edge
        path.addLine(to: CGPoint(x: rect.maxX, y: bubbleBottom - r))
        // Bottom-right corner
        path.addArc(
            tangent1End: CGPoint(x: rect.maxX, y: bubbleBottom),
            tangent2End: CGPoint(x: rect.maxX - r, y: bubbleBottom),
            radius: r
        )
        // Bottom edge to beak right
        path.addLine(to: CGPoint(x: beakRight, y: bubbleBottom))
        // Beak right slope down to tip
        path.addLine(to: CGPoint(x: beakTipX, y: rect.maxY))
        // Beak left slope up to bubble bottom
        path.addLine(to: CGPoint(x: beakLeft, y: bubbleBottom))
        // Bottom edge to bottom-left corner
        path.addLine(to: CGPoint(x: rect.minX + r, y: bubbleBottom))
        // Bottom-left corner
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: bubbleBottom),
            tangent2End: CGPoint(x: rect.minX, y: bubbleBottom - r),
            radius: r
        )
        // Left edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + r))
        // Top-left corner
        path.addArc(
            tangent1End: CGPoint(x: rect.minX, y: rect.minY),
            tangent2End: CGPoint(x: rect.minX + r, y: rect.minY),
            radius: r
        )
        path.closeSubpath()
        return path
    }
}

/// Bottom contour shape following the curvature of the mini player capsule,
/// extended slightly above the mid-point so that the beveled cut cleanly slices it.
struct MiniPlayerBottomContour: Shape {
    var cornerRadius: CGFloat = 26.5

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = min(cornerRadius, rect.height / 2)
        let cy = rect.midY
        let cxLeft = rect.minX + r
        let cxRight = rect.maxX - r

        // Start 12 degrees above 180° (at 192°) so the line has solid body across the bevel cut
        path.addArc(
            center: CGPoint(x: cxLeft, y: cy),
            radius: r,
            startAngle: .degrees(192),
            endAngle: .degrees(90),
            clockwise: true
        )
        // Straight line across the bottom edge
        path.addLine(to: CGPoint(x: cxRight, y: cy + r))
        // Curve around bottom-right corner up to -12° (symmetrical extension)
        path.addArc(
            center: CGPoint(x: cxRight, y: cy),
            radius: r,
            startAngle: .degrees(90),
            endAngle: .degrees(-12),
            clockwise: true
        )
        return path
    }
}

/// Slices the start (and end) of the contour at an exact diagonal angle (скошений зріз)
struct MiniPlayerBevelMask: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let yBevel = rect.midY
        let bevelDY: CGFloat = 4.5
        let bevelDX: CGFloat = 6.0

        // Left bevel cut: diagonal slice from outer top to inner bottom (скошений кут)
        let pOutLeft = CGPoint(x: rect.minX - 4, y: yBevel - bevelDY)
        let pInLeft = CGPoint(x: rect.minX + bevelDX, y: yBevel + bevelDY)

        // Right bevel cut: symmetrical diagonal slice from inner bottom to outer top
        let pInRight = CGPoint(x: rect.maxX - bevelDX, y: yBevel + bevelDY)
        let pOutRight = CGPoint(x: rect.maxX + 4, y: yBevel - bevelDY)

        p.move(to: pOutLeft)
        p.addLine(to: pInLeft)
        p.addLine(to: pInRight)
        p.addLine(to: pOutRight)
        p.addLine(to: CGPoint(x: rect.maxX + 20, y: rect.maxY + 20))
        p.addLine(to: CGPoint(x: rect.minX - 20, y: rect.maxY + 20))
        p.closeSubpath()
        return p
    }
}

struct MiniPlayerProgressTrack: View {
    @State private var audioEngine = AudioEngine.shared
    @State private var displayProgress: CGFloat = 0.0

    var body: some View {
        GeometryReader { geo in
            let targetProgress = max(0.0, min(1.0, CGFloat(audioEngine.progress)))
            let insetRect = geo.frame(in: .local).insetBy(dx: 1.5, dy: 1.5)
            let radius = insetRect.height / 2

            ZStack {
                // 1. Faint frosted glass contour guide along bottom capsule rim with beveled ends
                MiniPlayerBottomContour(cornerRadius: radius)
                    .stroke(
                        Color.white.opacity(0.08),
                        style: StrokeStyle(lineWidth: 2.2, lineCap: .butt)
                    )
                    .mask(MiniPlayerBevelMask())

                // 2. Active fluid flowing progress contour (beveled start, smooth moving playhead)
                if displayProgress > 0.001 {
                    MiniPlayerBottomContour(cornerRadius: radius)
                        .trim(from: 0.0, to: displayProgress)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    ThemeManager.shared.accent.opacity(0.85),
                                    ThemeManager.shared.accent
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(lineWidth: 2.6, lineCap: .round)
                        )
                        .mask(MiniPlayerBevelMask())
                        .shadow(color: ThemeManager.shared.accent.opacity(0.48), radius: 3, x: 0, y: 0)
                }
            }
            .frame(width: insetRect.width, height: insetRect.height)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .onAppear {
                displayProgress = targetProgress
            }
            .onChange(of: audioEngine.progress) { _, newProgress in
                let target = max(0.0, min(1.0, CGFloat(newProgress)))
                let jump = abs(target - displayProgress)
                if jump > 0.05 {
                    // Seeking / track skip: quick smooth spring
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        displayProgress = target
                    }
                } else {
                    // Continuous playback: buttery smooth 120 FPS interpolation without any teleporting
                    withAnimation(.linear(duration: 0.12)) {
                        displayProgress = target
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

struct MiniPlayerScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.86 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    PreviewContainer()
}

private struct PreviewContainer: View {
    @Namespace var previewNamespace

    var body: some View {
        ZStack {
            ThemeManager.shared.primaryBackground
                .ignoresSafeArea()

            VStack {
                Spacer()
                MiniPlayerView(
                    showFullPlayer: .constant(false),
                    animationNamespace: previewNamespace
                )
                .padding(.bottom, 50)
            }
        }
        .preferredColorScheme(.dark)
    }
}
