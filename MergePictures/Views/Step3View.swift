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
                if viewModel.isExporting {
                    ProgressView(value: viewModel.exportProgress)
                        .padding(.vertical)
                }
                #if os(macOS)
                Button("Export") { exportImages() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(viewModel.isExporting)
                if viewModel.exportProgress == 1 && !viewModel.isExporting {
                    Text("Export Completed!").foregroundColor(.green)
                }
                #else
                HStack {
                    Spacer()
                    VStack {
                        Button { exportImages() } label:{
                            Text("Share")
                                .frame(alignment: .center)
                                .bold()
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .disabled(viewModel.isExporting)
                            
                        Button { saveToPhotos() } label: {
                            Text("Save To Photos")
                                .frame(alignment: .center)
                                .bold()
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .bold()
                        .disabled(viewModel.isExporting)
                    }
                    .frame(maxWidth: .infinity)
                    Spacer()
                }
                
                if let msg = saveMessage {
                    Text(msg).foregroundColor(.green)
                }
                #endif
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }.padding()
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
