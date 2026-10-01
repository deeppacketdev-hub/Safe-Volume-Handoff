import SwiftUI

struct MiniPlayerView: View {
    @Binding var showFullPlayer: Bool
    @State private var audioEngine = AudioEngine.shared
    @State private var discovery = DeviceDiscoveryService.shared
    @State private var showDevicesSheet = false
    
    var body: some View {
        if let track = audioEngine.currentTrack {
            ZStack(alignment: .bottom) {
                // MARK: - Основна картка Apple Music
                HStack(spacing: 12) {
                    artworkView(track: track)
                    trackInfo(track: track)
                    controlsView
                }
                .padding(.leading, 8)
                .padding(.trailing, 10)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
                .onTapGesture {
                    showFullPlayer = true
                    HapticFeedbackService.light()
                }
                
                // MARK: - Тонкий Apple Music прогрес-бар
                GeometryReader { geo in
                    progressBar(width: geo.size.width)
                }
                .frame(height: 2.5)
            }
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: Color.black.opacity(0.28), radius: 16, x: 0, y: 6)
            .padding(.horizontal, 12)
            .sheet(isPresented: $showDevicesSheet) {
                DevicesView()
                    .presentationDetents([.medium, .large])
            }
        }
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func artworkView(track: Track) -> some View {
        AsyncImage(url: track.albumImageURL) { image in
            image
                .resizable()
                .aspectRatio(contentMode: .fill)
        } placeholder: {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(ThemeManager.shared.cardBackground)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.subheadline)
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 4, y: 2)
        .scaleEffect(audioEngine.isPlaying ? 1.0 : 0.88)
        .animation(.spring(response: 0.35, dampingFraction: 0.72), value: audioEngine.isPlaying)
    }
    
    @ViewBuilder
    private func trackInfo(track: Track) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(track.name)
                .font(.system(.subheadline, design: .rounded, weight: .semibold))
                .foregroundStyle(ThemeManager.shared.primaryText)
                .lineLimit(1)
            
            Text(track.artistName)
                .font(.system(.caption, design: .rounded, weight: .regular))
                .foregroundStyle(ThemeManager.shared.secondaryText)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    @ViewBuilder
    private var controlsView: some View {
        HStack(spacing: 4) {
            // AirPlay / Castlie Connect
            Button {
                showDevicesSheet = true
                HapticFeedbackService.light()
            } label: {
                let isRemote = CastlieConnectService.shared.activeRemoteDevice != nil
                Image(systemName: isRemote ? "laptopcomputer" : (discovery.currentDevice?.type.sfSymbol ?? "airplayaudio"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(
                        isRemote || (discovery.currentDevice?.type != .iPhone && discovery.currentDevice != nil)
                        ? ThemeManager.shared.accent
                        : ThemeManager.shared.secondaryText
                    )
                    .frame(width: 36, height: 44)
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.88))
            
            // Play / Pause
            Button {
                audioEngine.togglePlayPause()
                HapticFeedbackService.light()
            } label: {
                Image(systemName: audioEngine.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 21, weight: .semibold))
                    .foregroundStyle(ThemeManager.shared.primaryText)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.86))
            
            // Next
            Button {
                audioEngine.playNext()
                HapticFeedbackService.light()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(ThemeManager.shared.primaryText)
                    .frame(width: 40, height: 44)
            }
            .buttonStyle(ScaleButtonStyle(scale: 0.88))
        }
    }
    
    @ViewBuilder
    private func progressBar(width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 2.5)
            
            Rectangle()
                .fill(ThemeManager.shared.accent)
                .frame(
                    width: width * max(0, min(1, audioEngine.progress)),
                    height: 2.5
                )
        }
    }
    
    @ViewBuilder
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: "1C1C24").opacity(0.72))
            )
    }
}

#Preview {
    ZStack {
        ThemeManager.shared.primaryBackground
            .ignoresSafeArea()
        
        VStack {
            Spacer()
            MiniPlayerView(showFullPlayer: .constant(false))
                .padding(.bottom, 50)
        }
    }
    .preferredColorScheme(.dark)
}
