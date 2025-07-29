import SwiftUI

struct Step1View: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var showImporter = false

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading) {
                    HStack {
                        Button("Add Images") { showImporter = true }
                        Stepper("Merge count: \(viewModel.mergeCount)", value: $viewModel.mergeCount, in: 1...10)
                            .onChange(of: viewModel.mergeCount) { _ in viewModel.updatePreview() }
                        Picker("Direction", selection: $viewModel.direction) {
                            ForEach(MergeDirection.allCases) { dir in
                                Text(dir.rawValue.capitalized).tag(dir)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .onChange(of: viewModel.direction) { _ in viewModel.updatePreview() }
                        Spacer()
                        Text("Selected: \(viewModel.images.count)")
                    }
                    Group {
                        if let img = viewModel.previewImage {
                            Image(nsImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            Text("No Preview")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                    .frame(minHeight: 200)
                }
                .frame(minHeight: proxy.size.height, alignment: .top)
                .padding(.bottom)
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.image], allowsMultipleSelection: true) { result in
            if case let .success(urls) = result {
                viewModel.addImages(urls: urls)
            }
        }
    }
}
