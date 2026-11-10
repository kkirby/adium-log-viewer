import Foundation

/// One top-level folder directly under a `LogRoot`, named `"<serviceID>.<accountUID>"`
/// on disk (e.g. `AIM.myscreenname`, `Jabber.me@example.com`).
///
/// `accountUID` is derived by splitting the folder name on the *first* "." only,
/// so account identifiers that themselves contain a "." (Jabber JIDs, email-style
/// UIDs) are preserved intact. This mirrors `AIChatLog.m`'s `-initWithPath:`.
struct AccountFolder: Identifiable, Hashable {
    var id: String { folderName }

    let folderName: String
    let service: String
    let accountUID: String
    let url: URL

    init(url: URL) {
        self.url = url
        let folderName = url.lastPathComponent
        self.folderName = folderName

        if let dotRange = folderName.range(of: ".") {
            self.service = String(folderName[folderName.startIndex..<dotRange.lowerBound])
            self.accountUID = String(folderName[dotRange.upperBound...])
        } else {
            self.service = ""
            self.accountUID = folderName
        }
    }
}
