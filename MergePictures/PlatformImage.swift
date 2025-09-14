import Foundation
import SwiftUI
import ImageIO
#if os(macOS)
import AppKit
public typealias PlatformImage = NSImage
#else
import UIKit
public typealias PlatformImage = UIImage
#endif

public extension Image {
    init(platformImage: PlatformImage) {
        #if os(macOS)
        self.init(nsImage: platformImage)
        #else
        self.init(uiImage: platformImage)
        #endif
    }
}

public func loadPlatformImage(from url: URL, maxDimension: CGFloat? = nil) -> PlatformImage? {
    guard let src = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
    var options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceShouldCache: false,
        kCGImageSourceShouldCacheImmediately: false
    ]
    if let max = maxDimension {
        options[kCGImageSourceThumbnailMaxPixelSize] = max
    } else if let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = props[kCGImagePropertyPixelHeight] as? CGFloat {
        options[kCGImageSourceThumbnailMaxPixelSize] = max(width, height)
    }
    guard let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary) else { return nil }
    #if os(macOS)
    return NSImage(cgImage: cg, size: .zero)
    #else
    return UIImage(cgImage: cg)
    #endif
}

public func platformImageNamed(_ name: String) -> PlatformImage? {
    #if os(macOS)
    return NSImage(named: name)
    #else
    return UIImage(named: name)
    #endif
}

/// Writes the provided platform image as a PNG file to the specified URL.
/// - Parameters:
///   - image: The platform-specific image instance.
///   - url: Destination file URL where the PNG data will be stored.
/// - Throws: Propagates any file system errors encountered during writing.
public func savePlatformImage(_ image: PlatformImage, to url: URL) throws {
    #if os(macOS)
    guard let tiff = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let data = rep.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "PlatformImage", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode image"])
    }
    try data.write(to: url)
    #else
    guard let data = image.pngData() else {
        throw NSError(domain: "PlatformImage", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to encode image"])
    }
    try data.write(to: url)
    #endif
}
