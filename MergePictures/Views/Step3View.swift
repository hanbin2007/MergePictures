import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct Step3View: View {
    @ObservedObject var viewModel: AppViewModel
#if os(iOS)
    @State private var showPicker = false
#endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                Stepper("Max KB: \(viewModel.maxFileSizeKB)", value: $viewModel.maxFileSizeKB, in: 100...10000, step: 100)
                if viewModel.isExporting {
                    ProgressView(value: viewModel.exportProgress)
                        .padding(.vertical)
                }
                Button("Export") { exportImages() }
                if viewModel.exportProgress == 1 && !viewModel.isExporting {
                    Text("Export Completed!").foregroundColor(.green)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
#if os(iOS)
        .sheet(isPresented: $showPicker) {
            DocumentPicker { url in
                if let url = url { viewModel.exportAll(to: url) }
            }
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
        showPicker = true
#endif
    }
}

#if os(iOS)
struct DocumentPicker: UIViewControllerRepresentable {
    var completion: (URL?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.folder], asCopy: false)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        init(_ parent: DocumentPicker) { self.parent = parent }
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            parent.completion(urls.first)
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.completion(nil)
        }
    }
}
#endif

#if DEBUG
#Preview {
    Step3View(viewModel: .preview)
}
#endif
