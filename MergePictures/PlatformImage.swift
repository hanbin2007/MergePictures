import Foundation
import SwiftUI
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

public func loadPlatformImage(from url: URL) -> PlatformImage? {
    #if os(macOS)
    return NSImage(contentsOf: url)
    #else
    return UIImage(contentsOfFile: url.path)
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
