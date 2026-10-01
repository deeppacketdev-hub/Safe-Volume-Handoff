import SwiftUI

struct AlbumArtView: View {
    let track: Track
    var isPlaying: Bool = true
    var onColorExtracted: ((Color) -> Void)?
    
    var body: some View {
        AsyncImage(url: track.albumImageURL) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(
                        color: .black.opacity(isPlaying ? 0.45 : 0.2),
                        radius: isPlaying ? 24 : 10,
                        y: isPlaying ? 12 : 5
                    )
                    .scaleEffect(isPlaying ? 1.0 : 0.86)
                    .animation(.spring(response: 0.42, dampingFraction: 0.75), value: isPlaying)
                    .onAppear {
                        // Витягуємо домінантний колір
                        Task {
                            if let uiImage = await loadUIImage(from: track.albumImageURL) {
                                let color = uiImage.dominantColor
                                await MainActor.run {
                                    onColorExtracted?(color)
                                }
                            }
                        }
                    }
            case .failure:
                albumPlaceholder
            case .empty:
                albumPlaceholder
                    .overlay {
                        ProgressView()
                            .tint(ThemeManager.shared.accent)
                    }
            @unknown default:
                albumPlaceholder
            }
        }
        .frame(maxWidth: 320, maxHeight: 320)
        .padding(.horizontal, 32)
    }
    
    private var albumPlaceholder: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(ThemeManager.shared.cardBackground)
            .aspectRatio(1, contentMode: .fit)
            .scaleEffect(isPlaying ? 1.0 : 0.86)
            .animation(.spring(response: 0.42, dampingFraction: 0.75), value: isPlaying)
            .overlay {
                Image(systemName: "music.note")
                    .font(.system(size: 60))
                    .foregroundStyle(ThemeManager.shared.secondaryText)
            }
    }
    
    /// Завантажити UIImage з URL
    private func loadUIImage(from url: URL?) async -> UIImage? {
        guard let url else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            return UIImage(data: data)
        } catch {
            return nil
        }
    }
}

#Preview {
    AlbumArtView(
        track: Track(
            id: "1", name: "Test", artistName: "Artist",
            albumName: "Album", albumImageURL: nil, previewURL: nil,
            durationMs: 30000, popularity: 50
        )
    )
    .preferredColorScheme(.dark)
    .background(ThemeManager.shared.primaryBackground)
}
