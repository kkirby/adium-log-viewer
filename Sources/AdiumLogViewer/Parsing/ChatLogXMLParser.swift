import Foundation

/// Parses a single Adium `.xml` chat log (root `<chat>` element, namespace
/// `http://purl.org/net/ulf/ns/0.4-02`) into a `Transcript`.
///
/// Uses `XMLParser` (SAX/streaming) rather than `XMLDocument` (DOM) so a large
/// transcript is never fully materialized as a node tree. Only `<chat>`'s direct
/// children (`<message>`/`<status>`/`<event>`) are treated structurally; each such
/// element's inner markup is reconstructed as a `String` (tags re-emitted verbatim,
/// text HTML-escaped) via the parser's own start/characters/end callbacks, which is
/// what `MessageHTMLRenderer` consumes later.
enum ChatLogXMLParser {
    static func parse(fileAt url: URL) throws -> Transcript {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw TranscriptParseError.fileUnreadable(underlying: error)
        }
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.shouldProcessNamespaces = false

        if !parser.parse() {
            // A completely empty/zero-entry chat is still a successful parse with
            // zero children, so only treat this as an error if XMLParser itself
            // reports one (as opposed to e.g. an empty file).
            if let error = delegate.capturedError ?? parser.parserError {
                throw TranscriptParseError.malformedXML(underlying: error)
            }
        }

        guard delegate.sawChatRoot else {
            throw TranscriptParseError.notAChatlog
        }

        return Transcript(
            account: delegate.account,
            service: delegate.service,
            adiumVersion: delegate.adiumVersion,
            entries: delegate.entries
        )
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        var sawChatRoot = false
        var account = ""
        var service = ""
        var adiumVersion: String?
        var entries: [TranscriptEntry] = []
        var capturedError: Error?

        private let timeFormatter: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f
        }()

        // State while inside a top-level <message>/<status> element.
        private var currentTopLevelName: String?
        private var currentAttributes: [String: String] = [:]
        private var innerXMLBuffer = ""
        private var innerDepth = 0

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            if currentTopLevelName == nil {
                switch elementName {
                case "chat":
                    sawChatRoot = true
                    account = attributeDict["account"] ?? ""
                    service = attributeDict["service"] ?? ""
                    adiumVersion = attributeDict["adiumversion"]
                case "message", "status", "event":
                    currentTopLevelName = elementName
                    currentAttributes = attributeDict
                    innerXMLBuffer = ""
                    innerDepth = 0
                default:
                    break
                }
            } else {
                innerDepth += 1
                innerXMLBuffer += renderStartTag(name: elementName, attributes: attributeDict)
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            guard currentTopLevelName != nil else { return }
            innerXMLBuffer += escapeHTML(string)
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?) {
            guard let topLevel = currentTopLevelName else { return }

            if elementName == topLevel && innerDepth == 0 {
                finishTopLevelElement(name: topLevel)
                currentTopLevelName = nil
                currentAttributes = [:]
                innerXMLBuffer = ""
                return
            }

            innerXMLBuffer += "</\(elementName)>"
            innerDepth -= 1
        }

        func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
            capturedError = parseError
        }

        private func finishTopLevelElement(name: String) {
            let time = currentAttributes["time"].flatMap { timeFormatter.date(from: $0) }
            let sender = currentAttributes["sender"] ?? ""
            let alias = currentAttributes["alias"]

            switch name {
            case "message":
                let isOutgoing = !account.isEmpty && sender.caseInsensitiveCompare(account) == .orderedSame
                let message = Message(
                    id: UUID(),
                    sender: sender,
                    alias: alias,
                    time: time,
                    isAuto: currentAttributes["auto"] == "true",
                    isOutgoing: isOutgoing,
                    rawInnerXML: innerXMLBuffer
                )
                entries.append(.message(message))
            case "status":
                let status = StatusEvent(
                    id: UUID(),
                    statusType: currentAttributes["type"] ?? "",
                    sender: sender,
                    alias: alias,
                    time: time,
                    rawInnerXML: innerXMLBuffer.isEmpty ? nil : innerXMLBuffer
                )
                entries.append(.status(status))
            case "event":
                let event = WindowEvent(
                    id: UUID(),
                    eventType: currentAttributes["type"] ?? "",
                    sender: sender,
                    time: time
                )
                entries.append(.event(event))
            default:
                break
            }
        }

        private func renderStartTag(name: String, attributes: [String: String]) -> String {
            var tag = "<\(name)"
            for (key, value) in attributes {
                tag += " \(key)=\"\(escapeHTML(value, attribute: true))\""
            }
            tag += ">"
            return tag
        }

        private func escapeHTML(_ string: String, attribute: Bool = false) -> String {
            var result = string
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
            if attribute {
                result = result.replacingOccurrences(of: "\"", with: "&quot;")
            }
            return result
        }
    }
}

extension ChatLogXMLParser {
    /// Lightweight fallback used when a filename has no parseable `(...)` date:
    /// aborts parsing as soon as the first `time=` attribute is seen anywhere in
    /// the document, mirroring `AIChatLog.m`'s date-probing behavior.
    static func probeFirstTimestamp(fileAt url: URL) -> Date? {
        guard let parser = XMLParser(contentsOf: url) else { return nil }
        let delegate = TimeProbeDelegate()
        parser.delegate = delegate
        parser.parse()
        return delegate.foundDate
    }

    private final class TimeProbeDelegate: NSObject, XMLParserDelegate {
        var foundDate: Date?
        private let formatter: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f
        }()

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            guard foundDate == nil, let timeString = attributeDict["time"] else { return }
            if let date = formatter.date(from: timeString) {
                foundDate = date
                parser.abortParsing()
            }
        }
    }
}
