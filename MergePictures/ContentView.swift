import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

struct ContentView: View {
    @StateObject private var viewModel: AppViewModel
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var hSizeClass
    @State private var showStep1Inspector: Bool = true
    @State private var showCompactControls: Bool = true
    @State private var compactPanelDetent: CompactControlsDetent = .fraction(0.35)
    #endif
    @State private var splitViewVisibility: NavigationSplitViewVisibility = .all
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

#if os(iOS)
    private var shouldShowFooterNavigation: Bool {
        if hSizeClass == .compact && !isPadDevice {
            return !compactControlsEligible
        }
        return true
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
            // Top banner independent of scroll
            .safeAreaInset(edge: .top) {
                PreviewNoticeHeader(
                    isPresented: viewModel.showPreviewNotice,
                    closeAction: { viewModel.dismissPreviewNoticeOnce() },
                    neverShowAction: { viewModel.suppressPreviewNotice() }
                )
            }
            // iPad (regular) Step1 inspector as system side panel
            .inspector(isPresented: Binding(get: { viewModel.step == .selectImages && showStep1Inspector }, set: { showStep1Inspector = $0 })) {
                Step1InspectorView(viewModel: viewModel)
            }
            .inspectorColumnWidth(min: 320, ideal: 360, max: 420)
        } else {
            NavigationStack {
                // Force inline title style to avoid oversized nav bar
                detailContent
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationTitle("")
            }
            // Top banner independent of scroll (compact)
            .safeAreaInset(edge: .top) {
                PreviewNoticeHeader(
                    isPresented: viewModel.showPreviewNotice,
                    closeAction: { viewModel.dismissPreviewNoticeOnce() },
                    neverShowAction: { viewModel.suppressPreviewNotice() }
                )
            }
            .overlay(alignment: .bottom) {
                if compactControlsEligible {
                    CompactControlsPanel(isPresented: $showCompactControls, selected: $compactPanelDetent) {
                        VStack(spacing: 12) {
                            compactNavigationControls

                            NavigationStack {
                                ControlsFormView(viewModel: viewModel)
                                    .navigationTitle("")
                                    .navigationBarTitleDisplayMode(.inline)
                            }
                        }
                    }
                }
            }
            .overlay(alignment: .bottom) {
                if compactControlsEligible {
                    CompactControlsPanel(isPresented: $showCompactControls, selected: $compactPanelDetent) {
                        NavigationStack {
                            ControlsFormView(viewModel: viewModel)
                                .navigationTitle("")
                                .navigationBarTitleDisplayMode(.inline)
                        }
                    }
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

#if os(iOS)
            if shouldShowFooterNavigation {
                footerNavigationBar
            }
#else
            footerNavigationBar
#endif
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        #if os(macOS)
        .safeAreaInset(edge: .top) {
            PreviewNoticeHeader(
                isPresented: viewModel.showPreviewNotice,
                closeAction: { viewModel.dismissPreviewNoticeOnce() },
                neverShowAction: { viewModel.suppressPreviewNotice() }
            )
        }
        #endif

        // Allow children to request opening the sidebar when needed
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenSidebar"))) { _ in
            splitViewVisibility = .all
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
            showStep1Inspector = (hSizeClass == .regular) ? !isPresenting : showStep1Inspector
            updateCompactSheetVisibility()
        }
        .onChange(of: viewModel.isPreviewPresented) { isPresenting in
            showStep1Inspector = (hSizeClass == .regular) ? !isPresenting : showStep1Inspector
            updateCompactSheetVisibility()
        }
        .onChange(of: viewModel.presentSettings) { _ in
            updateCompactSheetVisibility()
        }
        .onChange(of: viewModel.step) { _ in
            updateCompactSheetVisibility()
        }
        .onAppear {
            showStep1Inspector = (hSizeClass == .regular)
            updateCompactSheetVisibility()
        }
        .onChange(of: hSizeClass) { _ in
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
    @ViewBuilder
    private var compactNavigationControls: some View {
        if hSizeClass == .compact && !isPadDevice {
            let showBack = viewModel.step != .selectImages
            let showNext = viewModel.step != .export

            if showBack || showNext {
                HStack(spacing: 12) {
                    if showBack {
                        backButton(fullWidth: false, padding: .init())
                    }

                    Spacer()

                    if showNext {
                        nextButton(fullWidth: false, padding: .init())
                    }
                }
                .padding(.top, 4)
            }
        }
    }
#endif

    @ViewBuilder
    private var footerNavigationBar: some View {
        let showBack = viewModel.step != .selectImages
        let showNext = viewModel.step != .export

        if showBack || showNext {
            HStack(spacing: 16) {
                if showBack && showNext {
                    Spacer()
                    backButton(fullWidth: true, padding: EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0))
                    nextButton(fullWidth: true, padding: EdgeInsets(top: 16, leading: 0, bottom: 16, trailing: 0))
                    Spacer()
                } else if showBack {
                    backButton(fullWidth: true, padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                } else if showNext {
                    nextButton(fullWidth: true, padding: EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 50)
            .background(.bar)
        }
    }

    @ViewBuilder
    private func backButton(fullWidth: Bool, padding: EdgeInsets) -> some View {
#if os(iOS)
        if #available(iOS 26.0, *) {
            baseBackButton(fullWidth: fullWidth, padding: padding)
                .buttonStyle(.glass)
        } else {
            baseBackButton(fullWidth: fullWidth, padding: padding)
                .buttonStyle(.bordered)
        }
#else
        baseBackButton(fullWidth: fullWidth, padding: padding)
            .buttonStyle(.bordered)
#endif
    }

    @ViewBuilder
    private func nextButton(fullWidth: Bool, padding: EdgeInsets) -> some View {
#if os(iOS)
        if #available(iOS 26.0, *) {
            baseNextButton(fullWidth: fullWidth, padding: padding)
                .buttonStyle(.glassProminent)
        } else {
            baseNextButton(fullWidth: fullWidth, padding: padding)
                .buttonStyle(.borderedProminent)
        }
#else
        baseNextButton(fullWidth: fullWidth, padding: padding)
            .buttonStyle(.borderedProminent)
#endif
    }

    private func baseBackButton(fullWidth: Bool, padding: EdgeInsets) -> some View {
        Button {
            if let prev = Step(rawValue: viewModel.step.rawValue - 1) {
                viewModel.step = prev
            }
        } label: {
            Text("Back")
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .bold()
        }
        .controlSize(.large)
        .padding(padding)
        .disabled(viewModel.isExporting)
    }

    private func baseNextButton(fullWidth: Bool, padding: EdgeInsets) -> some View {
        Button {
            if let next = Step(rawValue: viewModel.step.rawValue + 1) {
                viewModel.step = next
            }
        } label: {
            Text("Next")
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .bold()
        }
        .controlSize(.large)
        .padding(padding)
        .disabled(viewModel.isMerging || viewModel.images.isEmpty)
    }

#if os(iOS)
    private var isPadDevice: Bool {
        UIDevice.current.userInterfaceIdiom == .pad
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
