import SwiftUI

struct Step2View: View {
    @ObservedObject var viewModel: AppViewModel
    @Environment(\.colorScheme) private var colorScheme
#if os(iOS)
    @Environment(\.horizontalSizeClass) private var hSizeClass
#endif
    
    private let gridSpacing: CGFloat = 16

    var body: some View {
        VStack(spacing: 16) {
            bannerSection

            VStack(alignment: .leading, spacing: 12) {
                if viewModel.isMerging {
                    ProgressView(value: viewModel.mergeProgress)
                        .padding()
                }

                GeometryReader { proxy in
                    let columns = gridColumns(for: proxy.size.width)
                    ScrollView {
                        if viewModel.mergedImageURLs.isEmpty {
                            reloadPrompt
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .frame(minWidth: proxy.size.width)
                        } else {
                            LazyVGrid(columns: columns, alignment: .leading, spacing: gridSpacing) {
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
                            .frame(minWidth: proxy.size.width, alignment: .leading)
                            .animation(.easeOut(duration: 0.12), value: viewModel.step2PreviewScale)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
//        .padding(.horizontal)
        .animation(.easeInOut(duration: 0.25), value: viewModel.showPreviewNotice)
        .onAppear {
            if viewModel.mergedImageURLs.isEmpty {
                viewModel.batchMerge()
            }
        }
    }

    private func gridColumns(for totalWidth: CGFloat) -> [GridItem] {
        let baseWidth = 150 * viewModel.step2PreviewScale
        let minItemWidth = max(120, baseWidth)
        let availableWidth = max(totalWidth, minItemWidth)
        let proposedCount = (availableWidth + gridSpacing) / (minItemWidth + gridSpacing)
        let columnCount = max(1, Int(proposedCount.rounded(.down)))
        let usableWidth = availableWidth - CGFloat(columnCount - 1) * gridSpacing
        let maxItemWidth = max(usableWidth / CGFloat(columnCount), minItemWidth)

        return Array(repeating: GridItem(.flexible(minimum: minItemWidth, maximum: maxItemWidth), spacing: gridSpacing, alignment: .top), count: columnCount)
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
        .task(id: url) {
            await loadThumbnailIfNeeded()
        }
        .onChange(of: url) { _ in
            image = nil
        }
    }

    private func loadThumbnailIfNeeded() async {
        guard image == nil else { return }
        await loadThumbnail()
    }

    private func loadThumbnail() async {
        guard let newImage = loadPlatformImage(from: url, maxDimension: preferredThumbnailDimension) else { return }
        guard !Task.isCancelled else { return }
        await MainActor.run {
            image = newImage
        }
    }

    private var preferredThumbnailDimension: CGFloat { 400 * maxPreviewScale }
    private var maxPreviewScale: CGFloat { 2.0 }
}

#if DEBUG
#Preview {
    Step2View(viewModel: .preview)
}
#endif
