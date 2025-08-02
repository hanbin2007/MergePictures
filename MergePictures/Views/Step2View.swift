import SwiftUI

struct Step2View: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.colorScheme) private var colorScheme
    private var gridLayout: [GridItem] {
        [GridItem(.adaptive(minimum: 150 * viewModel.step2PreviewScale))]
    }
    var body: some View {
        GeometryReader { proxy in
            VStack {
                if viewModel.isMerging {
                    ProgressView(value: viewModel.mergeProgress)
                        .padding(.vertical)
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
                                Image(platformImage: img)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 150 * viewModel.step2PreviewScale)
                                    .overlay(alignment: .bottomTrailing) {
                                        Text("\(idx + 1)")
                                            .fontWeight(.bold)
                                            .foregroundColor(colorScheme == .dark ? .white : .black)
                                            .shadow(color: colorScheme == .dark ? .black.opacity(0.8) : .white.opacity(0.8), radius: 1)
                                            .padding(4)
                                    }
                            }
                        }
                        .animation(.default, value: viewModel.step2PreviewScale)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
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
