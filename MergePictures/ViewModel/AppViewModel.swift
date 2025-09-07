import SwiftUI
import Combine
import UniformTypeIdentifiers
import ImageIO
#if os(iOS)
import UIKit
import PhotosUI
#elseif os(macOS)
import AppKit
#endif
#if canImport(Photos)
import Photos
#endif

class AppViewModel: ObservableObject {
    @Published var step: Step = .selectImages

    @Published var mergeCount: Int = 2 {
        didSet {
            clearMergedResults()
            updatePreview()
        }
    }

    @Published var direction: MergeDirection = .vertical {
        didSet {
            clearMergedResults()
            updatePreview()
        }
    }

    @Published var images: [ImageItem] = [] {
        didSet {
            clearMergedResults()
            updatePreview()
        }
    }
    @Published var mergedImageURLs: [URL] = []
    @Published var previewImage: PlatformImage?
    @Published var maxFileSizeKB: Int = 1024 {
        didSet {
            cleanupDirectory(exportCacheDirectory)
            exportCacheDirectory = nil
        }
    }
    @Published var enableCompression: Bool = true
    @Published var isMerging: Bool = false
    @Published var mergeProgress: Double = 0
    @Published var isExporting: Bool = false
    @Published var exportProgress: Double = 0
    @Published var sortAscending: Bool = true
    @Published var step1PreviewScale: CGFloat = 1.0
    @Published var step2PreviewScale: CGFloat = 1.0

    private let fileManager = FileManager.default
    private let previewMergeDimension: CGFloat = 2048
    private var exportProcessingDimension: CGFloat { processingDimension(for: maxFileSizeKB) }
    private var mergeCacheDirectory: URL?
    private var exportCacheDirectory: URL?
    private var importCacheDirectory: URL?
    private lazy var importDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return df
    }()

    var exportFileURLs: [URL] {
        guard let cacheDir = exportCacheDirectory else { return [] }
        return ((try? fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)) ?? [])
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    deinit {
        cleanupDirectory(mergeCacheDirectory)
        cleanupDirectory(exportCacheDirectory)
        cleanupDirectory(importCacheDirectory)
    }

    /// Removes any previously merged results and deletes cached files.
    func clearMergedResults() {
        mergedImageURLs = []
        cleanupDirectory(mergeCacheDirectory)
        mergeCacheDirectory = nil
        clearExportCache()
    }

    func clearExportCache() {
        cleanupDirectory(exportCacheDirectory)
        exportCacheDirectory = nil
    }

    private func createTempDirectory(prefix: String) -> URL? {
        let base = fileManager.temporaryDirectory
        let dir = base.appendingPathComponent("MergePictures-\(prefix)-\(UUID().uuidString)", isDirectory: true)
        do {
            try fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        } catch {
            return nil
        }
    }

    private func cleanupDirectory(_ url: URL?) {
        guard let url = url else { return }
        try? fileManager.removeItem(at: url)
    }

    private func processingDimension(for maxSizeKB: Int) -> CGFloat {
        let bytes = Double(max(maxSizeKB, 1)) * 1024.0
        let bytesPerPixel: Double = 0.5
        let pixelEstimate = bytes / bytesPerPixel
        let dimension = sqrt(pixelEstimate) * 1.1
        return CGFloat(min(dimension, 8192))
    }

    private func cgImage(from image: PlatformImage) -> CGImage? {
        #if os(macOS)
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        #else
        if image.imageOrientation == .up {
            return image.cgImage
        }
        guard let cg = image.cgImage else { return nil }
        let width = cg.width
        let height = cg.height
        var transform = CGAffineTransform.identity
        switch image.imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: CGFloat(width), y: CGFloat(height)).rotated(by: .pi)
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: CGFloat(width), y: 0).rotated(by: .pi/2)
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: CGFloat(height)).rotated(by: -.pi/2)
        default:
            break
        }
        switch image.imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: CGFloat(width), y: 0).scaledBy(x: -1, y: 1)
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: CGFloat(height), y: 0).scaledBy(x: -1, y: 1)
        default:
            break
        }
        var ctxWidth = width
        var ctxHeight = height
        if image.imageOrientation == .left || image.imageOrientation == .leftMirrored ||
            image.imageOrientation == .right || image.imageOrientation == .rightMirrored {
            ctxWidth = height
            ctxHeight = width
        }
        guard let ctx = CGContext(data: nil,
                                  width: ctxWidth,
                                  height: ctxHeight,
                                  bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: cg.colorSpace ?? CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.concatenate(transform)
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        return ctx.makeImage()
        #endif
    }

    private func jpegData(from cgImage: CGImage, quality: CGFloat) -> Data? {
        let data = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: quality]
        CGImageDestinationAddImage(dest, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return data as Data
    }

    private func scaledCGImage(from cgImage: CGImage, scale: CGFloat) -> CGImage? {
        let newWidth = Int(CGFloat(cgImage.width) * scale)
        let newHeight = Int(CGFloat(cgImage.height) * scale)
        guard newWidth > 0, newHeight > 0 else { return nil }
        guard let ctx = CGContext(data: nil,
                                  width: newWidth,
                                  height: newHeight,
                                  bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        ctx.interpolationQuality = .high
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: CGFloat(newWidth), height: CGFloat(newHeight)))
        return ctx.makeImage()
    }

    func addImages(urls: [URL]) {
        #if os(iOS)
        let newItems = urls.compactMap { url -> ImageItem? in
            var needsStop = false
            if url.startAccessingSecurityScopedResource() {
                needsStop = true
            }
            defer {
                if needsStop {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            guard let preview = loadPlatformImage(from: url, maxDimension: 1024) else { return nil }
            let addedAt = Date()
            let ext = url.pathExtension.isEmpty ? "img" : url.pathExtension
            let name = "photo-\(importDateFormatter.string(from: addedAt)).\(ext)"
            return ImageItem(url: url, preview: preview, addedDate: addedAt, displayName: name)
        }
        #else
        let newItems = urls.compactMap { url -> ImageItem? in
            guard let preview = loadPlatformImage(from: url, maxDimension: 1024) else { return nil }
            let addedAt = Date()
            let ext = url.pathExtension.isEmpty ? "img" : url.pathExtension
            let name = "photo-\(importDateFormatter.string(from: addedAt)).\(ext)"
            return ImageItem(url: url, preview: preview, addedDate: addedAt, displayName: name)
        }
        #endif
        images.append(contentsOf: newItems)
        sortImages()
    }

#if os(iOS)
    @MainActor
    func addImages(items: [PhotosPickerItem]) async {
        var newItems: [ImageItem] = []
        if importCacheDirectory == nil {
            importCacheDirectory = createTempDirectory(prefix: "import")
        }
        guard let dir = importCacheDirectory else { return }
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let addedAt = Date()
                let fileName = "photo-\(importDateFormatter.string(from: addedAt)).img"
                let url = dir.appendingPathComponent(fileName)
                try? data.write(to: url)
                if let preview = loadPlatformImage(from: url, maxDimension: 1024) {
                    newItems.append(ImageItem(url: url, preview: preview, addedDate: addedAt, displayName: fileName))
                }
            }
        }
        images.append(contentsOf: newItems)
        sortImages()
    }
#endif

    /// Rotates image order within each mergeCount-sized group.
    /// For example, with mergeCount 3 and images [1,2,3,4,5], the result will be
    /// [2,3,1,5,4]. Results and preview are cleared after rearranging.
    func rotateImages() {
        guard images.count > 1 else { return }
        var newOrder: [ImageItem] = []
        var index = 0
        while index < images.count {
            let end = min(index + mergeCount, images.count)
            var group = Array(images[index..<end])
            if group.count > 1 {
                let first = group.removeFirst()
                group.append(first)
            }
            newOrder.append(contentsOf: group)
            index += mergeCount
        }
        images = newOrder
        clearMergedResults()
        updatePreview()
    }

    /// Sorts images by filename using Finder-like logic respecting the current sort order.
    func sortImages() {
        images.sort { a, b in
            let cmp = a.addedDate.compare(b.addedDate)
            if cmp != .orderedSame {
                return sortAscending ? (cmp == .orderedAscending) : (cmp == .orderedDescending)
            }
            // tie-breaker for identical timestamps
            return a.id.uuidString < b.id.uuidString
        }
        clearMergedResults()
    }

    /// Toggles between ascending and descending order and resorts the image list.
    func toggleSortOrder() {
        sortAscending.toggle()
        sortImages()
    }

    func removeImage(_ item: ImageItem) {
        if let idx = images.firstIndex(where: { $0.id == item.id }) {
            images.remove(at: idx)
            if let dir = importCacheDirectory, item.url.path.hasPrefix(dir.path) {
                try? fileManager.removeItem(at: item.url)
            }
            if images.isEmpty {
                cleanupDirectory(importCacheDirectory)
                importCacheDirectory = nil
            }
            updatePreview()
        }
    }

    func updatePreview() {
        let previewSource = images.prefix(mergeCount).compactMap { loadPlatformImage(from: $0.url, maxDimension: 1024) }
        previewImage = merge(images: previewSource, direction: direction)
    }


    func batchMerge() {
        clearMergedResults()
        mergeCacheDirectory = createTempDirectory(prefix: "merge")
        isMerging = true
        mergeProgress = 0
        DispatchQueue.global(qos: .userInitiated).async {
            var index = 0
            while index < self.images.count {
                autoreleasepool {
                    let end = min(index + self.mergeCount, self.images.count)
                    var merged: PlatformImage?
                    for item in self.images[index..<end] {
                        autoreleasepool {
                            if let img = loadPlatformImage(from: item.url, maxDimension: self.previewMergeDimension) {
                                if let current = merged {
                                    merged = self.merge(images: [current, img], direction: self.direction)
                                } else {
                                    merged = img
                                }
                            }
                        }
                    }
                    if let result = merged, let dir = self.mergeCacheDirectory {
                        let fileURL = dir.appendingPathComponent("merged_\(index / self.mergeCount).png")
                        try? savePlatformImage(result, to: fileURL)
                        DispatchQueue.main.async {
                            self.mergedImageURLs.append(fileURL)
                        }
                    }
                    merged = nil
                    index += self.mergeCount
                    DispatchQueue.main.async {
                        self.mergeProgress = Double(index) / Double(self.images.count)
                    }
                }
            }
            DispatchQueue.main.async {
                self.isMerging = false
                self.mergeProgress = 1.0
            }
        }
    }

    func generateExportCache(completion: @escaping (Bool) -> Void) {
        if exportCacheDirectory != nil {
            completion(true)
            return
        }
        guard !images.isEmpty else {
            completion(false)
            return
        }
        exportCacheDirectory = createTempDirectory(prefix: "export")
        guard let dir = exportCacheDirectory else {
            completion(false)
            return
        }
        isExporting = true
        exportProgress = 0
        DispatchQueue.global(qos: .userInitiated).async {
            var index = 0
            var group = 0
            let totalGroups = Int(ceil(Double(self.images.count) / Double(self.mergeCount)))
            var success = true
            while index < self.images.count {
                autoreleasepool {
                    let end = min(index + self.mergeCount, self.images.count)
                    var merged: PlatformImage?
                    for item in self.images[index..<end] {
                        autoreleasepool {
                            let maxDim: CGFloat? = self.enableCompression ? self.exportProcessingDimension : nil
                            if let img = loadPlatformImage(from: item.url, maxDimension: maxDim) {
                                if let current = merged {
                                    merged = self.merge(images: [current, img], direction: self.direction)
                                } else {
                                    merged = img
                                }
                            }
                        }
                    }
                    if let result = merged {
                        autoreleasepool {
                            var data: Data?
                            var ext: String = ""
                            if self.enableCompression, let comp = self.compress(image: result, maxSizeKB: self.maxFileSizeKB) {
                                data = comp.0
                                ext = comp.1
                            } else if let cg = self.cgImage(from: result) {
                                data = self.jpegData(from: cg, quality: 1.0)
                                ext = "jpg"
                            }
                            if let d = data {
                                let fileURL = dir.appendingPathComponent("export_\(group).\(ext)")
                                try? d.write(to: fileURL)
                            } else {
                                success = false
                            }
                        }
                    }
                    merged = nil
                    index += self.mergeCount
                    group += 1
                    DispatchQueue.main.async {
                        self.exportProgress = Double(group) / Double(totalGroups)
                    }
                }
            }
            DispatchQueue.main.async {
                self.isExporting = false
                completion(success)
            }
        }
    }

    func merge(images: [PlatformImage], direction: MergeDirection) -> PlatformImage? {
        let cgImages = images.compactMap { cgImage(from: $0) }
        guard !cgImages.isEmpty else { return nil }
        let totalSize = cgImages.reduce(CGSize.zero) { partial, cg in
            let size = CGSize(width: cg.width, height: cg.height)
            switch direction {
            case .horizontal:
                return CGSize(width: partial.width + size.width, height: max(partial.height, size.height))
            case .vertical:
                return CGSize(width: max(partial.width, size.width), height: partial.height + size.height)
            }
        }
        guard let ctx = CGContext(data: nil,
                                  width: Int(totalSize.width),
                                  height: Int(totalSize.height),
                                  bitsPerComponent: 8,
                                  bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return nil
        }
        ctx.interpolationQuality = .high
        var current = CGPoint.zero
        for cg in cgImages {
            let size = CGSize(width: cg.width, height: cg.height)
            let rect = CGRect(origin: current, size: size)
            ctx.draw(cg, in: rect)
            switch direction {
            case .horizontal:
                current.x += size.width
            case .vertical:
                current.y += size.height
            }
        }
        guard let combined = ctx.makeImage() else { return nil }
        #if os(macOS)
        return NSImage(cgImage: combined, size: totalSize)
        #else
        return UIImage(cgImage: combined)
        #endif
    }

    func compress(image: PlatformImage, maxSizeKB: Int) -> (Data, String)? {
        guard let cg = cgImage(from: image) else { return nil }
        let limit = maxSizeKB * 1024
        var quality: CGFloat = 1.0
        let minQuality: CGFloat = 0.05
        var data = jpegData(from: cg, quality: quality)
        while let d = data, d.count > limit, quality > minQuality {
            quality = max(minQuality, quality - 0.05)
            data = jpegData(from: cg, quality: quality)
        }
        if let d = data, d.count <= limit { return (d, "jpg") }
        var lower: CGFloat = 0.0
        var upper: CGFloat = 1.0
        var bestData: Data?
        while upper - lower > 0.01 {
            let scale = (lower + upper) / 2
            guard let scaled = scaledCGImage(from: cg, scale: scale),
                  let d = jpegData(from: scaled, quality: minQuality) else { break }
            if d.count > limit {
                upper = scale
            } else {
                lower = scale
                bestData = d
            }
        }
        if let best = bestData { return (best, "jpg") }
        return nil
    }

#if canImport(Photos)
    func saveExportedImagesToPhotos(completion: @escaping (Bool) -> Void) {
        let urls = exportFileURLs
        guard !urls.isEmpty else {
            completion(false)
            return
        }
        isExporting = true
        exportProgress = 0
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async {
                    self.isExporting = false
                    completion(false)
                }
                return
            }
            DispatchQueue.global(qos: .userInitiated).async {
                var success = true
                for (idx, url) in urls.enumerated() {
                    let group = DispatchGroup()
                    group.enter()
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                    }) { s, _ in
                        success = success && (s != false)
                        group.leave()
                    }
                    group.wait()
                    DispatchQueue.main.async {
                        self.exportProgress = Double(idx + 1) / Double(urls.count)
                    }
                }
                DispatchQueue.main.async {
                    self.isExporting = false
                    completion(success)
                    self.cleanupDirectory(self.exportCacheDirectory)
                    self.exportCacheDirectory = nil
                }
            }
        }
    }
#endif

    func exportAll(to directory: URL) {
        guard let cacheDir = exportCacheDirectory else { return }
        isExporting = true
        exportProgress = 0
        DispatchQueue.global(qos: .userInitiated).async {
            let files = ((try? self.fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)) ?? [])
                .sorted { $0.lastPathComponent < $1.lastPathComponent }
            for (idx, file) in files.enumerated() {
                autoreleasepool {
                    let ext = file.pathExtension
                    let finalURL = directory.appendingPathComponent("merged_\(idx).\(ext)")
                    try? self.fileManager.removeItem(at: finalURL)
                    do {
                        try self.fileManager.copyItem(at: file, to: finalURL)
                    } catch {
                        // ignore copy errors
                    }
                    DispatchQueue.main.async {
                        self.exportProgress = Double(idx + 1) / Double(files.count)
                    }
                }
            }
            self.cleanupDirectory(self.exportCacheDirectory)
            self.exportCacheDirectory = nil
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
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyyMMdd-HHmmss-SSS"
        let base = Date()
        vm.images = (1...3).compactMap { idx in
            guard let img = platformImageNamed("Placeholder\(idx)") else { return nil }
            let addedAt = base.addingTimeInterval(Double(idx))
            let name = "photo-\(df.string(from: addedAt)).png"
            return ImageItem(url: URL(fileURLWithPath: "placeholder\(idx).png"), preview: img, addedDate: addedAt, displayName: name)
        }
        vm.step1PreviewScale = 1.0
        vm.step2PreviewScale = 1.0
        vm.updatePreview()
        vm.batchMerge()
        return vm
    }
}
#endif
