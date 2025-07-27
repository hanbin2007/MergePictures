import AppKit
import SwiftUI

struct Step3View: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var exported = false

    var body: some View {
        VStack(alignment: .leading) {
            Stepper("Max KB: \(viewModel.maxFileSizeKB)", value: $viewModel.maxFileSizeKB, in: 100...10000, step: 100)
            Button("Export") { exportImages() }
            if exported {
                Text("Export Completed!").foregroundColor(.green)
            }
        }
    }

    func exportImages() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let dir = panel.url {
            for (idx, img) in viewModel.mergedImages.enumerated() {
                let data = viewModel.compress(image: img, maxSizeKB: viewModel.maxFileSizeKB) ?? img.tiffRepresentation!
                let url = dir.appendingPathComponent("merged_\(idx).jpg")
                try? data.write(to: url)
            }
            exported = true
        }
    }
}
