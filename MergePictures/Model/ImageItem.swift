import Foundation
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct ImageItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let image: PlatformImage
}
