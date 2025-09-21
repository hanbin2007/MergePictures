import SwiftUI
#if os(iOS)
import PhotosUI

struct ControlsFormView: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var selectedItems: [PhotosPickerItem] = []
    @Environment(\.horizontalSizeClass) private var hSizeClass

    var body: some View {
        Form {
            if viewModel.step == .previewAll {
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Thumbnail Scale")
                            Spacer()
                            Text("\(Int(viewModel.step2PreviewScale * 100))%")
                                .monospacedDigit()
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $viewModel.step2PreviewScale, in: 0.5...2.0)
                            .accessibilityLabel(LocalizedStringKey("Thumbnail Scale"))
                    }

                    Button {
                        viewModel.batchMerge()
                    } label: {
                        Label("Reload Preview", systemImage: "arrow.clockwise")
                    }
                    .controlSize(.large)
                } header: {
                    Text("Preview Controls")
                }
            }

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
        .onChange(of: selectedItems) { _, newItems in
            Task {
                await viewModel.addImages(items: newItems)
                selectedItems = []
            }
        }
    }
}
#endif
