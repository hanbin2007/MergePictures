import SwiftUI

struct Step1View: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showImporter = false

    var body: some View {
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
            Button("Swap Order") { viewModel.rotateImages() }
            Text("Selected: \(viewModel.images.count)")
            Spacer()
        }
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GeometryReader { proxy in
                    Group {
                        if let img = viewModel.previewImage {
                            previewImage(for: img, in: proxy)
                        } else {
                            Text("No Preview")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .frame(minHeight: 400)
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

    private func previewImage(for image: NSImage, in proxy: GeometryProxy) -> some View {
        let baseScale: CGFloat
        if viewModel.direction == .vertical {
            baseScale = min(proxy.size.width / image.size.width, 1)
        } else {
            baseScale = min(proxy.size.height / image.size.height, 1)
        }

        var width = image.size.width * baseScale * viewModel.step1PreviewScale
        var frameHeight: CGFloat? = image.size.height * baseScale * viewModel.step1PreviewScale

        if width < proxy.size.width * 0.5 {
            width = proxy.size.width * 0.5
            frameHeight = nil
        }

        return Image(nsImage: image)
            .resizable()
            .scaledToFit()
            .frame(width: width, height: frameHeight)
    }
}

#if DEBUG
#Preview {
    Step1View(viewModel: .preview)
}
#endif
