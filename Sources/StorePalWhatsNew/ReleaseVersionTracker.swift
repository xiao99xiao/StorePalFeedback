import Foundation

@MainActor
struct ReleaseVersionTracker {
    let defaults: UserDefaults
    private let key = "com.storepal.lastSeenVersion"

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    func needsPresentation(version: String) -> Bool {
        guard !version.isEmpty else { return false }
        guard let previous = defaults.string(forKey: key), !previous.isEmpty else {
            defaults.set(version, forKey: key)
            return false
        }
        return previous != version
    }

    func markPresented(version: String) {
        guard !version.isEmpty else { return }
        defaults.set(version, forKey: key)
    }
}
