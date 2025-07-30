import SwiftUI

struct PreviewScaleSlider: View {
    @Binding var scale: CGFloat

    var body: some View {
        Slider(value: $scale, in: 0.8...3)
            .frame(width: 150)
    }
}

#if DEBUG
#Preview {
    PreviewScaleSlider(scale: .constant(1.0))
}
#endif
