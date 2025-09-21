import Foundation

struct ImageItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let preview: PlatformImage
    let addedDate: Date
    let displayName: String

    static func == (lhs: ImageItem, rhs: ImageItem) -> Bool {
        lhs.id == rhs.id && lhs.url == rhs.url
    }
}

// The underlying PlatformImage (UIImage/NSImage) is not Sendable, but we only
// pass these immutable wrappers across concurrency boundaries. Declare the
// struct as unchecked Sendable so Swift 6's strict checks allow it.
extension ImageItem: @unchecked Sendable {}
