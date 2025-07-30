import SwiftUI

struct Step2View: View {
    @ObservedObject var viewModel: AppViewModel
    private var gridLayout: [GridItem] {
        [GridItem(.adaptive(minimum: 150 * viewModel.step2PreviewScale))]
    }
    var body: some View {

        VStack {
            if viewModel.isMerging {
                ProgressView(value: viewModel.mergeProgress)
                    .padding(.vertical)
            }
            HStack {
                Spacer()
                PreviewScaleSlider(scale: $viewModel.step2PreviewScale)
            }
            ScrollView {
                if viewModel.mergedImages.isEmpty {
                    reloadPrompt
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    LazyVGrid(columns: gridLayout) {
                        ForEach(Array(viewModel.mergedImages.enumerated()), id: \.offset) { pair in
                            let idx = pair.offset
                            let img = pair.element
                            Image(nsImage: img)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 150 * viewModel.step2PreviewScale)
                                .overlay(
                                    Text("\(idx + 1)")
                                        .foregroundColor(.white)
                                        .padding(4),
                                    alignment: .bottomTrailing
                                )
                        }
                    }
                    .animation(.default, value: viewModel.step2PreviewScale)
                }
            }
        }
        .onAppear {
            if viewModel.mergedImages.isEmpty {
                viewModel.batchMerge()
            }
        }
    }

    private var reloadPrompt: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)
            Text("Preview is empty")
                .font(.headline)
            Text("Preview need to be regenerated after rearranging images")
                .multilineTextAlignment(.center)
            
            Button("Reload Preview") {
                viewModel.batchMerge()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentColor.opacity(0.1))
        )
        .frame(width:280)
        .padding()
    }
}

#if DEBUG
#Preview {
    Step2View(viewModel: .preview)
}
#endif
