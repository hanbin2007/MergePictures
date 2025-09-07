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
