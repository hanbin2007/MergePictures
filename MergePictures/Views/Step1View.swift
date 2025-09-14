import SwiftUI
#if os(iOS)
import PhotosUI
#endif

struct Step1View: View {
    @ObservedObject var viewModel: AppViewModel
#if os(iOS)
    @State private var selectedItems: [PhotosPickerItem] = []
    @Environment(\.horizontalSizeClass) private var hSizeClass
#else
    @State private var showImporter = false
#endif

    var body: some View {
        #if os(iOS)
        GeometryReader { proxy in
            VStack(spacing: 0) {
                previewSection
                    .frame(height: proxy.size.height * 0.5)
                Divider()
                settingsSection
                    .frame(height: proxy.size.height * 0.5)
            }
        }
        .onChange(of: selectedItems) { newItems in
            Task {
                await viewModel.addImages(items: newItems)
                selectedItems = []
            }
        }
        #else
        HStack(spacing: 0) {
            previewSection
            Divider()
            settingsSection
                .frame(width: 280)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            if case let .success(urls) = result {
                viewModel.addImages(urls: urls)
            }
        }
        #endif
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            GeometryReader { proxy in
                Group {
                    if let img = viewModel.previewImage {
                        ScrollView([.vertical, .horizontal]) {
                            previewImage(for: img, in: proxy)
                        }
                    } else {
                        noPreviewView
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
//        .padding(.bottom)
    }

    private var noPreviewView: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.stack")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
            Text("No Preview")
                .font(.headline)
                .bold()
            Text(LocalizedStringKey("No Preview Detail 1"))
                .multilineTextAlignment(.center)
            Text(LocalizedStringKey("No Preview Detail 2"))
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentColor.opacity(0.1))
        )
        .frame(maxWidth: 360)
        .padding()
    }

    private var settingsSection: some View {
#if os(iOS)
        Form {
            Section {
                PhotosPicker(selection: $selectedItems, maxSelectionCount: 0, matching: .images) {
                    Label("Add Images", systemImage: "photo.on.rectangle.angled")
                }
                .controlSize(.large)
                .help("Select one or more images to merge.")
            }

            Section {
                Stepper(value: $viewModel.mergeCount, in: 1...10) {
                    HStack {
                        Text("Merge Count")
                        Spacer()
                        Text("\(viewModel.mergeCount)")
                    }
                }
                    .help("Number of images combined into each merged result.")
                HStack {
                    Text("Direction")
                    Spacer()
                    Picker("Direction", selection: $viewModel.direction) {
                        ForEach(MergeDirection.allCases) { dir in
                            Text(LocalizedStringKey(dir.rawValue)).tag(dir)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(maxWidth: 200, alignment: .trailing)
                    .help("Vertical stacks top-to-bottom; Horizontal side-by-side.")
                }
            } header: { Text("Basic Settings") } footer: { Text("Choose how many images to merge and the stacking direction.") }

            Section {
                Toggle("Enable Uniform Scaling", isOn: $viewModel.enableUniformScaling)
                HStack {
                    Text("Uniform Dimension")
                    Spacer()
                    Picker("Uniform Dimension", selection: $viewModel.scaleMode) {
                        ForEach(ScaleMode.allCases) { mode in
                            Text(LocalizedStringKey(mode.rawValue)).tag(mode)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(maxWidth: 300, alignment: .trailing)
                    .disabled(!viewModel.enableUniformScaling)
                    .help("Scale images so widths or heights match before merging.")
                }
                HStack {
                    Text("Scale Strategy")
                    Spacer()
                    Picker("Scale Strategy", selection: $viewModel.scaleStrategy) {
                        ForEach(ScaleStrategy.allCases) { s in
                            Text(LocalizedStringKey(s.rawValue)).tag(s)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(maxWidth: 300, alignment: .trailing)
                    .disabled(!viewModel.enableUniformScaling)
                    .help("Target dimension: min (shrink), max (enlarge), or average.")
                }
            } header: { Text("Uniform Scaling") } footer: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enable and configure proportional scaling to unify widths or heights.")
                    if viewModel.enableUniformScaling {
                        Text(LocalizedStringKey(viewModel.scaleStrategyDescriptionKey))
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section {
                Button("Swap Order") {
                    viewModel.rotateImages()
                }
                .controlSize(.large)
                .help("Rotate order within each merge group (move first image to the end).")
            } header: { Text("Advanced Settings") } footer: { Text("Rearrange image order within each group without reselecting images.") }

            // Separate group for opening the image list or guiding manual sorting in sidebar
            Section {
                let isSidebarVisible = (hSizeClass == .regular)
                let buttonKey = isSidebarVisible ? "Manually Sort in Sidebar" : "Open Image List to Sort"
                Button(LocalizedStringKey(buttonKey)) {
                    if isSidebarVisible {
                        // Ensure the sidebar is shown when sorting in sidebar is intended
                        NotificationCenter.default.post(name: Notification.Name("OpenSidebar"), object: nil)
                    } else {
                        // Open list as a sheet for manual sorting
                        viewModel.presentImageListSheet = true
                    }
                }
                .controlSize(.large)
            } footer: {
                Text(LocalizedStringKey("Manual Sort Description"))
            }
        }
        .formStyle(.grouped)
#else
        VStack(alignment: .leading) {
            Button {
                showImporter = true
            } label: {
                Text("Add Images").frame(maxWidth: .infinity)
            }
            .padding()
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .leading)
            .help("Select one or more images to merge.")

            Text("Basic Settings").bold()

            Stepper(value: $viewModel.mergeCount, in: 1...10) {
                HStack {
                    Text("Merge Count")
                    Spacer()
                    Text("\(viewModel.mergeCount)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .help("Number of images combined into each merged result.")

            Picker("Direction", selection: $viewModel.direction) {
                ForEach(MergeDirection.allCases) { dir in
                    Text(LocalizedStringKey(dir.rawValue)).tag(dir)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
            .help("Vertical stacks top-to-bottom; Horizontal side-by-side.")

            // Uniform Scaling group (macOS)
            Text("Uniform Scaling").bold().padding(.top)
            Toggle("Enable Uniform Scaling", isOn: $viewModel.enableUniformScaling)
            HStack {
                Text("Uniform Dimension")
                Spacer()
                Picker("Uniform Dimension", selection: $viewModel.scaleMode) {
                    ForEach(ScaleMode.allCases) { mode in
                        Text(LocalizedStringKey(mode.rawValue)).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(maxWidth: 360, alignment: .trailing)
                .disabled(!viewModel.enableUniformScaling)
                .help("Scale images so widths or heights match before merging.")
            }

            HStack {
                Text("Scale Strategy")
                Spacer()
                Picker("Scale Strategy", selection: $viewModel.scaleStrategy) {
                    ForEach(ScaleStrategy.allCases) { s in
                        Text(LocalizedStringKey(s.rawValue)).tag(s)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(maxWidth: 360, alignment: .trailing)
                .disabled(!viewModel.enableUniformScaling)
                .help("Target dimension: min (shrink), max (enlarge), or average.")
            }
            Text(LocalizedStringKey(viewModel.scaleStrategyDescriptionKey))
                .font(.footnote)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .disabled(!viewModel.enableUniformScaling)

            Text("Advance Settings").bold().padding(.top)

            Button("Swap Order") {
                viewModel.rotateImages()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .help("Rotate order within each merge group (move first image to the end).")

            // Separate group for opening the image list or guiding manual sorting in sidebar (macOS)
            Divider().padding(.vertical, 4)
            Button(LocalizedStringKey("Manually Sort in Sidebar")) {
                NotificationCenter.default.post(name: Notification.Name("OpenSidebar"), object: nil)
            }
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(LocalizedStringKey("Manual Sort Description"))
                .font(.footnote)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
        .padding(.horizontal)
#endif
    }

    private func previewImage(for image: PlatformImage, in proxy: GeometryProxy) -> some View {
        let baseScale: CGFloat
        if viewModel.direction == .vertical {
            baseScale = min(proxy.size.width / image.size.width, 1)
        } else {
            baseScale = min(proxy.size.height / image.size.height, 1)
        }

        var width = image.size.width * baseScale * viewModel.step1PreviewScale
        var frameHeight: CGFloat? = image.size.height * baseScale * viewModel.step1PreviewScale

        if width < proxy.size.width * 0.5 {
            width = proxy.size.width * 0.5
            frameHeight = nil
        }

        return Image(platformImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width, height: frameHeight)
    }
}

#if DEBUG
#Preview {
    Step1View(viewModel: .preview)
}
#endif
