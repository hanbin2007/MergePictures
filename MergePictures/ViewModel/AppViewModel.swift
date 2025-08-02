import SwiftUI
import Combine
#if os(iOS)
import UIKit
import PhotosUI
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
            prepareProgress = 0
            if step == .export {
                prepareExportCache()
            }
        }
    }
    @Published var isMerging: Bool = false
    @Published var mergeProgress: Double = 0
    @Published var isPreparingExport: Bool = false
    @Published var prepareProgress: Double = 0
    @Published var isExporting: Bool = false
    @Published var exportProgress: Double = 0
    @Published var sortAscending: Bool = true
    @Published var step1PreviewScale: CGFloat = 1.0
    @Published var step2PreviewScale: CGFloat = 1.0

    private let fileManager = FileManager.default
    private let maxProcessingDimension: CGFloat = 4096
    private var mergeCacheDirectory: URL?
    private var exportCacheDirectory: URL?
    private var importCacheDirectory: URL?

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
        cleanupDirectory(exportCacheDirectory)
        exportCacheDirectory = nil
        prepareProgress = 0
        isPreparingExport = false
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
            return ImageItem(url: url, preview: preview)
        }
        #else
        let newItems = urls.compactMap { url -> ImageItem? in
            guard let preview = loadPlatformImage(from: url, maxDimension: 1024) else { return nil }
            return ImageItem(url: url, preview: preview)
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
                let url = dir.appendingPathComponent("photo-\(UUID().uuidString).img")
                try? data.write(to: url)
                if let preview = loadPlatformImage(from: url, maxDimension: 1024) {
                    newItems.append(ImageItem(url: url, preview: preview))
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
            let result = a.url.lastPathComponent.localizedStandardCompare(b.url.lastPathComponent)
            return sortAscending ? result == .orderedAscending : result == .orderedDescending
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

    func prepareExportCache() {
        guard exportCacheDirectory == nil, !mergedImageURLs.isEmpty else { return }
        exportCacheDirectory = createTempDirectory(prefix: "export")
        guard exportCacheDirectory != nil else { return }
        isPreparingExport = true
        prepareProgress = 0
        DispatchQueue.global(qos: .userInitiated).async {
            for (idx, url) in self.mergedImageURLs.enumerated() {
                autoreleasepool {
                    if let img = loadPlatformImage(from: url, maxDimension: self.maxProcessingDimension) {
                        var data: Data?
                        var ext: String = ""
                        if let result = self.compress(image: img, maxSizeKB: self.maxFileSizeKB) {
                            data = result.0
                            ext = result.1
                        } else {
                            #if os(macOS)
                            data = img.tiffRepresentation
                            ext = "tiff"
                            #else
                            data = img.pngData()
                            ext = "png"
                            #endif
                        }
                        if let d = data, let dir = self.exportCacheDirectory {
                            let tempURL = dir.appendingPathComponent("export_\(idx).\(ext)")
                            try? d.write(to: tempURL)
                        }
                    }
                    DispatchQueue.main.async {
                        self.prepareProgress = Double(idx + 1) / Double(self.mergedImageURLs.count)
                    }
                }
            }
            DispatchQueue.main.async {
                self.isPreparingExport = false
            }
        }
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
                        if let img = loadPlatformImage(from: item.url, maxDimension: self.maxProcessingDimension) {
                            if let current = merged {
                                merged = self.merge(images: [current, img], direction: self.direction)
                            } else {
                                merged = img
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

    func merge(images: [PlatformImage], direction: MergeDirection) -> PlatformImage? {
        guard !images.isEmpty else { return nil }
        let totalSize = images.reduce(CGSize.zero) { partial, image in
            switch direction {
            case .horizontal:
                return CGSize(width: partial.width + image.size.width, height: max(partial.height, image.size.height))
            case .vertical:
                return CGSize(width: max(partial.width, image.size.width), height: partial.height + image.size.height)
            }
        }
        #if os(macOS)
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
        #else
        UIGraphicsBeginImageContextWithOptions(totalSize, false, 0)
        var current = CGPoint.zero
        for image in images {
            image.draw(at: current)
            switch direction {
            case .horizontal:
                current.x += image.size.width
            case .vertical:
                current.y += image.size.height
            }
        }
        let result = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return result
        #endif
    }

    func compress(image: PlatformImage, maxSizeKB: Int) -> (Data, String)? {
        #if os(macOS)
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
        #else
        var quality: CGFloat = 1.0
        let minQuality: CGFloat = 0.05
        let limit = maxSizeKB * 1024
        var data = image.jpegData(compressionQuality: quality)
        var currentImage = image

        while let d = data, d.count >= limit {
            if quality > minQuality {
                quality = max(minQuality, quality - 0.05)
            } else {
                let ratio: CGFloat = 0.95
                let newSize = CGSize(width: currentImage.size.width * ratio,
                                     height: currentImage.size.height * ratio)
                if newSize.width < 1 || newSize.height < 1 { break }
                UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
                currentImage.draw(in: CGRect(origin: .zero, size: newSize))
                let scaled = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                guard let scaledImage = scaled else { break }
                currentImage = scaledImage
            }
            data = currentImage.jpegData(compressionQuality: quality)
        }

        if let d = data {
            return (d, "jpg")
        }
        return nil
        #endif
    }

#if canImport(Photos)
    func saveExportedImagesToPhotos(completion: @escaping (Bool) -> Void) {
        let urls = exportFileURLs
        guard !urls.isEmpty, !isPreparingExport else {
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
                        success = success && s
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
                }
            }
        }
    }
#endif

    func exportAll(to directory: URL) {
        guard let cacheDir = exportCacheDirectory, !isPreparingExport else { return }
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
        vm.images = (1...3).compactMap { idx in
            guard let img = platformImageNamed("Placeholder\(idx)") else { return nil }
            return ImageItem(url: URL(fileURLWithPath: "placeholder\(idx).png"), preview: img)
        }
        vm.step1PreviewScale = 1.0
        vm.step2PreviewScale = 1.0
        vm.updatePreview()
        vm.batchMerge()
        return vm
    }
}
#endif
