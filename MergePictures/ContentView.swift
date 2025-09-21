import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

struct ContentView: View {
    @StateObject private var viewModel: AppViewModel
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var showInspector: Bool = true
    @State private var showCompactControls: Bool = true
    @State private var compactPanelDetent: CompactControlsDetent = .fraction(0.35)
    #endif
    @State private var splitViewVisibility: NavigationSplitViewVisibility = .all
    @State private var actionBarHeight: CGFloat = 0
    #if os(iOS)
    private func updateCompactSheetVisibility() {
        guard hSizeClass == .compact else {
            if showCompactControls { showCompactControls = false }
            return
        }
        let allowStep = (viewModel.step == .selectImages || viewModel.step == .previewAll)
        let anyModal = viewModel.presentImageListSheet || viewModel.isPreviewPresented || viewModel.presentSettings
        let shouldShow = allowStep && !anyModal
        let wasShowing = showCompactControls
        showCompactControls = shouldShow
        if shouldShow && !wasShowing {
            compactPanelDetent = .fraction(0.35)
        }
    }

    private var compactControlsEligible: Bool {
        hSizeClass == .compact &&
        (viewModel.step == .selectImages || viewModel.step == .previewAll)
    }
    #endif

    init(viewModel: AppViewModel = AppViewModel()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    var body: some View {
        #if os(macOS)
        NavigationSplitView(columnVisibility: $splitViewVisibility) {
            ImageSidebarView(viewModel: viewModel)
                .navigationSplitViewColumnWidth(min: 150, ideal: 200, max: 400)
        } detail: {
            detailContent
        }
        #else
        if hSizeClass == .regular {
            NavigationSplitView(columnVisibility: $splitViewVisibility) {
                ImageSidebarView(viewModel: viewModel)
            } detail: {
                detailContent
            }
            // iPad (regular) Step1 inspector as system side panel
            .inspector(isPresented: Binding(get: { shouldPresentInspector }, set: { showInspector = $0 })) {
                inspectorContent
            }
            .inspectorColumnWidth(min: 600, ideal: 1200, max: 1200)
        } else {
            NavigationStack {
                // Force inline title style to avoid oversized nav bar
                detailContent
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle("")
            }
            .overlay(alignment: .bottom) {
                if compactControlsEligible {
                    CompactControlsPanel(isPresented: $showCompactControls, selected: $compactPanelDetent, bottomInset: actionBarHeight) {
                        NavigationStack {
                            ControlsFormView(viewModel: viewModel)
                                .navigationTitle("")
                                .navigationBarTitleDisplayMode(.inline)
                        }
                    } bottomBar: {
                        StepNavigationButtons(viewModel: viewModel)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .onChange(of: compactControlsEligible) { eligible in
                if eligible {
                    actionBarHeight = 0
                }
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

            if shouldShowStandaloneActionBar {
                StepNavigationButtons(viewModel: viewModel, topPadding: 12)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 50)
                    .background(.bar)
                    .background(
                        GeometryReader { proxy in
                            Color.clear.preference(key: ActionBarHeightKey.self, value: proxy.size.height)
                        }
                    )
            }
//#if os(iOS)
            else {
                Color.clear
                    .frame(height: 0)
                    .preference(key: ActionBarHeightKey.self, value: 0)
            }
//#endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

        // Allow children to request opening the sidebar when needed
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenSidebar"))) { _ in
            splitViewVisibility = .all
        }
        .onPreferenceChange(ActionBarHeightKey.self) { newHeight in
            actionBarHeight = newHeight
        }
#if os(iOS)
        .toolbar {
            // Leading button for image list on compact layouts
            ToolbarItem(placement: .topBarLeading) {
                if hSizeClass == .compact {
                    Button {
                        viewModel.presentImageListSheet = true
                    } label: {
                        if #available(iOS 17.0, *) {
                            Image(systemName: "photo.stack")
                        } else {
                            Image(systemName: "square.grid.2x2")
                        }
                    }
                }
            }
            // Center step indicator inside navigation bar
            ToolbarItem(placement: .principal) {
                StepIndicator(current: $viewModel.step, viewModel: viewModel)
            }
            // Settings on the right
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.presentSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel(LocalizedStringKey("Settings"))
            }
        }
        #endif
        #if os(iOS)
        // Coordinate inspector with other sheets on iOS
        .onChange(of: viewModel.presentImageListSheet) { isPresenting in
            showInspector = (hSizeClass == .regular) ? !isPresenting : showInspector
            updateCompactSheetVisibility()
        }
        .onChange(of: viewModel.isPreviewPresented) { isPresenting in
            showInspector = (hSizeClass == .regular) ? !isPresenting : showInspector
            updateCompactSheetVisibility()
        }
        .onChange(of: viewModel.presentSettings) { _ in
            updateCompactSheetVisibility()
        }
        .onChange(of: viewModel.step) { _ in
            if hSizeClass == .regular && inspectorIsEligible {
                showInspector = true
            }
            updateCompactSheetVisibility()
        }
        .onAppear {
            showInspector = (hSizeClass == .regular)
            updateCompactSheetVisibility()
        }
        .onChange(of: hSizeClass) { newValue in
            if newValue != .regular {
                showInspector = false
            } else if inspectorIsEligible {
                showInspector = true
            }
            updateCompactSheetVisibility()
        }
        #endif
        #if os(iOS)
        .sheet(isPresented: Binding(get: { viewModel.presentImageListSheet }, set: { viewModel.presentImageListSheet = $0 })) {
            NavigationStack {
                ImageSidebarView(viewModel: viewModel)
                    .navigationTitle("Images")
                    .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { viewModel.presentImageListSheet = false } } }
            }
        }
        #endif
        .sheet(isPresented: Binding(get: { viewModel.presentSettings }, set: { viewModel.presentSettings = $0 })) {
            SettingsView(viewModel: viewModel)
        }
        #if os(macOS)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                if splitViewVisibility != .all {
                    Button {
                        splitViewVisibility = .all
                    } label: {
                        Image(systemName: "sidebar.left")
                    }
                    .help(LocalizedStringKey("Show Sidebar"))
                    .accessibilityLabel(LocalizedStringKey("Show Sidebar"))
                }
            }
            ToolbarItem(placement: .automatic) {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Slider(value: previewScaleBinding, in: 0.5...2.0)
                }
                .frame(width: 150)
                .tint(.accentColor)
            }
            ToolbarItem(placement: .automatic) {
                Button {
                    viewModel.presentSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .help(LocalizedStringKey("Settings"))
                .accessibilityLabel(LocalizedStringKey("Settings"))
            }
        }
        #endif
        // Global preview using system Quick Look on iOS; custom fallback on macOS
        .sheet(isPresented: Binding(get: { viewModel.isPreviewPresented }, set: { viewModel.isPreviewPresented = $0 })) {
            #if os(iOS)
            NavigationStack {
                QuickLookPreview(
                    urls: viewModel.previewURLs,
                    isPresented: Binding(get: { viewModel.isPreviewPresented }, set: { viewModel.isPreviewPresented = $0 }),
                    initialIndex: viewModel.previewStartIndex
                )
                .navigationTitle("Preview")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { viewModel.isPreviewPresented = false }
                    }
                }
            }
            .interactiveDismissDisabled(true)
            .presentationDragIndicator(.hidden)
            #else
            NavigationStack {
                ImagePreviewer(
                    urls: viewModel.previewURLs,
                    isPresented: Binding(get: { viewModel.isPreviewPresented }, set: { viewModel.isPreviewPresented = $0 }),
                    initialIndex: viewModel.previewStartIndex
                )
                .navigationTitle("Preview")
                .toolbar { ToolbarItem(placement: .automatic) { Button("Done") { viewModel.isPreviewPresented = false } } }
            }
            .presentationDragIndicator(.visible)
            #endif
        }
    }

#if os(iOS)
    private var isPadDevice: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
    }
    private var isiOS26OrNewer: Bool {
        if #available(iOS 26.0, *) { return true } else { return false }
    }
#endif

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

#if os(iOS)
    private var inspectorIsEligible: Bool {
        viewModel.step == .selectImages || viewModel.step == .previewAll
    }

    private var shouldPresentInspector: Bool {
        inspectorIsEligible && showInspector && hSizeClass == .regular
    }

    @ViewBuilder
    private var inspectorContent: some View {
        if inspectorIsEligible {
            ControlsFormView(viewModel: viewModel)
                .navigationTitle("Controls")
        } else {
            EmptyView()
        }
    }
#endif

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

#if os(iOS)
private extension ContentView {
    var shouldShowStandaloneActionBar: Bool { !compactControlsEligible }
}
#else
private extension ContentView {
    var shouldShowStandaloneActionBar: Bool { true }
}
#endif

private struct StepNavigationButtons: View {
    @ObservedObject var viewModel: AppViewModel
    var topPadding: CGFloat = 0

    var body: some View {
        let showBack = viewModel.step != .selectImages
        let showNext = viewModel.step != .export

        VStack {
            HStack(spacing: 0) {
                if showBack && showNext {
                    Spacer()
                    backButton
                    //                    .padding(.vertical)
                    Spacer()
                    nextButton
                    //                    .padding(.vertical)
                    Spacer()
                } else if showBack {
                    backButton
                        .padding(.horizontal)
                } else if showNext {
                    nextButton
                        .padding(.horizontal)
                }
            }
        }
        .padding(.top, topPadding)
        .padding(.bottom)
    }

    @ViewBuilder
    private var backButton: some View {
#if os(iOS)
        if #available(iOS 26.0, *) {
            Button {
                if let prev = Step(rawValue: viewModel.step.rawValue - 1) {
                    viewModel.step = prev
                }
            } label: {
                Text("Back")
                    .frame(maxWidth: .infinity)
                    .bold()
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .disabled(viewModel.isExporting)
        } else {
            Button {
                if let prev = Step(rawValue: viewModel.step.rawValue - 1) {
                    viewModel.step = prev
                }
            } label: {
                Text("Back")
                    .frame(maxWidth: .infinity)
                    .bold()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(viewModel.isExporting)
        }
#else
        Button {
            if let prev = Step(rawValue: viewModel.step.rawValue - 1) {
                viewModel.step = prev
            }
        } label: {
            Text("Back")
                .frame(maxWidth: .infinity)
                .bold()
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
        .disabled(viewModel.isExporting)
#endif
    }

    @ViewBuilder
    private var nextButton: some View {
#if os(iOS)
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
            .controlSize(.large)
            .disabled(viewModel.isMerging || viewModel.images.isEmpty)
        } else {
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
            .controlSize(.large)
            .disabled(viewModel.isMerging || viewModel.images.isEmpty)
        }
#else
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
        .controlSize(.large)
        .disabled(viewModel.isMerging || viewModel.images.isEmpty)
#endif
    }
}

private struct ActionBarHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#if DEBUG
#Preview {
    ContentView(viewModel: .preview)
        .environment(\.horizontalSizeClass, .regular)
//        .previewDevice("iPhone 14 Pro")
}
#endif
