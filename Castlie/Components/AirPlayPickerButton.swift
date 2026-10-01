import AVKit
import SwiftUI

struct AirPlayPickerButton: UIViewRepresentable {
    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.tintColor = UIColor(ThemeManager.shared.accent)
        picker.activeTintColor = UIColor(ThemeManager.shared.accent)
        picker.prioritizesVideoDevices = false
        return picker
    }
    
    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        uiView.tintColor = UIColor(ThemeManager.shared.accent)
        uiView.activeTintColor = UIColor(ThemeManager.shared.accent)
    }
}

#Preview {
    AirPlayPickerButton()
        .frame(width: 44, height: 44)
        .padding()
        .preferredColorScheme(.dark)
        .background(ThemeManager.shared.primaryBackground)
}
