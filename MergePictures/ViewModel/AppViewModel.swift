import SwiftUI
import Combine

class AppViewModel: ObservableObject {
    @Published var step: Step = .selectImages

    @Published var mergeCount: Int = 2 {
        didSet {
            mergedImages = []
            updatePreview()
        }
    }

    @Published var direction: MergeDirection = .vertical {
        didSet {
            mergedImages = []
            updatePreview()
        }
    }

    @Published var images: [ImageItem] = [] {
        didSet {
            mergedImages = []
            updatePreview()
        }
    }
    @Published var mergedImages: [NSImage] = []
    @Published var previewImage: NSImage?
    @Published var maxFileSizeKB: Int = 1024
    @Published var isMerging: Bool = false
    @Published var mergeProgress: Double = 0
    @Published var isExporting: Bool = false
    @Published var exportProgress: Double = 0
    @Published var sortAscending: Bool = true


    func addImages(urls: [URL]) {
        let newItems = urls.compactMap { url -> ImageItem? in
            guard let img = NSImage(contentsOf: url) else { return nil }
            return ImageItem(url: url, image: img)
        }
        images.append(contentsOf: newItems)
        sortImages()
    }

    /// Cycles the image order by moving the first item to the end.
    /// Clears any generated results and refreshes the preview.
    func rotateImages() {
        guard images.count > 1 else { return }
        let first = images.removeFirst()
        images.append(first)
        mergedImages = []
        updatePreview()
    }

    /// Sorts images by filename using Finder-like logic respecting the current sort order.
    func sortImages() {
        images.sort { a, b in
            let result = a.url.lastPathComponent.localizedStandardCompare(b.url.lastPathComponent)
            return sortAscending ? result == .orderedAscending : result == .orderedDescending
        }
    }

    /// Toggles between ascending and descending order and resorts the image list.
    func toggleSortOrder() {
        sortAscending.toggle()
        sortImages()
    }

    func updatePreview() {
        let previewSource = images.prefix(mergeCount).map { $0.image }
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
                let slice = self.images[index..<end].map { $0.image }
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
              var rep = NSBitmapImageRep(data: tiff) else {
            return nil
        }

        var quality: CGFloat = 1.0
        let minQuality: CGFloat = 0.05
        let limit = maxSizeKB * 1024
        var data = rep.representation(using: .jpeg, properties: [.compressionFactor: quality])

        var currentImage = image

        while let d = data, d.count >= limit {
            if quality > minQuality {
                quality = max(minQuality, quality - 0.05)
            } else {
                // quality already minimal, start reducing resolution gradually
                let ratio: CGFloat = 0.95
                let newSize = NSSize(width: currentImage.size.width * ratio,
                                     height: currentImage.size.height * ratio)
                if newSize.width < 1 || newSize.height < 1 {
                    break
                }
                let scaled = NSImage(size: newSize)
                scaled.lockFocus()
                NSGraphicsContext.current?.imageInterpolation = .high
                currentImage.draw(in: NSRect(origin: .zero, size: newSize))
                scaled.unlockFocus()
                currentImage = scaled
                guard let newTiff = currentImage.tiffRepresentation,
                      let newRep = NSBitmapImageRep(data: newTiff) else {
                    break
                }
                rep = newRep
            }
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

#if DEBUG
extension AppViewModel {
    static var preview: AppViewModel {
        let vm = AppViewModel()
        vm.images = (1...3).compactMap { idx in
            guard let img = NSImage(named: "Placeholder\(idx)") else { return nil }
            return ImageItem(url: URL(fileURLWithPath: "placeholder\(idx).png"), image: img)
        }
        vm.updatePreview()
        vm.batchMerge()
        return vm
    }
}
#endif
