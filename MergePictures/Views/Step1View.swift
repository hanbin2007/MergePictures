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
                        let wRatio = proxy.size.width / img.size.width
                        let hRatio = proxy.size.height / img.size.height
                        let scale = min(wRatio, hRatio, 1)
                        let width = img.size.width * scale
                        let height = img.size.height * scale
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: width, height: height)
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

#Preview {
    Step1View(viewModel: .preview)
}
