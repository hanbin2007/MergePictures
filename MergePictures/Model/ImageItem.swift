import Foundation

struct ImageItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let preview: PlatformImage

    static func == (lhs: ImageItem, rhs: ImageItem) -> Bool {
        lhs.id == rhs.id && lhs.url == rhs.url
    }
}
