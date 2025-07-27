import SwiftUI

struct Step2View: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))]) {
                ForEach(Array(viewModel.mergedImages.enumerated()), id: \._0) { idx, img in
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 150)
                        .overlay(Text("\(idx+1)").foregroundColor(.white).padding(4), alignment: .bottomTrailing)
                }
            }
        }
        .onAppear {
            viewModel.batchMerge()
        }
    }
}
