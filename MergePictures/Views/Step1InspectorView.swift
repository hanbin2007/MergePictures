import SwiftUI
#if os(iOS)
import PhotosUI

struct Step1InspectorView: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        ControlsFormView(viewModel: viewModel)
            .navigationTitle("Controls")
    }
}
#endif
