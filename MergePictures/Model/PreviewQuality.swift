import Foundation

enum PreviewQuality: String, CaseIterable, Identifiable {
    case low
    case medium
    case high

    var id: String { rawValue }
}

