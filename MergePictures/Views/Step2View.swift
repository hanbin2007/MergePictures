import SwiftUI

struct Step2View: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        VStack {
            if viewModel.isMerging {
                ProgressView(value: viewModel.mergeProgress)
                    .padding(.vertical)
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))]) {
                    ForEach(Array(viewModel.mergedImages.enumerated()), id: \.offset) { pair in
                        let idx = pair.offset
                        let img = pair.element
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150)
                            .overlay(
                                Text("\(idx + 1)")
                                    .foregroundColor(.white)
                                    .padding(4),
                                alignment: .bottomTrailing
                            )
                    }
                }
            }
        }
        .onAppear {
            if viewModel.mergedImages.isEmpty {
                viewModel.batchMerge()
            }
        }
    }
}
