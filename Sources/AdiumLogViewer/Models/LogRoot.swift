import Foundation

/// A user-picked folder that is expected to contain Adium-style logs
/// (typically `~/Library/Application Support/Adium 2.0/Users/<Profile>/Logs/`).
struct LogRoot: Identifiable, Codable, Equatable {
    let id: UUID
    var url: URL
    var displayName: String

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.displayName = url.lastPathComponent
    }
}
