import Foundation
import AppKit

struct ImageItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let image: NSImage
}
