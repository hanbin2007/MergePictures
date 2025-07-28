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
    @Published var isMerging: Bool = false
    @Published var mergeProgress: Double = 0
    @Published var isExporting: Bool = false
    @Published var exportProgress: Double = 0


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
        isMerging = true
        mergeProgress = 0
        DispatchQueue.global(qos: .userInitiated).async {
            var index = 0
            var results: [NSImage] = []
            while index < self.images.count {
                let end = min(index + self.mergeCount, self.images.count)
                let slice = Array(self.images[index..<end])
                if let merged = self.merge(images: slice, direction: self.direction) {
                    results.append(merged)
                }
                index += self.mergeCount
                DispatchQueue.main.async {
                    self.mergeProgress = Double(index) / Double(self.images.count)
                }
            }
            DispatchQueue.main.async {
                self.mergedImages = results
                self.isMerging = false
                self.mergeProgress = 1.0
            }
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

    func compress(image: NSImage, maxSizeKB: Int) -> (Data, String)? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            return nil
        }
        var quality: CGFloat = 1.0
        var data = rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
        while let d = data, d.count > maxSizeKB * 1024, quality > 0.1 {
            quality -= 0.1
            data = rep.representation(using: .jpeg, properties: [.compressionFactor: quality])
        }
        if let d = data {
            return (d, "jpg")
        }
        return nil
    }

    func exportAll(to directory: URL) {
        guard !mergedImages.isEmpty else { return }
        isExporting = true
        exportProgress = 0
        DispatchQueue.global(qos: .userInitiated).async {
            for (idx, img) in self.mergedImages.enumerated() {
                let result = self.compress(image: img, maxSizeKB: self.maxFileSizeKB)
                let data: Data
                let ext: String
                if let res = result {
                    data = res.0
                    ext = res.1
                } else {
                    data = img.tiffRepresentation!
                    ext = "tiff"
                }
                let url = directory.appendingPathComponent("merged_\(idx).\(ext)")
                try? data.write(to: url)
                DispatchQueue.main.async {
                    self.exportProgress = Double(idx + 1) / Double(self.mergedImages.count)
                }
            }
            DispatchQueue.main.async {
                self.isExporting = false
            }
        }
    }
}
