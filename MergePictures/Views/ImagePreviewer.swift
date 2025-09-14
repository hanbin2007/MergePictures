import SwiftUI

struct ImagePreviewer: View {
    let urls: [URL]
    @Binding var isPresented: Bool
    @State private var currentIndex: Int

    init(urls: [URL], isPresented: Binding<Bool>, initialIndex: Int = 0) {
        self.urls = urls
        self._isPresented = isPresented
        self._currentIndex = State(initialValue: min(max(0, initialIndex), max(0, urls.count - 1)))
    }

    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(urls.indices, id: \.self) { idx in
                PreviewPage(url: urls[idx])
                    .tag(idx)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .automatic))
    }
}

private struct PreviewPage: View {
    let url: URL
    @State private var image: PlatformImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image {
                    ZoomableImage(image: image)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ProgressView()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .task(id: url) {
            image = nil
            image = loadPlatformImage(from: url, maxDimension: 4096)
        }
        .background(Color.black.opacity(0.001))
    }
}

private struct ZoomableImage: View {
    let image: PlatformImage
    @State private var scale: CGFloat = 1.0
    @State private var steadyScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var steadyOffset: CGSize = .zero

    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0

    var body: some View {
        GeometryReader { proxy in
            let container = proxy.size

            let magnify = MagnificationGesture()
                .onChanged { value in
                    let newScale = clamp(steadyScale * value, min: minScale, max: maxScale)
                    scale = newScale
                    offset = bounded(offset: steadyOffset, in: container, at: newScale)
                }
                .onEnded { value in
                    steadyScale = clamp(steadyScale * value, min: minScale, max: maxScale)
                    if steadyScale == 1 {
                        steadyOffset = .zero
                        offset = .zero
                    } else {
                        steadyOffset = bounded(offset: steadyOffset, in: container, at: steadyScale)
                        offset = steadyOffset
                    }
                }

            let drag = DragGesture()
                .onChanged { value in
                    guard scale > 1.0 else { return }
                    let tentative = CGSize(width: steadyOffset.width + value.translation.width,
                                            height: steadyOffset.height + value.translation.height)
                    offset = bounded(offset: tentative, in: container, at: scale)
                }
                .onEnded { _ in
                    guard scale > 1.0 else { return }
                    steadyOffset = offset
                }

            Image(platformImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: container.width, height: container.height)
                .scaleEffect(scale)
                .offset(offset)
                .contentShape(Rectangle())
                .gesture(drag)
                .simultaneousGesture(magnify)
                .onTapGesture(count: 2) {
                    withAnimation(.easeInOut) {
                        if steadyScale > 1 {
                            steadyScale = 1
                            scale = 1
                            steadyOffset = .zero
                            offset = .zero
                        } else {
                            steadyScale = 2
                            scale = 2
                        }
                    }
                }
                .onChange(of: scale) { newValue in
                    offset = bounded(offset: offset, in: container, at: newValue)
                }
        }
    }

    private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.max(min, Swift.min(max, value))
    }

    private func bounded(offset: CGSize, in container: CGSize, at scale: CGFloat) -> CGSize {
        let iw = image.size.width
        let ih = image.size.height
        if iw <= 0 || ih <= 0 || container.width <= 0 || container.height <= 0 { return .zero }
        let imageAspect = iw / ih
        let containerAspect = container.width / container.height
        let baseWidth: CGFloat
        let baseHeight: CGFloat
        if containerAspect > imageAspect {
            baseHeight = container.height
            baseWidth = baseHeight * imageAspect
        } else {
            baseWidth = container.width
            baseHeight = baseWidth / imageAspect
        }
        let scaledWidth = baseWidth * scale
        let scaledHeight = baseHeight * scale
        let hBound = max(0, (scaledWidth - container.width) / 2)
        let vBound = max(0, (scaledHeight - container.height) / 2)
        let clampedX = Swift.max(-hBound, Swift.min(hBound, offset.width))
        let clampedY = Swift.max(-vBound, Swift.min(vBound, offset.height))
        return CGSize(width: clampedX, height: clampedY)
    }
}

#if DEBUG
#Preview {
    let urls: [URL] = [
        URL(fileURLWithPath: "/tmp/a.png"),
        URL(fileURLWithPath: "/tmp/b.png")
    ]
    return ImagePreviewer(urls: urls, isPresented: .constant(true), initialIndex: 0)
}
#endif

