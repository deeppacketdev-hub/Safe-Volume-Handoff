import SwiftUI

/// Банер угорі екрана: результат Safe Volume Handoff або повідомлення плеєра.
private struct StatusBannerModifier: ViewModifier {
    struct Banner: Equatable, Identifiable {
        let id = UUID()
        let symbol: String
        let title: String
        var subtitle: String?
        var tint: Color = Theme.accent
    }

    @State private var banner: Banner?
    @State private var hideTask: Task<Void, Never>?

    private let discovery = DeviceDiscoveryService.shared
    private let engine = AudioEngine.shared

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let banner {
                    BannerView(banner: banner)
                        .id(banner.id)
                        .padding(.top, 6)
                        .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9, anchor: .top)))
                        .onTapGesture { hide() }
                }
            }
            .animation(.spring(duration: 0.45, bounce: 0.3), value: banner)
            .onChange(of: discovery.lastHandoff) { _, event in
                guard let event else { return }
                let level = SafeVolumeManager.shared.safetyLevel(for: event.volume, type: event.device.type)
                show(Banner(
                    symbol: event.device.symbol,
                    title: event.device.name,
                    subtitle: "Безпечна гучність \(Format.percent(event.volume))",
                    tint: level.color
                ))
            }
            .onChange(of: engine.notice) { _, notice in
                guard let notice else { return }
                show(Banner(symbol: notice.symbol, title: notice.message, tint: Theme.accent))
            }
    }

    private func show(_ newBanner: Banner) {
        banner = newBanner
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            banner = nil
        }
    }

    private func hide() {
        hideTask?.cancel()
        banner = nil
    }

    private struct BannerView: View {
        let banner: Banner

        var body: some View {
            HStack(spacing: 12) {
                Image(systemName: banner.symbol)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(banner.tint)
                    .frame(width: 30)
                    .symbolEffect(.bounce, value: banner.id)

                VStack(alignment: .leading, spacing: 1) {
                    Text(banner.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if let subtitle = banner.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 20)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)
            .padding(.horizontal, 24)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isStaticText)
        }
    }
}

extension View {
    func statusBanners() -> some View {
        modifier(StatusBannerModifier())
    }
}
