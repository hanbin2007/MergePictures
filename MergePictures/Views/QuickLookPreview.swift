import SwiftUI
#if os(iOS)
import QuickLook

struct QuickLookPreview: UIViewControllerRepresentable {
    let urls: [URL]
    @Binding var isPresented: Bool
    var initialIndex: Int = 0

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        controller.delegate = context.coordinator
        controller.currentPreviewItemIndex = safeIndex(initialIndex)
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        context.coordinator.parent = self
        controller.reloadData()
    }

    private func safeIndex(_ i: Int) -> Int {
        guard !urls.isEmpty else { return 0 }
        return max(0, min(i, urls.count - 1))
    }

    class Coordinator: NSObject, QLPreviewControllerDataSource, QLPreviewControllerDelegate {
        var parent: QuickLookPreview
        init(_ parent: QuickLookPreview) { self.parent = parent }

        // MARK: QLPreviewControllerDataSource
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            parent.urls.count
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            parent.urls[index] as NSURL
        }

        // MARK: QLPreviewControllerDelegate
        func previewControllerDidDismiss(_ controller: QLPreviewController) {
            DispatchQueue.main.async { self.parent.isPresented = false }
        }
    }
}
#endif
