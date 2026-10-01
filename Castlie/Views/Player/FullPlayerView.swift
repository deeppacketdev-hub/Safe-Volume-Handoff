import SwiftUI

struct FullPlayerView: View {
    @Binding var isPresented: Bool
    @State private var audioEngine = AudioEngine.shared
    @State private var safeVolume = SafeVolumeManager.shared
    @State private var discovery = DeviceDiscoveryService.shared
    @State private var playlistManager = PlaylistManager.shared
    @State private var backgroundColor = Color(hex: "1F1F2C")
    @State private var showDevicesSheet = false
    
    // MARK: - Плавний інтерактивний Apple Music жест закриття
    @State private var dragOffset: CGFloat = 0
    @State private var isDismissing = false
    @State private var screenHeight: CGFloat = 852
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // MARK: - Головна картка плеєра (100% непрозора, монолітна, без дірок)
                VStack(spacing: 0) {
                    // Індикатор згортання (Apple Grabber Pill)
                    Capsule()
                        .fill(Color.white.opacity(0.35))
                        .frame(width: 36, height: 5)
                        .padding(.top, 12)
                        .padding(.bottom, 6)
                
                // Верхня панель (Кнопка закриття, статус, AirPlay)
                headerView
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                
                Spacer(minLength: 8)
                
                // MARK: - Обкладинка альбому з Apple Music анімацією (1.0 грає / 0.86 пауза)
                if let track = audioEngine.currentTrack {
                    AlbumArtView(
                        track: track,
                        isPlaying: audioEngine.isPlaying,
                        onColorExtracted: { color in
                            withAnimation(.easeInOut(duration: 0.6)) {
                                backgroundColor = color
                            }
                        }
                    )
                    .padding(.vertical, 4)
                }
                
                Spacer(minLength: 8)
                
                // MARK: - Інформація про трек + Like
                if let track = audioEngine.currentTrack {
                    trackInfoView(track: track)
                        .padding(.horizontal, 24)
                }
                
                // MARK: - Apple Music Scrubber / Прогрес
                ProgressBarView()
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                
                // MARK: - Контроли (Shuffle, Prev, Play/Pause, Next, Repeat)
                PlaybackControlsView()
                    .padding(.top, 12)
                
                // MARK: - Слайдер гучності (керує апаратною гучністю Mac, колонок, iPhone)
                VolumeSliderView()
                    .padding(.horizontal, 28)
                    .padding(.top, 16)
                
                // MARK: - Смужка активного пристрою (AirPlay / Castlie Connect)
                activeDeviceBar
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 34) // Заповнює область Home Indicator повністю без дірок
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // 100% непрозорий монолітний фон (повністю закриває екран пошуку)
            .background(
                LinearGradient(
                    colors: [
                        backgroundColor,
                        Color(hex: "0E0E16"),
                        Color(hex: "08080C")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: dragOffset > 0 ? min(36, 12 + dragOffset * 0.15) : 0,
                    style: .continuous
                )
            )
            .offset(y: max(0, dragOffset))
            .scaleEffect(max(0.88, 1.0 - (max(0, dragOffset) / 1600.0)))
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 || value.predictedEndTranslation.height > 250 {
                            dismissToMiniPlayer()
                        } else {
                            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            
            // MARK: - Панель аудіопристроїв (Edge-to-Edge, краї плеєра не стирчать)
            if showDevicesSheet {
                devicesOverlaySheet
            }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .ignoresSafeArea()
            .onAppear {
                screenHeight = geometry.size.height
            }
            .onChange(of: geometry.size.height) { _, newH in
                screenHeight = newH
            }
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Button {
                dismissToMiniPlayer()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(ThemeManager.shared.secondaryText)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.88))
            
            Spacer()
            
            HStack(spacing: 8) {
                AnimatedWaveform(
                    isPlaying: audioEngine.isPlaying,
                    color: ThemeManager.shared.accent,
                    barCount: 4
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
            
            Spacer()
            
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    showDevicesSheet = true
                }
                HapticFeedbackService.light()
            } label: {
                let isRemote = CastlieConnectService.shared.activeRemoteDevice != nil
                Image(systemName: isRemote ? "laptopcomputer" : (discovery.currentDevice?.type.sfSymbol ?? "airplayaudio"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        isRemote || (discovery.currentDevice?.type != .iPhone && discovery.currentDevice != nil)
                        ? ThemeManager.shared.accent
                        : ThemeManager.shared.secondaryText
                    )
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.88))
        }
    }
    
    private func trackInfoView(track: Track) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .font(.system(.title2, design: .rounded, weight: .bold))
                    .foregroundStyle(ThemeManager.shared.primaryText)
                    .lineLimit(1)
                
                Text(track.artistName)
                    .font(.system(.subheadline, design: .rounded, weight: .medium))
                    .foregroundStyle(ThemeManager.shared.secondaryText)
                    .lineLimit(1)
            }
            
            Spacer()
            
            Button {
                playlistManager.toggleLike(track: track)
                HapticFeedbackService.light()
            } label: {
                Image(systemName: playlistManager.isLiked(track: track) ? "heart.fill" : "heart")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(
                        playlistManager.isLiked(track: track)
                        ? Color(hex: "FF3B30")
                        : ThemeManager.shared.secondaryText.opacity(0.8)
                    )
                    .frame(width: 44, height: 44)
                    .background(
                        playlistManager.isLiked(track: track)
                        ? Color(hex: "FF3B30").opacity(0.14)
                        : Color.white.opacity(0.08)
                    )
                    .clipShape(Circle())
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.86))
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: playlistManager.isLiked(track: track))
        }
    }
    
    private var activeDeviceBar: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                showDevicesSheet = true
            }
            HapticFeedbackService.light()
        } label: {
            let activeRemote = CastlieConnectService.shared.activeRemoteDevice
            let isRemote = activeRemote != nil
            
            HStack(spacing: 8) {
                Image(systemName: isRemote ? "laptopcomputer" : (discovery.currentDevice?.type.sfSymbol ?? "speaker.wave.2.fill"))
                    .font(.callout)
                    .foregroundStyle(
                        isRemote || (discovery.currentDevice?.type != .iPhone && discovery.currentDevice != nil)
                        ? ThemeManager.shared.accent
                        : ThemeManager.shared.secondaryText
                    )
                
                Text(isRemote ? "Грає на: \(activeRemote?.name ?? "Mac")" : "Грає на: \(discovery.currentDevice?.name ?? "Цей iPhone")")
                    .font(.system(.caption, design: .rounded, weight: .medium))
                    .foregroundStyle(
                        isRemote || (discovery.currentDevice?.type != .iPhone && discovery.currentDevice != nil)
                        ? ThemeManager.shared.accent
                        : ThemeManager.shared.primaryText
                    )
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption2.bold())
                    .foregroundStyle(ThemeManager.shared.secondaryText)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
    
    private var devicesOverlaySheet: some View {
        ZStack(alignment: .bottom) {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        showDevicesSheet = false
                    }
                }
            
            VStack(spacing: 0) {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 36, height: 5)
                    .padding(.top, 12)
                    .padding(.bottom, 8)
                
                HStack {
                    Text("Аудіопристрої")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                        .foregroundStyle(ThemeManager.shared.primaryText)
                    
                    Spacer()
                    
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                            showDevicesSheet = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                
                Divider()
                    .background(Color.white.opacity(0.12))
                
                DevicesView()
            }
            .frame(maxWidth: .infinity)
            .frame(maxHeight: screenHeight * 0.82)
            .background(Color(hex: "161622"))
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: .black.opacity(0.55), radius: 30, y: -6)
            .transition(.move(edge: .bottom))
        }
        .ignoresSafeArea()
        .zIndex(30)
    }
    
    /// Плавне закриття з пружною анімацією ковзання вниз до міні-плеєра
    private func dismissToMiniPlayer() {
        guard !isDismissing else { return }
        isDismissing = true
        HapticFeedbackService.light()
        
        withAnimation(.spring(response: 0.36, dampingFraction: 0.85)) {
            dragOffset = screenHeight
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) {
            isPresented = false
            dragOffset = 0
            isDismissing = false
        }
    }
}

#Preview {
    FullPlayerView(isPresented: .constant(true))
        .preferredColorScheme(.dark)
}
