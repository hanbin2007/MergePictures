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
    @State private var compactSheetDetent: PresentationDetent = .fraction(0.35)
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
            compactSheetDetent = .fraction(0.35)
        }
    }

    private var shouldPresentCompactControls: Bool {
        showCompactControls && hSizeClass == .compact &&
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
            // Top banner independent of scroll
            .safeAreaInset(edge: .top) {
                if viewModel.showPreviewNotice {
                    NoticeBanner(
                        closeAction: { viewModel.dismissPreviewNoticeOnce() },
                        neverShowAction: { viewModel.suppressPreviewNotice() }
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
                }
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
                if viewModel.showPreviewNotice {
                    NoticeBanner(
                        closeAction: { viewModel.dismissPreviewNoticeOnce() },
                        neverShowAction: { viewModel.suppressPreviewNotice() }
                    )
                    .padding(.horizontal)
                    .padding(.top, 8)
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
        #if os(macOS)
        .overlay(alignment: .top) {
            if viewModel.showPreviewNotice {
                NoticeBanner(
                    closeAction: { viewModel.dismissPreviewNoticeOnce() },
                    neverShowAction: { viewModel.suppressPreviewNotice() }
                )
                .padding(.horizontal)
                .padding(.top, 8)
            }
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
        .sheet(isPresented: Binding(get: { shouldPresentCompactControls }, set: { newValue in
            if !newValue {
                showCompactControls = false
            }
        })) {
            NavigationStack {
                ControlsFormView(viewModel: viewModel)
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([
                .fraction(0.35),
                .medium,
                .large
            ], selection: $compactSheetDetent)
            .presentationDragIndicator(.visible)
            .interactiveDismissDisabled(true)
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
