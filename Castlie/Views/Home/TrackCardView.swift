import SwiftUI

struct TrackCardView: View {
    let track: Track
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Обкладинка
                AsyncImage(url: track.albumImageURL) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(ThemeManager.shared.cardBackground)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.title2)
                                .foregroundStyle(ThemeManager.shared.secondaryText)
                        }
                }
                .frame(width: 140, height: 140)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                
                Text(track.name)
                    .font(AppFonts.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(ThemeManager.shared.primaryText)
                    .lineLimit(1)
                
                Text(track.artistName)
                    .font(AppFonts.caption)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
                    .lineLimit(1)
            }
            .frame(width: 140)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TrackCardView(
        track: Track(
            id: "preview",
            name: "Sample Track",
            artistName: "Sample Artist",
            albumName: "Sample Album",
            albumImageURL: nil,
            previewURL: nil,
            durationMs: 200000,
            popularity: 80
        ),
        onTap: {}
    )
    .preferredColorScheme(.dark)
    .padding()
    .background(ThemeManager.shared.primaryBackground)
}
