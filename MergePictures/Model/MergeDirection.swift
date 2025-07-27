import Foundation

enum MergeDirection: String, CaseIterable, Identifiable {
    case vertical
    case horizontal

    var id: String { rawValue }
}
