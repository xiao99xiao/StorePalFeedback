import Foundation
import Testing
@testable import StorePalWhatsNew

@MainActor
@Test func upgradeIsOnlyConsumedAfterPresentation() {
    let suite = "com.storepal.tests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let tracker = ReleaseVersionTracker(defaults: defaults)
    #expect(!tracker.needsPresentation(version: ""))
    #expect(!tracker.needsPresentation(version: "1.0")) // first install
    #expect(!tracker.needsPresentation(version: "1.0"))
    #expect(tracker.needsPresentation(version: "1.1"))
    #expect(tracker.needsPresentation(version: "1.1")) // offline or missing note: retry later
    tracker.markPresented(version: "1.1")
    #expect(!tracker.needsPresentation(version: "1.1"))
    #expect(tracker.needsPresentation(version: "1.2"))
}
