import SwiftUI

struct FullPlayerView: View {
    @Binding var isPresented: Bool
    @State private var audioEngine = AudioEngine.shared
    @State private var safeVolume = SafeVolumeManager.shared
    @State private var discovery = DeviceDiscoveryService.shared
    @State private var playlistManager = PlaylistManager.shared
    @State private var backgroundColor = Color(hex: "1A1A24")
    
    var body: some View {
        ZStack {
            // Адаптивний фон
            LinearGradient(
                colors: [backgroundColor, ThemeManager.shared.primaryBackground],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // Drag indicator + Close
                HStack {
                    Button {
                        isPresented = false
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.title3)
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        AnimatedWaveform(isPlaying: audioEngine.isPlaying, color: ThemeManager.shared.accent, barCount: 4)
                        Text("Зараз грає")
                            .font(AppFonts.caption)
                            .foregroundStyle(ThemeManager.shared.secondaryText)
                    }
                    
                    Spacer()
                    
                    // Пристрій
                    Image(systemName: discovery.currentDevice?.type.sfSymbol ?? "hifispeaker.fill")
                        .font(.title3)
                        .foregroundStyle(ThemeManager.shared.secondaryText)
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Обкладинка
                if let track = audioEngine.currentTrack {
                    AlbumArtView(track: track, onColorExtracted: { color in
                        withAnimation(.easeInOut(duration: 0.5)) {
                            backgroundColor = color
                        }
                    })
                }
                
                // Інформація про трек
                if let track = audioEngine.currentTrack {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(track.name)
                                .font(AppFonts.title2)
                                .foregroundStyle(ThemeManager.shared.primaryText)
                                .lineLimit(1)
                            
                            Text(track.artistName)
                                .font(AppFonts.body)
                                .foregroundStyle(ThemeManager.shared.secondaryText)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                        
                        Button {
                            playlistManager.toggleLike(track: track)
                        } label: {
                            Image(systemName: playlistManager.isLiked(track: track) ? "heart.fill" : "heart")
                                .font(.title2)
                                .foregroundStyle(
                                    playlistManager.isLiked(track: track)
                                    ? ThemeManager.shared.accent
                                    : ThemeManager.shared.secondaryText
                                )
                                .frame(width: 44, height: 44)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                
                // Прогрес-бар
                ProgressBarView()
                    .padding(.horizontal)
                
                // Контроли
                PlaybackControlsView()
                
                // Повзунок гучності
                VolumeSliderView()
                    .padding(.horizontal, 24)
                
                Spacer()
            }
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    // Свайп вниз → закрити
                    if value.translation.height > 100 {
                        isPresented = false
                    }
                }
        )
    }
}

#Preview {
    FullPlayerView(isPresented: .constant(true))
        .preferredColorScheme(.dark)
}
