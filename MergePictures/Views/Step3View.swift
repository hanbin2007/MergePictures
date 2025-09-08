import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct Step3View: View {
    @ObservedObject var viewModel: AppViewModel
#if !os(macOS)
    @State private var isSharePresented = false
    @State private var saveMessage: String?
    @State private var saveIsError: Bool = false
#endif

    var body: some View {
        Form {
            // Status (system-native rows, no custom background)
            if viewModel.isExporting {
                Section {
                    Label {
                        Text("Exporting…") + Text(" \(Int(viewModel.exportProgress * 100))%")
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    ProgressView(value: viewModel.exportProgress)
                }
            }

            #if os(macOS)
            if viewModel.exportProgress == 1 && !viewModel.isExporting {
                Section {
                    Label("Export Completed!", systemImage: "checkmark.circle.fill")
                        .tint(.green)
                }
            }
            #else
            if let msg = saveMessage {
                Section {
                    Label(msg, systemImage: saveIsError ? "xmark.octagon.fill" : "checkmark.circle.fill")
                        .tint(saveIsError ? .red : .green)
                }
            }
            #endif

            // Export Settings
            Section {
                Toggle("Compress Output", isOn: $viewModel.enableCompression)
                    .help("Enable to limit each merged image to a target size.")
                Stepper(value: $viewModel.maxFileSizeKB, in: 100...10000, step: 100) {
                    HStack {
                        Text("Max KB")
                        Spacer()
                        Text("\(viewModel.maxFileSizeKB)")
                    }
                }
                .disabled(!viewModel.enableCompression)
                .help("Target file size per merged image (KB). Applies when compression is on.")
            } header: { Text("Export Settings") } footer: { Text("Choose whether to compress output and set a maximum file size per merged image.") }

            // Actions
            #if os(macOS)
            Section("Actions") {
                if #available(macOS 15.0, *) {
                    Button("Export") { exportImages() }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                        .disabled(viewModel.isExporting)
                        .help("Generate merged files and save them to a selected folder.")
                } else {
                    Button("Export") { exportImages() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(viewModel.isExporting)
                        .help("Generate merged files and save them to a selected folder.")
                }
            }
            #endif
        }
        #if os(iOS)
        .formStyle(.grouped)
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                if #available(iOS 26.0, *) {
                    Button { saveToPhotos() } label: {
                        Label("Save To Photos", systemImage: "photo")
                            .frame(maxWidth: .infinity)
                    }
//                    .buttonStyle(.glass)
                    .controlSize(.large)
                    .disabled(viewModel.isExporting)
                } else {
                    // Fallback on earlier versions
                    Button { saveToPhotos() } label: {
                        Label("Save To Photos", systemImage: "photo")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .disabled(viewModel.isExporting)
                }

                if #available(iOS 26.0, *) {
                    Button { exportImages() } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
//                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .disabled(viewModel.isExporting)
                } else {
                    // Fallback on earlier versions
                    Button { exportImages() } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(viewModel.isExporting)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(.bar)
        }
        #endif
        #if !os(macOS)
        .sheet(isPresented: $isSharePresented, onDismiss: {
            viewModel.clearExportCache()
        }) {
            ActivityView(items: viewModel.exportFileURLs)
        }
        #endif
    }

    func exportImages() {
        #if os(macOS)
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let dir = panel.url {
            viewModel.generateExportCache { success in
                if success {
                    viewModel.exportAll(to: dir)
                }
            }
        }
        #else
        viewModel.generateExportCache { success in
            if success {
                isSharePresented = true
            }
        }
        #endif
    }
#if !os(macOS)
    func saveToPhotos() {
        viewModel.generateExportCache { success in
            if success {
                viewModel.saveExportedImagesToPhotos { s in
                    saveIsError = !s
                    saveMessage = s ? String(localized: "Saved to Photos") : String(localized: "Save Failed")
                }
            }
        }
    }
#endif
}

#if os(iOS)
struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif

#if DEBUG
#Preview {
    Step3View(viewModel: .preview)
}
#endif
