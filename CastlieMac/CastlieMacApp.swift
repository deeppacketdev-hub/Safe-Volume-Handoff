import SwiftUI

@main
struct CastlieMacApp: App {
    @State private var receiver = MacReceiverService.shared
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView(receiver: receiver)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: receiver.isPlaying ? "waveform" : "hifispeaker.fill")
                if receiver.isPlaying, let track = receiver.currentTrack {
                    Text(track.name)
                        .font(.system(size: 11, weight: .medium))
                        .lineLimit(1)
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
