import SwiftUI
#if os(iOS)
import UIKit

/// Presents a UIKit sheet with detents but without dimming the background.
/// Uses UISheetPresentationController and sets `largestUndimmedDetentIdentifier = .large`.
struct UndimmedDetentSheet<Content: View>: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let content: () -> Content

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .clear
        return vc
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {
        DispatchQueue.main.async {
            if isPresented {
                if context.coordinator.presented == nil {
                    let host = UIHostingController(rootView: content())
                    host.view.backgroundColor = .clear
                    host.modalPresentationStyle = .pageSheet
                    host.isModalInPresentation = true // disable interactive dismiss
                    if let sheet = host.sheetPresentationController {
                        if #available(iOS 16.0, *) {
                            let collapsed = UISheetPresentationController.Detent.custom(identifier: .init("collapsed")) { _ in
                                80 // completely collapsed height
                            }
                            let small = UISheetPresentationController.Detent.custom(identifier: .init("forty")) { ctx in
                                ctx.maximumDetentValue * 0.4
                            }
                            sheet.detents = [collapsed, small, .medium(), .large()]
                            sheet.selectedDetentIdentifier = small.identifier
                        } else {
                            sheet.detents = [.medium(), .large()]
                        }
                        sheet.largestUndimmedDetentIdentifier = .large
                        sheet.prefersGrabberVisible = true
                    }
                    let presenter = topViewController(from: uiViewController)
                    presenter?.present(host, animated: true)
                    context.coordinator.presented = host
                } else if let host = context.coordinator.presented as? UIHostingController<Content> {
                    host.rootView = content()
                }
            } else {
                if let presented = context.coordinator.presented {
                    presented.dismiss(animated: true)
                    context.coordinator.presented = nil
                }
            }
        }
    }

    private func topViewController(from base: UIViewController?) -> UIViewController? {
        // Find the top-most presenter from the given base controller
        var rootVC: UIViewController?
        if let base = base {
            rootVC = base
        } else {
            let scenes = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
            let keyWin = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
            rootVC = keyWin?.rootViewController ?? scenes.first?.windows.first?.rootViewController
        }
        var base = rootVC
        while let presented = base?.presentedViewController { base = presented }
        if let nav = base as? UINavigationController { return nav.visibleViewController }
        if let tab = base as? UITabBarController { return tab.selectedViewController }
        return base
    }

    class Coordinator {
        var presented: UIViewController?
    }
}
#endif
