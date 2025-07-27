import SwiftUI
import Combine

class AppViewModel: ObservableObject {
    @Published var step: Step = .selectImages
    @Published var mergeCount: Int = 2
    @Published var direction: MergeDirection = .vertical
    @Published var images: [NSImage] = [] {
        didSet { updatePreview() }
    }
    @Published var mergedImages: [NSImage] = []
    @Published var previewImage: NSImage?
    @Published var maxFileSizeKB: Int = 1024

    func addImages(urls: [URL]) {
        let newImages = urls.compactMap { NSImage(contentsOf: $0) }
        images.append(contentsOf: newImages)
    }

    func updatePreview() {
        let previewSource = Array(images.prefix(mergeCount))
        previewImage = merge(images: previewSource, direction: direction)
    }

    func batchMerge() {
        mergedImages = []
        var index = 0
        while index < images.count {
            let slice = Array(images[index..<min(index+mergeCount, images.count)])
            if let merged = merge(images: slice, direction: direction) {
                mergedImages.append(merged)
            }
            index += mergeCount
        }
    }

    func merge(images: [NSImage], direction: MergeDirection) -> NSImage? {
        guard !images.isEmpty else { return nil }
        let totalSize = images.reduce(CGSize.zero) { partial, image in
            switch direction {
            case .horizontal:
                return CGSize(width: partial.width + image.size.width, height: max(partial.height, image.size.height))
            case .vertical:
                return CGSize(width: max(partial.width, image.size.width), height: partial.height + image.size.height)
            }
        }
        let result = NSImage(size: totalSize)
        result.lockFocus()
        var current = CGPoint.zero
        for image in images {
            image.draw(at: current, from: .zero, operation: .sourceOver, fraction: 1.0)
            switch direction {
            case .horizontal:
                current.x += image.size.width
            case .vertical:
                current.y += image.size.height
            }
        }
        result.unlockFocus()
        return result
    }

    func compress(image: NSImage, maxSizeKB: Int) -> Data? {
        guard let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        var quality: CGFloat = 1.0
        var data = rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
        while let d = data, d.count > maxSizeKB * 1024, quality > 0.1 {
            quality -= 0.1
            data = rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
        }
        return data
    }
}
