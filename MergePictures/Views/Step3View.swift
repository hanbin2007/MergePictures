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
#endif

    var body: some View {
        Form {
            // Status (system-native rows, no custom background)
            if viewModel.isExporting {
                Section {
                    Label("Exporting… \(Int(viewModel.exportProgress * 100))%", systemImage: "arrow.triangle.2.circlepath")
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
                    let isError = msg.lowercased().contains("fail") || msg.lowercased().contains("error")
                    Label(msg, systemImage: isError ? "xmark.octagon.fill" : "checkmark.circle.fill")
                        .tint(isError ? .red : .green)
                }
            }
            #endif

            // Export Settings
            Section("Export Settings") {
                Toggle("Compress Output", isOn: $viewModel.enableCompression)
                Stepper("Max KB: \(viewModel.maxFileSizeKB)", value: $viewModel.maxFileSizeKB, in: 100...10000, step: 100)
                    .disabled(!viewModel.enableCompression)
            }

            // Actions
            #if os(macOS)
            Section("Actions") {
                if #available(macOS 15.0, *) {
                    Button("Export") { exportImages() }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                        .disabled(viewModel.isExporting)
                } else {
                    Button("Export") { exportImages() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(viewModel.isExporting)
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
                    .buttonStyle(.glass)
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
                    .buttonStyle(.glassProminent)
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
                    saveMessage = s ? "Saved to Photos" : "Save Failed"
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
