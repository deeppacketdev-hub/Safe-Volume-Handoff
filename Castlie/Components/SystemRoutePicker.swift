import AVKit
import SwiftUI

/// Системна кнопка вибору аудіовиходу (AirPlay / Bluetooth).
/// Це єдиний дозволений iOS спосіб перемкнути звук на конкретний пристрій.
struct SystemRoutePicker: UIViewRepresentable {
    var showsGlyph = false
    var onWillPresent: () -> Void = {}
    var onDidDismiss: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.delegate = context.coordinator
        picker.prioritizesVideoDevices = false
        picker.backgroundColor = .clear
        return picker
    }

    func updateUIView(_ picker: AVRoutePickerView, context: Context) {
        context.coordinator.onWillPresent = onWillPresent
        context.coordinator.onDidDismiss = onDidDismiss
        let color = showsGlyph ? UIColor.white : UIColor.clear
        picker.tintColor = color
        picker.activeTintColor = showsGlyph ? UIColor(Theme.accent) : .clear
    }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency AVRoutePickerViewDelegate {
        var onWillPresent: () -> Void = {}
        var onDidDismiss: () -> Void = {}

        func routePickerViewWillBeginPresentingRoutes(_ routePickerView: AVRoutePickerView) {
            HapticFeedbackService.light()
            onWillPresent()
        }

        func routePickerViewDidEndPresentingRoutes(_ routePickerView: AVRoutePickerView) {
            onDidDismiss()
        }
    }
}

extension View {
    /// Робить усю область view кнопкою системного меню AirPlay/Bluetooth.
    func opensSystemRoutePicker(
        accessibilityLabel: String,
        onWillPresent: @escaping () -> Void = {},
        onDidDismiss: @escaping () -> Void = {}
    ) -> some View {
        self
            .accessibilityHidden(true)
            .overlay {
                SystemRoutePicker(onWillPresent: onWillPresent, onDidDismiss: onDidDismiss)
                    .accessibilityLabel(accessibilityLabel)
            }
    }
}

/// Індикатор "зараз грає" — анімований символ замість покадрової анімації.
struct NowPlayingIndicator: View {
    let isPlaying: Bool
    var color: Color = Theme.accent

    var body: some View {
        Image(systemName: "waveform")
            .font(.footnote.weight(.bold))
            .foregroundStyle(color)
            .symbolEffect(.variableColor.iterative.dimInactiveLayers, isActive: isPlaying)
            .accessibilityLabel(isPlaying ? "Зараз грає" : "На паузі")
    }
}
