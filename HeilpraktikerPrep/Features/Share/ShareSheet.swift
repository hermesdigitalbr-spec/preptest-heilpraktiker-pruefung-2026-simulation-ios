import SwiftUI
import UIKit

/// Presents the system share sheet for arbitrary items (image + text), so the
/// user can post the result card to Stories, Messages, WhatsApp, Photos, etc.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {
        // On iPad the share sheet presents as a popover and UIKit requires a
        // valid anchor or it crashes / mis-anchors to the top-left. Anchor it
        // to the controller's own view, centered with no arrow. On iPhone
        // `popoverPresentationController` is nil (modal sheet), so this is a
        // no-op and the phone behavior is unchanged.
        if let popover = controller.popoverPresentationController {
            popover.sourceView = controller.view
            popover.sourceRect = CGRect(x: controller.view.bounds.midX,
                                        y: controller.view.bounds.midY,
                                        width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
    }
}
