import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

struct ContentView: View {
    @StateObject private var viewModel: AppViewModel
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var hSizeClass
    #endif
    @State private var splitViewVisibility: NavigationSplitViewVisibility = .all

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
        .safeAreaInset(edge: .top) {
            VStack(spacing: 8) {
                ZStack {
                    // Centered step indicator
                    StepIndicator(current: $viewModel.step, viewModel: viewModel)
                        .frame(maxWidth: .infinity, alignment: .center)
                    // Left-aligned button (iOS compact only)
                    #if os(iOS)
                    HStack {
                        if hSizeClass == .compact && !(isiOS26OrNewer && isPadDevice) {
                            Button {
                                viewModel.presentImageListSheet = true
                            } label: {
                                Group {
                                    if #available(iOS 17.0, *) {
                                        Image(systemName: "photo.stack")
                                    } else {
                                        Image(systemName: "square.grid.2x2")
                                    }
                                }
                                .imageScale(.large)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    #endif
                }
                .padding(.horizontal)
                Divider()
            }
            .background(.bar)
        }
        // Allow children to request opening the sidebar when needed
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenSidebar"))) { _ in
            splitViewVisibility = .all
        }
        #if os(iOS)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if isiOS26OrNewer && isPadDevice && hSizeClass == .compact {
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
