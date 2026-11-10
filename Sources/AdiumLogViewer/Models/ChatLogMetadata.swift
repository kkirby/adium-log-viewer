import Foundation

/// How a single log item on disk should be parsed. Kept as an explicit enum so
/// `LogDiscoveryService` can classify each item it finds and parsing/rendering can
/// dispatch on it — this is the seam that keeps adding another on-disk format
/// (e.g. legacy HTML logs) additive rather than a rewrite.
enum LogFormat: Hashable {
    /// `<name>.chatlog` is a directory bundle containing `<name>.xml`.
    case xmlChatlogBundle
    /// `<name>.chatlog` is itself the XML file (older Adium versions).
    case xmlChatlogFlatFile
    /// `.html` / `.html.bak` / `.AdiumHTMLLog` — raw HTML fragment, no XML wrapper.
    case legacyHTML
}

/// Metadata about a single logged chat session, mirroring Adium's own `AIChatLog`
/// (relativePath/from/to/service/date) so discovery logic has a direct behavioral
/// reference to check against.
struct ChatLogMetadata: Identifiable, Hashable {
    var id: String { relativePath }

    /// Path relative to the `LogRoot`, used for stable identity/display and as the
    /// index key for the search cache.
    let relativePath: String
    /// Absolute path to the `.chatlog` bundle/file (or legacy HTML file) on disk.
    let url: URL
    let from: String
    let to: String
    let service: String
    /// nil only if neither the filename nor a probe of the file's own XML yielded a
    /// parseable date.
    let date: Date?
    let format: LogFormat
}
