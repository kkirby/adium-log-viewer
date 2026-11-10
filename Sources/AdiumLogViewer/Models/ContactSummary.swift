import Foundation

/// A contact folder directly under an `AccountFolder`. `contactUID` is treated as an
/// opaque, filesystem-sanitized display string — Adium's `safeFilenameString`
/// sanitization is never reversed, so contact identifiers containing characters like
/// "/" will appear sanitized here rather than as the original screen name.
struct ContactSummary: Identifiable, Hashable {
    var id: String { url.path }

    let contactUID: String
    let url: URL
    let account: AccountFolder

    /// Populated lazily after `discoverLogs(for:)` has run for this contact; nil
    /// until then so the sidebar walk never has to open every contact folder.
    var logCount: Int?
    var mostRecentDate: Date?

    init(url: URL, account: AccountFolder) {
        self.url = url
        self.account = account
        self.contactUID = url.lastPathComponent
        self.logCount = nil
        self.mostRecentDate = nil
    }

    static func == (lhs: ContactSummary, rhs: ContactSummary) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
