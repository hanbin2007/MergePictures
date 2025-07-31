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
