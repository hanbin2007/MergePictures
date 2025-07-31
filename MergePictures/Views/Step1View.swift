import SwiftUI

struct Step1View: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showImporter = false

    var body: some View {
        #if os(iOS)
        ScrollView {
            VStack(spacing: 0) {
                previewSection
                Divider()
                settingsSection
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            if case let .success(urls) = result {
                viewModel.addImages(urls: urls)
            }
        }
        #else
        HStack(spacing: 0) {
            previewSection
            Divider()
            settingsSection
                .frame(width: 280)
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            if case let .success(urls) = result {
                viewModel.addImages(urls: urls)
            }
        }
        #endif
    }

    private var previewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            GeometryReader { proxy in
                Group {
                    if let img = viewModel.previewImage {
                        ScrollView([.vertical, .horizontal]) {
                            previewImage(for: img, in: proxy)
                        }
                    } else {
                        Text("No Preview")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
//        .padding(.bottom)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading) {
            Button("Add Images") {
                showImporter = true
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Basic Settings").bold().padding(.top)

            Stepper("Merge count: \(viewModel.mergeCount)", value: $viewModel.mergeCount, in: 1...10)
                .frame(maxWidth: .infinity, alignment: .leading)

            Picker("Direction", selection: $viewModel.direction) {
                ForEach(MergeDirection.allCases) { dir in
                    Text(dir.rawValue.capitalized).tag(dir)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("Advance Settings").bold().padding(.top)

            Button("Swap Order") {
                viewModel.rotateImages()
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer()
        }.padding(.leading)
    }

    private func previewImage(for image: PlatformImage, in proxy: GeometryProxy) -> some View {
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

        return Image(platformImage: image)
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
