import AppKit
import SwiftUI

struct MenuBarView: View {
    @Bindable var receiver: MacReceiverService
    
    var body: some View {
        VStack(spacing: 12) {
            // MARK: - Header: Connection Status & Sender
            HStack(spacing: 8) {
                Circle()
                    .fill(receiver.isConnectedToServer ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                
                VStack(alignment: .leading, spacing: 1) {
                    Text("Castlie Connect")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.primary)
                    
                    if let user = receiver.connectedUser {
                        Text("Підключено: \(user)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    } else {
                        Text(receiver.isConnectedToServer ? "Очікування підключення..." : "Підключення до сервера...")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                Text("\(Int(receiver.volume * 100))%")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 2)
            
            Divider()
            
            // MARK: - Now Playing (Super Minimal)
            if let track = receiver.currentTrack {
                HStack(spacing: 10) {
                    // Album Art
                    if let artUrl = track.albumArtURL, let url = URL(string: artUrl) {
                        AsyncImage(url: url) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Color.gray.opacity(0.3)
                        }
                        .frame(width: 42, height: 42)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.orange.opacity(0.15))
                            Image(systemName: "music.note")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.orange)
                        }
                        .frame(width: 42, height: 42)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.name)
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                            .foregroundStyle(.primary)
                        
                        Text(track.artistName)
                            .font(.system(size: 11))
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                    }
                    
                    Spacer()
                    
                    // Play/Pause button
                    Button {
                        receiver.audioPlayer.togglePlayPause()
                    } label: {
                        Image(systemName: receiver.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 14))
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 2)
            } else {
                HStack {
                    Image(systemName: "hifispeaker.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                    Text("Немає активного треку")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.vertical, 4)
            }
            
            // MARK: - Minimal Volume Slider
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                
                Slider(
                    value: Binding(
                        get: { receiver.volume },
                        set: { receiver.updateVolume($0) }
                    ),
                    in: 0...1
                )
                .controlSize(.mini)
                
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // MARK: - Footer
            HStack {
                Text("castlie.dron.lol")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                
                Spacer()
                
                Button("Вийти") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.system(size: 10))
                .buttonStyle(.borderless)
            }
        }
        .padding(12)
        .frame(width: 260)
    }
}
