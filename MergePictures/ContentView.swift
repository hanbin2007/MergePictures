import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: AppViewModel
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var hSizeClass
    #endif

    init(viewModel: AppViewModel = AppViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    var body: some View {
        #if os(macOS)
        NavigationSplitView {
            ImageSidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 150, ideal: 200, max: 400)
        } detail: {
            detailContent
        }
        #else
        if hSizeClass == .regular {
            NavigationSplitView {
                ImageSidebarView(viewModel: viewModel)
            } detail: {
                detailContent
            }
        } else {
            NavigationStack {
                detailContent
            }
        }
        #endif
    }

    private var detailContent: some View {
        VStack(spacing: 10) {
            StepIndicator(current: $viewModel.step)
            Divider()

            VStack(alignment: .leading, spacing: 16) {
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            let showBack = viewModel.step != .selectImages
            let showNext = viewModel.step != .export
            HStack(spacing: 16) {
                if showBack && showNext {
                    Button("Back") {
                        if let prev = Step(rawValue: viewModel.step.rawValue - 1) {
                            viewModel.step = prev
                        }
                    }
                    .bold()
                    .buttonStyle(.bordered)
                    .frame(width: 120)
                    .controlSize(.large)
                    .disabled(viewModel.isExporting)

                    Button("Next") {
                        if let next = Step(rawValue: viewModel.step.rawValue + 1) {
                            viewModel.step = next
                        }
                    }
                    .bold()
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .controlSize(.large)
                    .disabled(viewModel.isMerging || viewModel.images.isEmpty)
                } else if showBack {
                    Button("Back") {
                        if let prev = Step(rawValue: viewModel.step.rawValue - 1) {
                            viewModel.step = prev
                        }
                    }
                    .bold()
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    .controlSize(.large)
                    .disabled(viewModel.isExporting)
                } else if showNext {
                    Button("Next") {
                        if let next = Step(rawValue: viewModel.step.rawValue + 1) {
                            viewModel.step = next
                        }
                    }
                    .bold()
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .controlSize(.large)
                    .disabled(viewModel.isMerging || viewModel.images.isEmpty)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
//        .padding()
        .frame(maxHeight: .infinity)
        #if os(macOS)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Slider(value: previewScaleBinding, in: 0.5...2.0)
                }
                .frame(width: 150)
                .tint(.accentColor)
            }
        }
        #endif
    }

    private var previewScaleBinding: Binding<CGFloat> {
        switch viewModel.step {
        case .selectImages:
            return $viewModel.step1PreviewScale
        case .previewAll:
            return $viewModel.step2PreviewScale
        case .export:
            return .constant(1.0)
        }
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
        .environment(\.horizontalSizeClass, .compact)
//        .previewDevice("iPhone 14 Pro")
}
#endif
