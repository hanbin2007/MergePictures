import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel: AppViewModel
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var hSizeClass
    #endif
    @Environment(\.layoutDirection) private var layoutDirection
    @State private var previousStep: Step = .selectImages
    @State private var stepTransition: AnyTransition = .identity

    init(viewModel: AppViewModel = AppViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
        _previousStep = State(initialValue: viewModel.step)
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
        VStack(spacing: 0) {

            VStack(alignment: .leading, spacing: viewModel.step == .export ? 0 : 16) {
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

            let showBack = viewModel.step != .selectImages
            let showNext = viewModel.step != .export
            HStack(spacing: 16) {
                if showBack && showNext {
                    Spacer()
                    if #available(iOS 26.0, *) {
                        Button {
                            if let prev = Step(rawValue: viewModel.step.rawValue - 1) {
                                viewModel.step = prev
                            }
                        } label:{
                            Text("Back")
                                .frame(maxWidth: .infinity)
                                .bold()
                        }
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .padding(.vertical)
                        .disabled(viewModel.isExporting)
                    } else {
                        // Fallback on earlier versions
                        Button {
                            if let prev = Step(rawValue: viewModel.step.rawValue - 1) {
                                viewModel.step = prev
                            }
                        } label:{
                            Text("Back")
                                .frame(maxWidth: .infinity)
                                .bold()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .padding(.vertical)
                        .disabled(viewModel.isExporting)
                    }

                    if #available(iOS 26.0, *) {
                        Button {
                            if let next = Step(rawValue: viewModel.step.rawValue + 1) {
                                viewModel.step = next
                            }
                        } label:{
                            Text("Next")
                                .frame(maxWidth: .infinity)
                                .bold()
                        }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                        .padding(.vertical)
                        .disabled(viewModel.isMerging || viewModel.images.isEmpty)
                    } else {
                        // Fallback on earlier versions
                        Button {
                            if let next = Step(rawValue: viewModel.step.rawValue + 1) {
                                viewModel.step = next
                            }
                        } label:{
                            Text("Next")
                                .frame(maxWidth: .infinity)
                                .bold()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.vertical)
                        .disabled(viewModel.isMerging || viewModel.images.isEmpty)
                    }
                    Spacer()
                } else if showBack {
                    if #available(iOS 26.0, *) {
                        Button {
                            if let prev = Step(rawValue: viewModel.step.rawValue - 1) {
                                viewModel.step = prev
                            }
                        } label:{
                            Text("Back")
                                .frame(maxWidth: .infinity)
                                .bold()
                        }
                        .padding()
                        .buttonStyle(.glass)
                        .controlSize(.large)
                        .disabled(viewModel.isExporting)
                    } else {
                        // Fallback on earlier versions
                        Button {
                            if let prev = Step(rawValue: viewModel.step.rawValue - 1) {
                                viewModel.step = prev
                            }
                        } label:{
                            Text("Back")
                                .frame(maxWidth: .infinity)
                                .bold()
                        }
                        .padding()
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .disabled(viewModel.isExporting)
                    }
                } else if showNext {
                    if #available(iOS 26.0, *) {
                        Button {
                            if let next = Step(rawValue: viewModel.step.rawValue + 1) {
                                viewModel.step = next
                            }
                        } label: {
                            Text("Next")
                                .frame(maxWidth: .infinity)
                                .bold()
                        }
                        .buttonStyle(.glassProminent)
                        .padding()
                        .controlSize(.large)
                        .disabled(viewModel.isMerging || viewModel.images.isEmpty)
                    } else {
                        // Fallback on earlier versions
                        Button {
                            if let next = Step(rawValue: viewModel.step.rawValue + 1) {
                                viewModel.step = next
                            }
                        } label: {
                            Text("Next")
                                .frame(maxWidth: .infinity)
                                .bold()
                        }
                        .buttonStyle(.borderedProminent)
                        .padding()
                        .controlSize(.large)
                        .disabled(viewModel.isMerging || viewModel.images.isEmpty)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(.bar)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
//        .padding(.top, 0)
        .onChange(of: viewModel.step) { newValue in
            withAnimation(.easeInOut) {
                setTransition(for: newValue)
            }
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 10) {
                StepIndicator(current: $viewModel.step)
                Divider()
            }
            .background(.bar)
        }
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

    private func setTransition(for newStep: Step) {
        let forward = newStep.rawValue > previousStep.rawValue
        let forwardEdge: Edge = layoutDirection == .leftToRight ? .trailing : .leading
        let backwardEdge: Edge = layoutDirection == .leftToRight ? .leading : .trailing
        if #available(iOS 17, macOS 14, *) {
            stepTransition = forward
            ? .asymmetric(insertion: .push(from: forwardEdge), removal: .push(from: backwardEdge))
            : .asymmetric(insertion: .push(from: backwardEdge), removal: .push(from: forwardEdge))
        } else {
            stepTransition = forward
            ? .asymmetric(insertion: .move(edge: forwardEdge), removal: .move(edge: backwardEdge))
            : .asymmetric(insertion: .move(edge: backwardEdge), removal: .move(edge: forwardEdge))
        }
        previousStep = newStep
    }

    @ViewBuilder
    var content: some View {
        Group {
            switch viewModel.step {
            case .selectImages:
                Step1View(viewModel: viewModel)
            case .previewAll:
                Step2View(viewModel: viewModel)
            case .export:
                Step3View(viewModel: viewModel)
            }
        }
        .id(viewModel.step)
        .transition(stepTransition)
        .animation(.easeInOut, value: viewModel.step)
    }
}

#if DEBUG
#Preview {
    ContentView(viewModel: .preview)
        .environment(\.horizontalSizeClass, .compact)
//        .previewDevice("iPhone 14 Pro")
}
#endif
