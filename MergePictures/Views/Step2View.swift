import SwiftUI

struct Step2View: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.colorScheme) private var colorScheme
    private var gridLayout: [GridItem] {
        [GridItem(.adaptive(minimum: 150 * viewModel.step2PreviewScale))]
    }
    var body: some View {

        VStack {
            if viewModel.isMerging {
                ProgressView(value: viewModel.mergeProgress)
                    .padding(.vertical)
            }
            ScrollView {
                if viewModel.mergedImageURLs.isEmpty {
                    reloadPrompt
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    LazyVGrid(columns: gridLayout) {
                        ForEach(Array(viewModel.mergedImageURLs.enumerated()), id: \.offset) { pair in
                            MergedThumbnail(
                                url: pair.element,
                                index: pair.offset,
                                scale: viewModel.step2PreviewScale,
                                colorScheme: colorScheme,
                                tapAction: { viewModel.presentPreviewForMerged(at: pair.offset) }
                            )
                        }
                    }
                    .animation(.default, value: viewModel.step2PreviewScale)
                }
            }
        }.padding()
        .onAppear {
            if viewModel.mergedImageURLs.isEmpty {
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
                .bold()
            Text("Preview need to be regenerated after rearranging images")
                .multilineTextAlignment(.center)
            Text(LocalizedStringKey("Reload Preview Detail"))
                .multilineTextAlignment(.center)

            Button("Reload Preview") {
                viewModel.batchMerge()
            }
            .bold()
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
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

private struct MergedThumbnail: View {
    let url: URL
    let index: Int
    let scale: CGFloat
    let colorScheme: ColorScheme

    @State private var image: PlatformImage?
    var tapAction: () -> Void = {}

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let image {
                    Image(platformImage: image)
                        .resizable()
                        .scaledToFit()
                } else {
                    ProgressView()
                }
            }
            .frame(height: 150 * scale)
            .contentShape(Rectangle())
            .onTapGesture(perform: tapAction)

            if image != nil {
                Text("\(index + 1)")
                    .fontWeight(.bold)
                    .foregroundColor(colorScheme == .dark ? .white : .black)
                    .shadow(color: colorScheme == .dark ? .black.opacity(0.8) : .white.opacity(0.8), radius: 1)
                    .padding(4)
            }
        }
        .task(id: scale) {
            image = nil
            image = loadPlatformImage(from: url, maxDimension: 400 * scale)
        }
    }
}

#if DEBUG
#Preview {
    Step2View(viewModel: .preview)
}
#endif
