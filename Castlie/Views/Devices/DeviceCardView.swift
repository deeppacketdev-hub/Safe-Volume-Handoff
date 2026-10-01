import SwiftUI

struct DeviceCardView: View {
    let device: AudioDevice
    let onConnect: () -> Void
    
    @State private var safeVolume = SafeVolumeManager.shared
    
    private var volume: Float {
        device.lastKnownVolume ?? safeVolume.recommendedVolume(for: device)
    }
    
    private var safety: SafeVolumeManager.SafetyLevel {
        safeVolume.safetyLevel(for: volume)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Заголовок
            HStack(spacing: 12) {
                Image(systemName: device.type.sfSymbol)
                    .font(.title2)
                    .foregroundStyle(ThemeManager.shared.primaryText)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(device.name)
                        .font(AppFonts.headline)
                        .foregroundStyle(ThemeManager.shared.primaryText)
                    
                    HStack(spacing: 4) {
                        Text(device.connectionType.rawValue)
                        if let room = device.roomName {
                            Text("·")
                            Text(room)
                        }
                    }
                    .font(AppFonts.caption)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
                }
                
                Spacer()
            }
            
            // Остання гучність
            VStack(alignment: .leading, spacing: 6) {
                Text("Остання гучність: \(Int(volume * 100))%")
                    .font(AppFonts.caption)
                    .foregroundStyle(ThemeManager.shared.secondaryText)
                
                // Volume bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(ThemeManager.shared.secondaryBackground)
                            .frame(height: 6)
                        
                        Capsule()
                            .fill(safety.color)
                            .frame(width: max(0, min(geometry.size.width, geometry.size.width * CGFloat(volume))), height: 6)
                    }
                }
                .frame(height: 6)
            }
            
            // Попередження (якщо потрібно)
            if safety != .safe {
                SafetyIndicator(level: safety)
            }
            
            // Кнопка підключення
            Button {
                HapticFeedbackService.medium()
                onConnect()
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "slider.horizontal.3")
                        .font(.subheadline)
                    Text("Налаштувати безпечну гучність")
                        .font(AppFonts.headline)
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(safety.color.opacity(0.2))
                )
                .foregroundStyle(safety.color)
            }
            .buttonStyle(.plain)
        }
        .cardStyle()
    }
}

#Preview {
    VStack(spacing: 16) {
        DeviceCardView(
            device: AudioDevice(
                id: "1", name: "JBL Flip 6", type: .speaker,
                connectionType: .bluetooth, roomName: "Кімната",
                lastKnownVolume: 0.35
            ),
            onConnect: {}
        )
        
        DeviceCardView(
            device: AudioDevice(
                id: "2", name: "Samsung TV", type: .tv,
                connectionType: .airplay, roomName: "Вітальня",
                lastKnownVolume: 0.72
            ),
            onConnect: {}
        )
    }
    .padding()
    .preferredColorScheme(.dark)
    .background(ThemeManager.shared.primaryBackground)
}
