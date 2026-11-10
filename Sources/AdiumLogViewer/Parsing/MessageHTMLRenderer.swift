import Foundation
import AppKit

/// Renders a message/status body's inner XHTML (as reconstructed by
/// `ChatLogXMLParser`) into an `AttributedString`, using Foundation's built-in HTML
/// importer rather than a live web view.
///
/// `WKWebView` was rejected: a webview per row is far too heavy for a virtualized
/// list, and a single whole-transcript webview loses native text selection, Find,
/// and Dynamic Type integration. A hand-rolled HTML mini-parser was also rejected:
/// `NSAttributedString`'s importer already handles the small subset Adium emits
/// (div/span+style/b/i/u/a/img) well, and maintaining an equivalent subset parser
/// isn't worth it for a personal tool.
enum MessageHTMLRenderer {
    /// Must be called off the main actor — `NSAttributedString(data:options:...)`
    /// with `.documentType: .html` is synchronous and can be slow on large input.
    static func render(innerXML: String, baseURL: URL?) -> AttributedString {
        let html = """
        <html>
        <head>
        <meta charset="utf-8">
        <style>
        body { font-family: -apple-system, sans-serif; font-size: 13px; margin: 0; }
        </style>
        </head>
        <body>\(innerXML)</body>
        </html>
        """
        return renderDocument(html: html, baseURL: baseURL, fallbackText: innerXML)
    }

    /// Renders an already-complete HTML document as-is (no wrapping shell) — used
    /// for legacy `.html`/`.AdiumHTMLLog` transcripts, which are whole captured
    /// documents rather than a bare message fragment. Must be called off the main
    /// actor for the same reason as `render(innerXML:baseURL:)`.
    static func renderDocument(html: String, baseURL: URL?) -> AttributedString {
        renderDocument(html: html, baseURL: baseURL, fallbackText: html)
    }

    private static func renderDocument(html: String, baseURL: URL?, fallbackText: String) -> AttributedString {
        guard let data = html.data(using: .utf8) else {
            return plainTextFallback(innerXML: fallbackText)
        }

        var options: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        if let baseURL {
            options[.baseURL] = baseURL
        }

        do {
            let nsAttributed = try NSAttributedString(data: data, options: options, documentAttributes: nil)
            return AttributedString(nsAttributed)
        } catch {
            AppLog.parsing.error("HTML import failed, falling back to plain text: \(error.localizedDescription)")
            return plainTextFallback(innerXML: fallbackText)
        }
    }

    /// Crude tag-stripping fallback so one malformed message never blanks a row.
    static func plainTextFallback(innerXML: String) -> AttributedString {
        AttributedString(stripTags(innerXML))
    }

    /// Removes tags and decodes the basic entities `ChatLogXMLParser` emits.
    static func stripTags(_ markup: String) -> String {
        var text = markup
        while let range = text.range(of: "<[^>]+>", options: .regularExpression) {
            text.removeSubrange(range)
        }
        text = text
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
        return text
    }
}
