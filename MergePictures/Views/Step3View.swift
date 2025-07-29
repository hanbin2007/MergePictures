import AppKit
import SwiftUI

struct Step3View: View {
    @ObservedObject var viewModel: AppViewModel

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
    }

    func exportImages() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let dir = panel.url {
            viewModel.exportAll(to: dir)
        }
    }
}
