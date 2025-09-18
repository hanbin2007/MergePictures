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
    @Published var step: Step = .selectImages {
        didSet {
            // 进入预览后解锁所有 Step 指示器按钮
            if step == .previewAll && !images.isEmpty {
                stepIndicatorUnlockedAll = true
            }
        }
    }

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

    @Published var enableUniformScaling: Bool = false {
        didSet {
            clearMergedResults()
            updatePreview()
        }
    }

    @Published var scaleMode: ScaleMode = .auto {
        didSet {
            clearMergedResults()
            updatePreview()
        }
    }

    @Published var scaleStrategy: ScaleStrategy = .average {
        didSet {
            clearMergedResults()
            updatePreview()
        }
    }

    @Published var images: [ImageItem] = [] {
        didSet {
            clearMergedResults()
            updatePreview()
            // 清空图片后恢复初始状态（禁用 Preview/Export）
            if images.isEmpty {
                stepIndicatorUnlockedAll = false
            }
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
    // 进入 Preview 后，Step 指示器解锁所有按钮；清空图片时重置
    @Published var stepIndicatorUnlockedAll: Bool = false
    // Controls presenting the image list sheet on iOS compact layouts
    @Published var presentImageListSheet: Bool = false
    // Preview overlay state
    @Published var isPreviewPresented: Bool = false {
        didSet {
            if isPreviewPresented == false {
                qlPrefetchTask?.cancel()
                qlPrefetchTask = nil
            }
        }
    }
    @Published var previewURLs: [URL] = []
    @Published var previewStartIndex: Int = 0

    // Notice banner state
    @Published var showPreviewNotice: Bool = true
    private let hidePreviewNoticeKey = "hidePreviewNotice"
    // Settings presentation
    @Published var presentSettings: Bool = false

    // Preview quality setting (persisted)
    private let previewQualityKey = "previewQuality"
    @Published var previewQuality: PreviewQuality = .high {
        didSet {
            UserDefaults.standard.set(previewQuality.rawValue, forKey: previewQualityKey)
            clearMergedResults()
            updatePreview()
            if step == .previewAll && !isMerging {
                batchMerge()
            }
        }
    }

    // Import progress state
    @Published var isImporting: Bool = false
    @Published var importProgress: Double = 0

    // Quick Look prefetch management
    private var qlPrefetchTask: Task<Void, Never>?
    private let qlPrefetchRadius: Int = 1

    init() {
        // Persisted user choice: if hidden once-and-for-all, don't show
        showPreviewNotice = !UserDefaults.standard.bool(forKey: hidePreviewNoticeKey)
        if let raw = UserDefaults.standard.string(forKey: previewQualityKey),
           let q = PreviewQuality(rawValue: raw) {
            previewQuality = q
        } else {
            previewQuality = .high
        }
    }

    private let fileManager = FileManager.default
    private var previewMergeDimension: CGFloat {
        switch previewQuality {
        case .low: return 512
        case .medium: return 1024
        case .high: return 2048
        }
    }
    private var previewDecodeDimensionStep1: CGFloat {
        switch previewQuality {
        case .low: return 512
        case .medium: return 1024
        case .high: return 2048
        }
    }
    private var exportProcessingDimension: CGFloat { processingDimension(for: maxFileSizeKB) }
    private var mergeCacheDirectory: URL?
    private var exportCacheDirectory: URL?
    private var importCacheDirectory: URL?
    private var quickLookCacheDirectory: URL?
    private lazy var importDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyyMMdd-HHmmss-SSS"
        return df
    }()

    var scaleStrategyDescriptionKey: String {
        switch scaleStrategy {
        case .min: return "Scale Strategy Detail Min"
        case .max: return "Scale Strategy Detail Max"
        case .average: return "Scale Strategy Detail Average"
        }
    }

    var exportFileURLs: [URL] {
        guard let cacheDir = exportCacheDirectory else { return [] }
        return ((try? fileManager.contentsOfDirectory(at: cacheDir, includingPropertiesForKeys: nil)) ?? [])
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    deinit {
        cleanupDirectory(mergeCacheDirectory)
        cleanupDirectory(exportCacheDirectory)
        cleanupDirectory(importCacheDirectory)
        cleanupDirectory(quickLookCacheDirectory)
    }

    // MARK: - Preview Presentation

    /// Presents the preview overlay for all original images, starting at the tapped item.
    func presentPreviewForOriginal(_ item: ImageItem) {
        guard let start = images.firstIndex(where: { $0.id == item.id }) else { return }
        let urls = images.map { $0.url }
        startQuickLookPrefetch(urls: urls, startIndex: start)
        previewStartIndex = start
        // If an image list sheet is open (iPhone compact), close it first then present preview
        #if os(iOS)
        if presentImageListSheet {
            presentImageListSheet = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { [weak self] in
                self?.isPreviewPresented = true
            }
        } else {
            isPreviewPresented = true
        }
        #else
        isPreviewPresented = true
        #endif
    }

    /// Presents the preview overlay for merged preview images, starting at the given index.
    func presentPreviewForMerged(at index: Int) {
        guard !mergedImageURLs.isEmpty, mergedImageURLs.indices.contains(index) else { return }
        startQuickLookPrefetch(urls: mergedImageURLs, startIndex: index)
        previewStartIndex = index
        #if os(iOS)
        if presentImageListSheet {
            presentImageListSheet = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { [weak self] in
                self?.isPreviewPresented = true
            }
        } else {
            isPreviewPresented = true
        }
        #else
        isPreviewPresented = true
        #endif
    }

    // MARK: Notice banner actions
    func dismissPreviewNoticeOnce() {
        showPreviewNotice = false
    }
    func suppressPreviewNotice() {
        UserDefaults.standard.set(true, forKey: hidePreviewNoticeKey)
        showPreviewNotice = false
    }

    func resetPreviewNoticeSuppression() {
        UserDefaults.standard.removeObject(forKey: hidePreviewNoticeKey)
        showPreviewNotice = true
    }

    // MARK: - Quick Look on-demand preparation
    private func quickLookCompatibleURL(for url: URL, index: Int) -> URL {
        let allowedExts: Set<String> = ["jpg","jpeg","png","gif","heic","heif","tif","tiff","bmp","webp"]
        let ext = url.pathExtension.lowercased()
        guard !(allowedExts.contains(ext) && fileManager.fileExists(atPath: url.path)) else {
            return url
        }
        if quickLookCacheDirectory == nil {
            quickLookCacheDirectory = createTempDirectory(prefix: "quicklook")
        }
        guard let dir = quickLookCacheDirectory else { return url }
        if let img = loadPlatformImage(from: url) ?? loadPlatformImage(from: url, maxDimension: 4096) {
            let copyURL = dir.appendingPathComponent("ql_\(index).png")
            try? fileManager.removeItem(at: copyURL)
            try? savePlatformImage(img, to: copyURL)
            return copyURL
        }
        return url
    }

    private func startQuickLookPrefetch(urls: [URL], startIndex: Int) {
        // Base assignment without heavy processing
        previewURLs = urls
        // Cancel any ongoing prefetch
        qlPrefetchTask?.cancel()
        qlPrefetchTask = Task(priority: .utility) { [weak self] in
            guard let self = self else { return }
            // Ensure selected index is ready first
            if Task.isCancelled { return }
            let prepared = self.quickLookCompatibleURL(for: urls[startIndex], index: startIndex)
            await MainActor.run {
                if self.previewURLs.indices.contains(startIndex) {
                    self.previewURLs[startIndex] = prepared
                }
            }
            // Prefetch immediate neighbors silently
            let neighbors: [Int] = [startIndex - 1, startIndex + 1].filter { urls.indices.contains($0) }
            for i in neighbors {
                if Task.isCancelled { break }
                let prep = self.quickLookCompatibleURL(for: urls[i], index: i)
                if Task.isCancelled { break }
                await MainActor.run {
                    if self.previewURLs.indices.contains(i) {
                        self.previewURLs[i] = prep
                    }
                }
            }
        }
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
        guard !urls.isEmpty else { return }
        isImporting = true
        importProgress = 0
        let total = urls.count
        DispatchQueue.global(qos: .userInitiated).async {
            var collected: [ImageItem] = []
            for (idx, url) in urls.enumerated() {
                autoreleasepool {
                    #if os(iOS)
                    var needsStop = false
                    if url.startAccessingSecurityScopedResource() {
                        needsStop = true
                    }
                    defer { if needsStop { url.stopAccessingSecurityScopedResource() } }
                    #endif
                    guard let preview = loadPlatformImage(from: url, maxDimension: 256) else { return }
                    let addedAt = Date()
                    let ext = url.pathExtension.isEmpty ? "img" : url.pathExtension
                    let name = "photo-\(self.importDateFormatter.string(from: addedAt)).\(ext)"
                    collected.append(ImageItem(url: url, preview: preview, addedDate: addedAt, displayName: name))
                    DispatchQueue.main.async {
                        self.importProgress = Double(idx + 1) / Double(total)
                    }
                }
            }
            DispatchQueue.main.async {
                self.images.append(contentsOf: collected)
                self.sortImages()
                self.isImporting = false
            }
        }
    }

#if os(iOS)
    func addImages(items: [PhotosPickerItem]) async {
        await MainActor.run {
            isImporting = true
            importProgress = 0
            if importCacheDirectory == nil {
                importCacheDirectory = createTempDirectory(prefix: "import")
            }
        }
        guard let dir = await MainActor.run(body: { importCacheDirectory }) else { return }
        let total = max(items.count, 1)
        var results: [ImageItem] = []
        results.reserveCapacity(items.count)
        for (idx, item) in items.enumerated() {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let addedAt = Date()
                // Determine proper extension from data; default to jpeg for broad compatibility
                var ext = "jpg"
                var ut: UTType?
                if let src = CGImageSourceCreateWithData(data as CFData, nil),
                   let uti = CGImageSourceGetType(src) as String? {
                    ut = UTType(uti)
                }
                if let preferred = ut?.preferredFilenameExtension {
                    ext = preferred
                }
                let fileName = "photo-\(importDateFormatter.string(from: addedAt)).\(ext)"
                let url = dir.appendingPathComponent(fileName)
                // Fast-path: write original data; avoid re-encoding
                do {
                    try data.write(to: url)
                } catch {
                    // Fallback: attempt to re-encode if write fails
                    if let img = PlatformImage(data: data) {
                        try? savePlatformImage(img, to: url)
                    }
                }
                // Smaller thumbnail for sidebar performance
                if let preview = loadPlatformImage(from: url, maxDimension: 256) {
                    results.append(ImageItem(url: url, preview: preview, addedDate: addedAt, displayName: fileName))
                }
                await MainActor.run {
                    importProgress = Double(idx + 1) / Double(total)
                }
            }
        }
        await MainActor.run {
            images.append(contentsOf: results)
            sortImages()
            isImporting = false
        }
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
        let previewSource = images.prefix(mergeCount).compactMap { loadPlatformImage(from: $0.url, maxDimension: previewDecodeDimensionStep1) }
        previewImage = merge(images: previewSource, direction: direction)
    }


    func batchMerge() {
        clearMergedResults()
        mergeCacheDirectory = createTempDirectory(prefix: "merge")
        isMerging = true
        mergeProgress = 0
        DispatchQueue.global(qos: .userInitiated).async {
            var index = 0
            var group = 0
            while index < self.images.count {
                autoreleasepool {
                    let end = min(index + self.mergeCount, self.images.count)
                    let imgs: [PlatformImage] = self.images[index..<end].compactMap { item in
                        loadPlatformImage(from: item.url, maxDimension: self.previewMergeDimension)
                    }
                    if let result = self.merge(images: imgs, direction: self.direction), let dir = self.mergeCacheDirectory {
                        let fileURL = dir.appendingPathComponent("merged_\(group).png")
                        try? savePlatformImage(result, to: fileURL)
                        DispatchQueue.main.async {
                            self.mergedImageURLs.append(fileURL)
                        }
                    }
                    index += self.mergeCount
                    group += 1
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
                    let maxDim: CGFloat? = self.enableCompression ? self.exportProcessingDimension : nil
                    let imgs: [PlatformImage] = self.images[index..<end].compactMap { item in
                        loadPlatformImage(from: item.url, maxDimension: maxDim)
                    }
                    if let result = self.merge(images: imgs, direction: self.direction) {
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

        if !enableUniformScaling {
            // Original behavior: no scaling, just concatenate
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

        // Determine which dimension to unify
        let unifyWidth: Bool = {
            switch scaleMode {
            case .fitWidth: return true
            case .fitHeight: return false
            case .auto:
                return direction == .vertical // vertical stacking → unify widths
            }
        }()

        // Collect the dimension to unify for each image
        let dims: [CGFloat] = cgImages.map { cg in
            let w = CGFloat(cg.width)
            let h = CGFloat(cg.height)
            return unifyWidth ? w : h
        }

        // Compute the target dimension based on strategy
        let targetDim: CGFloat = {
            switch scaleStrategy {
            case .min:
                return dims.min() ?? dims.first ?? 0
            case .max:
                return dims.max() ?? dims.first ?? 0
            case .average:
                guard !dims.isEmpty else { return 0 }
                return dims.reduce(0, +) / CGFloat(dims.count)
            }
        }()

        // Compute scaled sizes and total canvas size
        var scaledSizes: [CGSize] = []
        scaledSizes.reserveCapacity(cgImages.count)

        for cg in cgImages {
            let w = CGFloat(cg.width)
            let h = CGFloat(cg.height)
            let scale = unifyWidth ? (targetDim / max(w, 0.0001)) : (targetDim / max(h, 0.0001))
            let newW = max(Int(w * scale), 1)
            let newH = max(Int(h * scale), 1)
            scaledSizes.append(CGSize(width: newW, height: newH))
        }

        let totalSize: CGSize = scaledSizes.reduce(into: .zero) { partial, size in
            switch direction {
            case .horizontal:
                partial.width += size.width
                partial.height = max(partial.height, size.height)
            case .vertical:
                partial.width = max(partial.width, size.width)
                partial.height += size.height
            }
        }

        guard totalSize.width > 0, totalSize.height > 0 else { return nil }

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

        var origin = CGPoint.zero
        for (cg, size) in zip(cgImages, scaledSizes) {
            let rect = CGRect(origin: origin, size: size)
            ctx.draw(cg, in: rect)
            switch direction {
            case .horizontal:
                origin.x += size.width
            case .vertical:
                origin.y += size.height
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
