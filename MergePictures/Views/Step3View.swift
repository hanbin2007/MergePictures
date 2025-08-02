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
        ScrollView {
            VStack(alignment: .leading) {
                Stepper("Max KB: \(viewModel.maxFileSizeKB)", value: $viewModel.maxFileSizeKB, in: 100...10000, step: 100)
                if viewModel.isPreparingExport {
                    ProgressView(value: viewModel.prepareProgress)
                        .padding(.vertical)
                } else if viewModel.isExporting {
                    ProgressView(value: viewModel.exportProgress)
                        .padding(.vertical)
                }
                #if os(macOS)
                Button("Export") { exportImages() }
                    .disabled(viewModel.isPreparingExport || viewModel.isExporting)
                if viewModel.exportProgress == 1 && !viewModel.isExporting {
                    Text("Export Completed!").foregroundColor(.green)
                }
                #else
                Button("Share") { exportImages() }
                    .disabled(viewModel.isPreparingExport || viewModel.isExporting)
                Button("Save to Photos") { saveToPhotos() }
                    .disabled(viewModel.isPreparingExport || viewModel.isExporting)
                if let msg = saveMessage {
                    Text(msg).foregroundColor(.green)
                }
                #endif
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .onAppear {
            viewModel.prepareExportCache()
        }
#if !os(macOS)
        .sheet(isPresented: $isSharePresented) {
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
            viewModel.exportAll(to: dir)
        }
        #else
        isSharePresented = true
        #endif
    }
#if !os(macOS)
    func saveToPhotos() {
        viewModel.saveExportedImagesToPhotos { success in
            saveMessage = success ? "Saved to Photos" : "Save Failed"
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
