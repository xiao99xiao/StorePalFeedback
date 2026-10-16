#if os(iOS)
import SwiftUI
import UIKit

extension StorePalFeedback {
    /// Presents feedback from the specified view controller, keeping multiwindow apps in their own scene.
    @discardableResult
    public static func show(from presenter: UIViewController) -> Bool {
        guard presenter.viewIfLoaded?.window != nil, presenter.presentedViewController == nil else { return false }
        presenter.present(makeViewController(), animated: true)
        return true
    }

    /// Creates an iOS feedback controller for a custom presentation or navigation flow.
    public static func makeViewController() -> UIViewController {
        let controller = UIHostingController(rootView: StorePalFeedbackView())
        controller.modalPresentationStyle = .formSheet
        return controller
    }
}
#endif
