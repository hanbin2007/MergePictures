import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: AppViewModel

    init(viewModel: AppViewModel = AppViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    var body: some View {
        NavigationSplitView {
            ImageSidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 150, ideal: 200, max: 400)
        } detail: {
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
            .frame(minWidth: 600)
            .padding()
        }
        .frame(minWidth: 800, minHeight: 400)
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
