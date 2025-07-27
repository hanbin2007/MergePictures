import Foundation

enum Step: Int, CaseIterable {
    case selectImages = 0
    case previewAll
    case export

    var title: String {
        switch self {
        case .selectImages:
            return "Select"
        case .previewAll:
            return "Preview"
        case .export:
            return "Export"
        }
    }
}
