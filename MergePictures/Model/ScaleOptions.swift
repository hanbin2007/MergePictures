import Foundation

enum ScaleMode: String, CaseIterable, Identifiable {
    case auto
    case fitWidth
    case fitHeight

    var id: String { rawValue }
}

enum ScaleStrategy: String, CaseIterable, Identifiable {
    case min
    case max
    case average

    var id: String { rawValue }
}

