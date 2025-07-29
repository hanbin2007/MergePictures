import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = AppViewModel()

    var body: some View {
        VStack(spacing: 0) {
            StepIndicator(current: $viewModel.step)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    content
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
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
        .padding()
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

#Preview {
    ContentView()
}
