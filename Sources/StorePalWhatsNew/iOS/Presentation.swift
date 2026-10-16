#if os(iOS)
import SwiftUI
import UIKit
import StorePalFeedback

extension StorePalWhatsNew {
    /// Checks after an upgrade and presents in the supplied controller's scene.
    public static func check(from presenter: UIViewController) {
        Task { [weak presenter] in
            guard let note = await releaseNoteForUpdate(), !Task.isCancelled,
                  let presenter, presenter.viewIfLoaded?.window != nil,
                  presenter.presentedViewController == nil else { return }
            let controller = UIHostingController(rootView: StorePalWhatsNewView(note: note)
                .onAppear { markAsSeen(version: note.version) })
            controller.modalPresentationStyle = .formSheet
            presenter.present(controller, animated: true)
        }
    }

    /// Opens a sheet with loading, retry, and missing-note states.
    @discardableResult
    public static func show(from presenter: UIViewController, version: String? = nil) -> Bool {
        guard presenter.viewIfLoaded?.window != nil, presenter.presentedViewController == nil else { return false }
        presenter.present(makeViewController(version: version), animated: true)
        return true
    }

    public static func makeViewController(version: String? = nil) -> UIViewController {
        let controller = UIHostingController(rootView: WhatsNewLoaderView(version: version ?? currentVersion))
        controller.modalPresentationStyle = .formSheet
        return controller
    }
}

private struct PresentedRelease: Identifiable {
    let note: ReleaseNote
    var id: String { note.id }
}

private struct WhatsNewUpdateModifier: ViewModifier {
    @Environment(\.scenePhase) private var scenePhase
    @State private var release: PresentedRelease?

    func body(content: Content) -> some View {
        content
            .task { await check() }
            .onChange(of: scenePhase) { phase in
                if phase == .active { Task { await check() } }
            }
            .sheet(item: $release) { release in
                StorePalWhatsNewView(note: release.note)
                    .onAppear { StorePalWhatsNew.markAsSeen(version: release.note.version) }
            }
    }

    private func check() async {
        guard release == nil, let note = await StorePalWhatsNew.releaseNoteForUpdate(), !Task.isCancelled else { return }
        release = PresentedRelease(note: note)
    }
}

extension View {
    /// Attach once to the scene's root after configuring StorePal. Skips first install.
    public func whatsNewOnUpdate() -> some View { modifier(WhatsNewUpdateModifier()) }

    /// Manually opens an exact version, or the installed version by default.
    public func whatsNewSheet(isPresented: Binding<Bool>, version: String? = nil) -> some View {
        sheet(isPresented: isPresented) { WhatsNewLoaderView(version: version ?? StorePalWhatsNew.currentVersion) }
    }
}
#endif
