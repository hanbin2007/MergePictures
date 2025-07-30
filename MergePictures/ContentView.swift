import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: AppViewModel
    @State private var sidebarWidth: CGFloat = 200

    init(viewModel: AppViewModel = AppViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                ImageSidebarView(viewModel: viewModel)
                    .frame(width: sidebarWidth)
                Divider()
                    .background(Color.clear)
                    .frame(width: 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let minWidth = max(150, proxy.size.width * 0.2)
                                let maxWidth = proxy.size.width * 0.6
                                let proposed = sidebarWidth + value.translation.width
                                sidebarWidth = min(max(proposed, minWidth), maxWidth)
                            }
                    )
                    .onAppear {
                        sidebarWidth = max(150, proxy.size.width / 3)
                    }
                VStack(spacing: 10) {
                    StepIndicator(current: $viewModel.step)
                    Divider()

                    VStack(alignment: .leading, spacing: 16) {
                        content
                    }
                    .frame(maxWidth: .infinity, alignment: .top)

                    HStack {
                        if viewModel.step != .selectImages {
                            Button("Back") {
                                if let prev = Step(rawValue: viewModel.step.rawValue - 1) {
                                    viewModel.step = prev
                                }
                            }
                            .disabled(viewModel.isExporting)
                        }
                        Spacer()
                        if viewModel.step != .export {
                            Button("Next") {
                                if let next = Step(rawValue: viewModel.step.rawValue + 1) {
                                    viewModel.step = next
                                }
                            }
                            .disabled(viewModel.isMerging || viewModel.images.isEmpty)
                        }
                    }
                    .padding(.top)
                }
                .padding()
            }
        }
        .frame(minWidth: 600, minHeight: 400)
    }

    @ViewBuilder
    var content: some View {
        switch viewModel.step {
        case .selectImages:
            Step1View(viewModel: viewModel)
        case .previewAll:
            Step2View(viewModel: viewModel)
        case .export:
            Step3View(viewModel: viewModel)
        }
    }
}

#if DEBUG
#Preview {
    ContentView(viewModel: .preview)
}
#endif
