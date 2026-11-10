import Foundation
import UniformTypeIdentifiers

enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case plainText
    case html

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .plainText: return "Text"
        case .html: return "HTML"
        }
    }

    var fileExtension: String {
        switch self {
        case .plainText: return "txt"
        case .html: return "html"
        }
    }

    var contentType: UTType {
        switch self {
        case .plainText: return .plainText
        case .html: return .html
        }
    }
}

/// Serializes one or more loaded transcripts into a single standalone `.txt` or
/// `.html` document. Pure (no I/O) and nonisolated, so it runs off the main actor
/// and is directly unit-testable.
enum TranscriptExporter {
    static func render(_ results: [TranscriptLoadResult], format: ExportFormat, title: String,
                       timeZone: TimeZone = .current, locale: Locale = .current) -> String {
        let formatters = Formatters(timeZone: timeZone, locale: locale)
        switch format {
        case .plainText: return plainText(results, title: title, formatters: formatters)
        case .html: return html(results, title: title, formatters: formatters)
        }
    }

    /// Orders logs oldest-first (undated last) so a multi-conversation export reads
    /// like one continuous history.
    static func chronological(_ logs: [ChatLogMetadata]) -> [ChatLogMetadata] {
        logs.sorted { lhs, rhs in
            switch (lhs.date, rhs.date) {
            case let (l?, r?) where l != r: return l < r
            case (nil, _?): return false
            case (_?, nil): return true
            default: return lhs.relativePath < rhs.relativePath
            }
        }
    }

    // MARK: - Plain text

    private static func plainText(_ results: [TranscriptLoadResult], title: String, formatters: Formatters) -> String {
        var sections: [String] = []
        if results.count > 1 {
            sections.append("\(title)\n\(String(repeating: "=", count: max(title.count, 8)))")
        }
        for result in results {
            var lines: [String] = []
            lines.append("Conversation with \(result.metadata.to)")
            lines.append(metaLine(for: result.metadata, formatters: formatters))
            lines.append(String(repeating: "-", count: 60))
            lines.append("")

            switch result.outcome {
            case .failure(let error):
                lines.append("[This conversation could not be read: \(error.localizedDescription)]")
            case .success(let transcript):
                for entry in transcript.entries {
                    lines.append(textLine(for: entry, formatters: formatters))
                }
            }
            sections.append(lines.joined(separator: "\n"))
        }
        return sections.joined(separator: "\n\n\n") + "\n"
    }

    private static func textLine(for entry: TranscriptEntry, formatters: Formatters) -> String {
        let stamp = entry.time.map { "[\(formatters.time.string(from: $0))] " } ?? ""
        switch entry {
        case .message(let message):
            let name = message.displayName + (message.isAuto ? " (autoreply)" : "")
            let body = XHTMLText.plainText(fromInnerXML: message.rawInnerXML)
            // Indent continuation lines so multi-line messages stay visually grouped.
            let indented = body.replacingOccurrences(of: "\n", with: "\n    ")
            return "\(stamp)\(name): \(indented)"
        case .status(let status):
            let detail = status.rawInnerXML.map(XHTMLText.plainText(fromInnerXML:)) ?? ""
            return "\(stamp)* \(status.summary)" + (detail.isEmpty ? "" : ": \(detail)")
        case .event(let event):
            return "\(stamp)— \(event.summary)"
        case .rawHTML(let block):
            let rendered = MessageHTMLRenderer.renderDocument(html: block.html, baseURL: nil)
            return XHTMLText.normalize(String(rendered.characters))
        }
    }

    // MARK: - HTML

    private static func html(_ results: [TranscriptLoadResult], title: String, formatters: Formatters) -> String {
        var out = """
        <!DOCTYPE html>
        <html lang="en">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escape(title))</title>
        <style>
        \(stylesheet)
        </style>
        </head>
        <body>

        """
        if results.count > 1 {
            out += "<h1>\(escape(title))</h1>\n"
        }
        for result in results {
            out += "<section class=\"conversation\">\n"
            out += "<header><h2>Conversation with \(escape(result.metadata.to))</h2>"
            out += "<p class=\"meta\">\(escape(metaLine(for: result.metadata, formatters: formatters)))</p></header>\n"
            switch result.outcome {
            case .failure(let error):
                out += "<p class=\"error\">This conversation could not be read: \(escape(error.localizedDescription))</p>\n"
            case .success(let transcript):
                for entry in transcript.entries {
                    out += htmlEntry(entry, formatters: formatters) + "\n"
                }
            }
            out += "</section>\n"
        }
        out += "</body>\n</html>\n"
        return out
    }

    private static func htmlEntry(_ entry: TranscriptEntry, formatters: Formatters) -> String {
        let timeTag = entry.time.map {
            "<time datetime=\"\(formatters.iso.string(from: $0))\">\(escape(formatters.time.string(from: $0)))</time>"
        } ?? ""
        switch entry {
        case .message(let message):
            let direction = message.isOutgoing ? "outgoing" : "incoming"
            let auto = message.isAuto ? " <span class=\"auto\">(autoreply)</span>" : ""
            return """
            <div class="entry message \(direction)"><div class="line"><span class="sender">\(escape(message.displayName))</span>\(auto) \(timeTag)</div><div class="body">\(message.rawInnerXML)</div></div>
            """
        case .status(let status):
            let detail = status.rawInnerXML.map { ": <span class=\"detail\">\($0)</span>" } ?? ""
            return "<div class=\"entry status\">\(escape(status.summary))\(detail) \(timeTag)</div>"
        case .event(let event):
            return "<div class=\"entry event\">\(escape(event.summary)) \(timeTag)</div>"
        case .rawHTML(let block):
            return "<div class=\"legacy\">\(legacyBody(block.html))</div>"
        }
    }

    /// Legacy logs are whole captured documents; embed only their `<body>` contents
    /// so the export stays a single well-formed document.
    static func legacyBody(_ html: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: "<body[^>]*>(.*)</body>",
                                                   options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let range = Range(match.range(at: 1), in: html) else {
            return html
        }
        return String(html[range])
    }

    static func escape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    private static let stylesheet = """
    :root { color-scheme: light dark; --fg: #1d1d1f; --muted: #6e6e73; --bg: #ffffff; --rule: #d2d2d7; --out: #0a66d8; }
    @media (prefers-color-scheme: dark) { :root { --fg: #f5f5f7; --muted: #98989d; --bg: #1c1c1e; --rule: #3a3a3c; --out: #4da3ff; } }
    body { font: 14px/1.45 -apple-system, BlinkMacSystemFont, "Helvetica Neue", sans-serif; color: var(--fg); background: var(--bg); max-width: 760px; margin: 0 auto; padding: 24px 16px; }
    h1 { font-size: 22px; }
    .conversation { border-top: 1px solid var(--rule); padding-top: 12px; margin-top: 28px; }
    .conversation header h2 { font-size: 17px; margin: 0; }
    .meta { color: var(--muted); margin: 2px 0 14px; font-size: 12px; }
    .entry { margin: 6px 0; }
    .message .sender { font-weight: 600; }
    .message.outgoing .sender { color: var(--out); }
    .message .body { overflow-wrap: anywhere; }
    .message .body img { max-width: 100%; }
    time, .auto { color: var(--muted); font-size: 11px; margin-left: 4px; }
    .status, .event { color: var(--muted); font-size: 12px; text-align: center; }
    .error { color: #c62828; }
    .legacy { overflow-x: auto; }
    """

    // MARK: - Shared

    private static func metaLine(for log: ChatLogMetadata, formatters: Formatters) -> String {
        let parts = [log.service, log.from, log.date.map(formatters.date.string(from:)) ?? "Unknown date"]
        return parts.filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private struct Formatters {
        let time: DateFormatter
        let date: DateFormatter
        let iso: ISO8601DateFormatter

        init(timeZone: TimeZone, locale: Locale) {
            time = DateFormatter()
            time.dateStyle = .none
            time.timeStyle = .medium
            time.timeZone = timeZone
            time.locale = locale

            date = DateFormatter()
            date.dateStyle = .full
            date.timeStyle = .short
            date.timeZone = timeZone
            date.locale = locale

            iso = ISO8601DateFormatter()
            iso.timeZone = timeZone
        }
    }
}
