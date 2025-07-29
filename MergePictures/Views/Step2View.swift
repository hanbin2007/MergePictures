import SwiftUI

struct Step2View: View {
    @ObservedObject var viewModel: AppViewModel
    @State private var scale: CGFloat = 1.0

    private var gridLayout: [GridItem] {
        [GridItem(.adaptive(minimum: 150 * scale))]
    }
    var body: some View {

        VStack {
            if viewModel.isMerging {
                ProgressView(value: viewModel.mergeProgress)
                    .padding(.vertical)
            }
            HStack {
                Spacer()
                Slider(value: $scale, in: 0.5...2)
                    .frame(width: 150)
            }
            ScrollView {
                LazyVGrid(columns: gridLayout) {
                    ForEach(Array(viewModel.mergedImages.enumerated()), id: \.offset) { pair in
                        let idx = pair.offset
                        let img = pair.element
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 150 * scale)
                            .overlay(
                                Text("\(idx + 1)")
                                    .foregroundColor(.white)
                                    .padding(4),
                                alignment: .bottomTrailing
                            )
                    }
                }.animation(.default, value: scale)
            }
        }
        .onAppear {
            if viewModel.mergedImages.isEmpty {
                viewModel.batchMerge()
            }
        }
    }
}

#if DEBUG
#Preview {
    Step2View(viewModel: .preview)
}
#endif
