import Foundation

/// Converts a message body's inner XHTML (as reconstructed by `ChatLogXMLParser`,
/// which always emits well-formed markup) into plain text for `.txt` export.
///
/// Deliberately not routed through `NSAttributedString`'s HTML importer: that is
/// far too slow to run once per message across a contact's entire history.
enum XHTMLText {
    static func plainText(fromInnerXML xml: String) -> String {
        guard !xml.isEmpty, let data = "<root>\(xml)</root>".data(using: .utf8) else { return "" }
        let collector = Collector()
        let parser = XMLParser(data: data)
        parser.delegate = collector
        parser.shouldProcessNamespaces = false
        guard parser.parse() else {
            return normalize(MessageHTMLRenderer.stripTags(xml))
        }
        return normalize(collector.text)
    }

    /// Trims trailing whitespace per line and collapses runs of blank lines.
    static func normalize(_ text: String) -> String {
        let lines = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .components(separatedBy: "\n")
            .map { line -> String in
                var line = line
                while line.last?.isWhitespace == true { line.removeLast() }
                return line
            }
        var result: [String] = []
        for line in lines {
            if line.isEmpty, result.last?.isEmpty ?? true { continue }
            result.append(line)
        }
        while result.last?.isEmpty == true { result.removeLast() }
        return result.joined(separator: "\n")
    }

    private static let blockElements: Set<String> = ["div", "p", "li", "tr", "blockquote", "h1", "h2", "h3", "h4", "h5", "h6"]

    private final class Collector: NSObject, XMLParserDelegate {
        var text = ""

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            switch elementName.lowercased() {
            case "br":
                text += "\n"
            case "img":
                // Adium stores emoticons as <img alt=":)">; keep the textual form.
                if let alt = attributeDict["alt"] ?? attributeDict["title"], !alt.isEmpty {
                    text += alt
                }
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                    qualifiedName qName: String?) {
            if XHTMLText.blockElements.contains(elementName.lowercased()), !text.isEmpty, !text.hasSuffix("\n") {
                text += "\n"
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            text += string
        }
    }
}
