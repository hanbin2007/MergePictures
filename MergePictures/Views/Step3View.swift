import SwiftUI
#if os(macOS)
import AppKit
#endif

struct Step3View: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        GeometryReader { proxy in
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
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
        }
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
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        viewModel.exportAll(to: dir)
        #endif
    }
}

#if DEBUG
#Preview {
    Step3View(viewModel: .preview)
}
#endif
