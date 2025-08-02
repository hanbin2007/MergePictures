import Foundation

struct ImageItem: Identifiable, Equatable {
    let id = UUID()
    let url: URL
    let image: PlatformImage
}
