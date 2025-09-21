import SwiftUI

struct Step2View: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.colorScheme) private var colorScheme
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var hSizeClass
#endif
    
    private var gridLayout: [GridItem] {
        [GridItem(.adaptive(minimum: 150 * viewModel.step2PreviewScale))]
    }
    var body: some View {
        VStack(spacing: 16) {
            bannerSection

            VStack(spacing: 12) {
                if viewModel.isMerging {
                    ProgressView(value: viewModel.mergeProgress)
                        .padding(.top, 4)
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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.25), value: viewModel.showPreviewNotice)
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
            Text("Preview needs to be regenerated when settings are modified")
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

extension Step2View {
    @ViewBuilder
    private var bannerSection: some View {
        if viewModel.showPreviewNotice {
            NoticeBanner(
                closeAction: { viewModel.dismissPreviewNoticeOnce() },
                neverShowAction: { viewModel.suppressPreviewNotice() }
            )
            .padding(.top, bannerTopPadding)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}

#if os(iOS)
private extension Step2View {
    var bannerTopPadding: CGFloat { hSizeClass == .regular ? 0 : 8 }
}
#else
private extension Step2View {
    var bannerTopPadding: CGFloat { 8 }
}
#endif

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
