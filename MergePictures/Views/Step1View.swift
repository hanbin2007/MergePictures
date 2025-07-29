import SwiftUI

struct Step1View: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showImporter = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Button("Add Images") { showImporter = true }
                Stepper("Merge count: \(viewModel.mergeCount)", value: $viewModel.mergeCount, in: 1...10)
                Picker("Direction", selection: $viewModel.direction) {
                    ForEach(MergeDirection.allCases) { dir in
                        Text(dir.rawValue.capitalized).tag(dir)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                Spacer()
                Text("Selected: \(viewModel.images.count)")
            }
            GeometryReader { proxy in
                Group {
                    if let img = viewModel.previewImage {
                        let containerWidth = proxy.size.width
                        let minWidth = containerWidth * 0.5
                        let targetWidth = max(minWidth, min(containerWidth, img.size.width))
                        let targetHeight = targetWidth * (img.size.height / img.size.width)
                        Image(nsImage: img)
                            .resizable()
                            .frame(width: targetWidth, height: targetHeight)
                    } else {
                        Text("No Preview")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(minHeight: 200)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(.bottom)
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            if case let .success(urls) = result {
                viewModel.addImages(urls: urls)
            }
        }
    }
}

#if DEBUG
#Preview {
    Step1View(viewModel: .preview)
}
#endif
