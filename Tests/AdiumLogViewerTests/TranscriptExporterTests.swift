import XCTest
@testable import AdiumLogViewer

final class TranscriptExporterTests: XCTestCase {
    private let utc = TimeZone(identifier: "UTC")!
    private let posix = Locale(identifier: "en_US_POSIX")
    var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    private func metadata(path: String = "AIM.myscreenname/theirscreenname/a.chatlog", date: Date?) -> ChatLogMetadata {
        ChatLogMetadata(relativePath: path, url: tempDir.appendingPathComponent(path),
                        from: "myscreenname", to: "theirscreenname", service: "AIM",
                        date: date, format: .xmlChatlogFlatFile)
    }

    private func sampleResult() throws -> TranscriptLoadResult {
        let url = tempDir.appendingPathComponent("sample.xml")
        try TestFixtures.sampleTranscriptXML.write(to: url, atomically: true, encoding: .utf8)
        let transcript = try ChatLogXMLParser.parse(fileAt: url)
        return TranscriptLoadResult(metadata: metadata(date: Date(timeIntervalSince1970: 1_304_295_300)),
                                    outcome: .success(transcript))
    }

    // MARK: - XHTMLText

    func testPlainTextDecodesEntitiesAndBreaks() {
        let text = XHTMLText.plainText(fromInnerXML: "<div>a &amp; b<br></br>c &lt;3 <img alt=\":)\" src=\"x.png\"></img></div>")
        XCTAssertEqual(text, "a & b\nc <3 :)")
    }

    func testPlainTextFallsBackOnMalformedMarkup() {
        XCTAssertEqual(XHTMLText.plainText(fromInnerXML: "<div>unclosed <b>bold"), "unclosed bold")
    }

    // MARK: - Plain text export

    func testPlainTextExportContainsMessagesStatusAndEvents() throws {
        let text = TranscriptExporter.render([try sampleResult()], format: .plainText,
                                             title: "Conversation with theirscreenname", timeZone: utc, locale: posix)
        XCTAssertTrue(text.hasPrefix("Conversation with theirscreenname\nAIM · myscreenname · "))
        // DateFormatter may use a narrow no-break space before AM/PM, so match around it.
        XCTAssertTrue(text.contains("[12:15:03"), text)
        XCTAssertTrue(text.contains("] myscreenname: hello there\n"), text)
        XCTAssertTrue(text.contains("] Bob: hi & welcome\n"))
        XCTAssertTrue(text.contains("] * Bob changed status to away: be right back\n"))
        XCTAssertTrue(text.contains("] — Conversation closed"))
        XCTAssertFalse(text.contains("<div>"))
    }

    func testPlainTextIndentsMultilineMessages() {
        let message = Message(id: UUID(), sender: "me", alias: nil, time: nil, isAuto: false,
                              isOutgoing: true, rawInnerXML: "<div>one<br></br>two</div>")
        let transcript = Transcript(account: "me", service: "AIM", adiumVersion: nil, entries: [.message(message)])
        let text = TranscriptExporter.render([TranscriptLoadResult(metadata: metadata(date: nil), outcome: .success(transcript))],
                                             format: .plainText, title: "t")
        XCTAssertTrue(text.contains("me: one\n    two\n"), text)
    }

    func testLegacyHTMLLogExportsAsPlainText() {
        let block = RawHTMLBlock(html: "<html><body><p>hello <b>world</b></p></body></html>")
        let transcript = Transcript(account: "", service: "", adiumVersion: nil, entries: [.rawHTML(block)])
        let text = TranscriptExporter.render([TranscriptLoadResult(metadata: metadata(date: nil), outcome: .success(transcript))],
                                             format: .plainText, title: "t")
        XCTAssertTrue(text.contains("hello world"), text)
        XCTAssertFalse(text.contains("<b>"))
    }

    func testFailedConversationIsNotedRatherThanDropped() {
        let failed = TranscriptLoadResult(metadata: metadata(date: nil), outcome: .failure(.notAChatlog))
        let text = TranscriptExporter.render([failed], format: .plainText, title: "t")
        XCTAssertTrue(text.contains("could not be read"))
    }

    // MARK: - HTML export

    func testHTMLExportIsStandaloneDocumentWithEscapedNames() throws {
        let message = Message(id: UUID(), sender: "x", alias: "<Bob & Co>", time: nil, isAuto: false,
                              isOutgoing: false, rawInnerXML: "<div>hi <b>there</b></div>")
        let transcript = Transcript(account: "me", service: "AIM", adiumVersion: nil, entries: [.message(message)])
        let html = TranscriptExporter.render(
            [try sampleResult(), TranscriptLoadResult(metadata: metadata(path: "b", date: nil), outcome: .success(transcript))],
            format: .html, title: "Conversations with theirscreenname")

        XCTAssertTrue(html.hasPrefix("<!DOCTYPE html>"))
        XCTAssertTrue(html.contains("<h1>Conversations with theirscreenname</h1>"))
        XCTAssertEqual(html.components(separatedBy: "<section class=\"conversation\">").count - 1, 2)
        XCTAssertTrue(html.contains("&lt;Bob &amp; Co&gt;"))
        XCTAssertTrue(html.contains("<div class=\"body\"><div>hi <b>there</b></div></div>"))
        XCTAssertTrue(html.contains("message outgoing"))
        XCTAssertTrue(html.hasSuffix("</html>\n"))
    }

    func testLegacyBodyExtraction() {
        XCTAssertEqual(TranscriptExporter.legacyBody("<html><head><style>x</style></head><BODY class=\"a\">hi</BODY></html>"), "hi")
        XCTAssertEqual(TranscriptExporter.legacyBody("<div>fragment</div>"), "<div>fragment</div>")
    }

    // MARK: - Ordering

    func testChronologicalOrdersOldestFirstWithUndatedLast() {
        let logs = [
            metadata(path: "new", date: Date(timeIntervalSince1970: 200)),
            metadata(path: "undated", date: nil),
            metadata(path: "old", date: Date(timeIntervalSince1970: 100)),
        ]
        XCTAssertEqual(TranscriptExporter.chronological(logs).map(\.relativePath), ["old", "new", "undated"])
    }
}
