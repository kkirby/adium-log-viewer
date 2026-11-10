import Foundation

/// A single logged instant message.
struct Message: Identifiable, Hashable {
    let id: UUID
    let sender: String
    /// Present only when it differs from the raw sender UID; display name should
    /// fall back to `sender` when this is nil.
    let alias: String?
    let time: Date?
    let isAuto: Bool
    let isOutgoing: Bool
    /// Serialized inner XHTML markup of the `<message>` element's children, ready
    /// to be handed to `MessageHTMLRenderer`.
    let rawInnerXML: String

    var displayName: String { alias ?? sender }
}

/// A presence/status change (`<status>`), e.g. "went away", possibly with a message.
struct StatusEvent: Identifiable, Hashable {
    let id: UUID
    let statusType: String
    let sender: String
    let alias: String?
    let time: Date?
    let rawInnerXML: String?

    var displayName: String { alias ?? sender }

    var summary: String {
        "\(displayName) changed status to \(statusType.isEmpty ? "unknown" : statusType)"
    }
}

/// A chat window lifecycle event (`<event>`), e.g. "windowOpened"/"windowClosed".
struct WindowEvent: Identifiable, Hashable {
    let id: UUID
    let eventType: String
    let sender: String
    let time: Date?

    var summary: String {
        switch eventType {
        case "windowOpened": return "Conversation opened"
        case "windowClosed": return "Conversation closed"
        default: return eventType.isEmpty ? "Event" : eventType
        }
    }
}

/// A legacy `.html`/`.html.bak`/`.AdiumHTMLLog` transcript, rendered as a single
/// opaque block. These predate Adium's structured XML log format and are literal
/// captures of whatever the active message style displayed, so — like Adium's own
/// log viewer and Spotlight importer — no attempt is made to parse out individual
/// messages/senders/timestamps from the markup; it's rendered as-is.
struct RawHTMLBlock: Identifiable, Hashable {
    let id = UUID()
    let html: String
}

enum TranscriptEntry: Identifiable, Hashable {
    case message(Message)
    case status(StatusEvent)
    case event(WindowEvent)
    case rawHTML(RawHTMLBlock)

    var id: UUID {
        switch self {
        case .message(let m): return m.id
        case .status(let s): return s.id
        case .event(let e): return e.id
        case .rawHTML(let r): return r.id
        }
    }

    var time: Date? {
        switch self {
        case .message(let m): return m.time
        case .status(let s): return s.time
        case .event(let e): return e.time
        case .rawHTML: return nil
        }
    }
}

/// A fully parsed chat transcript, from a single `.xml`/`.chatlog` file.
struct Transcript {
    let account: String
    let service: String
    let adiumVersion: String?
    let entries: [TranscriptEntry]
}

enum TranscriptParseError: Error, LocalizedError {
    case fileUnreadable(underlying: Error)
    case malformedXML(underlying: Error?)
    case notAChatlog

    var errorDescription: String? {
        switch self {
        case .fileUnreadable(let underlying):
            return "Could not read the log file: \(underlying.localizedDescription)"
        case .malformedXML(let underlying):
            return "The transcript's XML could not be parsed" + (underlying.map { ": \($0.localizedDescription)" } ?? ".")
        case .notAChatlog:
            return "This does not look like an Adium chat log."
        }
    }
}

/// The outcome of attempting to load one `ChatLogMetadata` item's contents, wrapped
/// so a single bad file can never crash navigation — the caller always gets a value.
struct TranscriptLoadResult {
    let metadata: ChatLogMetadata
    let outcome: Outcome

    enum Outcome {
        case success(Transcript)
        case failure(TranscriptParseError)
    }
}
