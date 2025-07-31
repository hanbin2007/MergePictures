import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

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
                if viewModel.mergedImages.isEmpty {
                    reloadPrompt
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    LazyVGrid(columns: gridLayout) {
                        ForEach(viewModel.mergedImages.indices, id: \.self) { idx in
                            Step2ImageCell(
                                image: viewModel.mergedImages[idx],
                                index: idx,
                                scale: viewModel.step2PreviewScale
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

private struct Step2ImageCell: View {
    let image: PlatformImage
    let index: Int
    let scale: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        platformImage
            .resizable()
            .scaledToFit()
            .frame(height: 150 * scale)
            .overlay(alignment: .bottomTrailing) { indexOverlay }
    }

    @ViewBuilder
    private var platformImage: some View {
#if os(macOS)
        Image(nsImage: image)
#else
        Image(uiImage: image)
#endif
    }

    private var indexOverlay: some View {
        let textColor: Color = colorScheme == .dark ? .white : .black
        let shadowColor: Color = colorScheme == .dark ? .black.opacity(0.8) : .white.opacity(0.8)
        return Text("\(index + 1)")
            .fontWeight(.bold)
            .foregroundColor(textColor)
            .shadow(color: shadowColor, radius: 1)
            .padding(4)
    }
}

#if DEBUG
#Preview {
    Step2View(viewModel: .preview)
}
#endif
