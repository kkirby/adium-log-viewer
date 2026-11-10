import XCTest
@testable import AdiumLogViewer

final class ChatLogXMLParserTests: XCTestCase {
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

    private func write(_ xml: String, name: String = "test.xml") -> URL {
        let url = tempDir.appendingPathComponent(name)
        try! xml.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func testParsesMessagesStatusAndEvents() throws {
        let url = write(TestFixtures.sampleTranscriptXML)
        let transcript = try ChatLogXMLParser.parse(fileAt: url)

        XCTAssertEqual(transcript.account, "myscreenname")
        XCTAssertEqual(transcript.service, "AIM")
        XCTAssertEqual(transcript.entries.count, 5)

        guard case .event(let opened) = transcript.entries[0] else {
            return XCTFail("expected windowOpened event first")
        }
        XCTAssertEqual(opened.eventType, "windowOpened")

        guard case .message(let sent) = transcript.entries[1] else {
            return XCTFail("expected outgoing message second")
        }
        XCTAssertTrue(sent.isOutgoing)
        XCTAssertTrue(sent.rawInnerXML.contains("<b>there</b>"))
        XCTAssertNil(sent.alias)

        guard case .message(let received) = transcript.entries[2] else {
            return XCTFail("expected incoming message third")
        }
        XCTAssertFalse(received.isOutgoing)
        XCTAssertEqual(received.alias, "Bob")
        XCTAssertEqual(received.displayName, "Bob")
        // "&amp;" in the source must round-trip through the inner-XML reconstruction.
        XCTAssertTrue(received.rawInnerXML.contains("&amp;"))

        guard case .status(let status) = transcript.entries[3] else {
            return XCTFail("expected status change fourth")
        }
        XCTAssertEqual(status.statusType, "away")
        XCTAssertEqual(status.rawInnerXML, "be right back")

        guard case .event(let closed) = transcript.entries[4] else {
            return XCTFail("expected windowClosed event fifth")
        }
        XCTAssertEqual(closed.eventType, "windowClosed")
    }

    func testAliasFallsBackToSenderWhenAbsent() throws {
        let url = write(TestFixtures.sampleTranscriptXML)
        let transcript = try ChatLogXMLParser.parse(fileAt: url)
        guard case .message(let sent) = transcript.entries[1] else {
            return XCTFail()
        }
        XCTAssertEqual(sent.displayName, sent.sender)
    }

    func testAutoReplyFlag() throws {
        let xml = """
        <chat xmlns="http://purl.org/net/ulf/ns/0.4-02" account="me" service="AIM">
        <message sender="them" time="2020-01-01T00:00:00Z" auto="true"><div>away</div></message>
        </chat>
        """
        let transcript = try ChatLogXMLParser.parse(fileAt: write(xml))
        guard case .message(let message) = transcript.entries[0] else { return XCTFail() }
        XCTAssertTrue(message.isAuto)
    }

    func testMalformedXMLThrows() {
        let url = write(TestFixtures.malformedXML)
        XCTAssertThrowsError(try ChatLogXMLParser.parse(fileAt: url)) { error in
            guard let parseError = error as? TranscriptParseError, case .malformedXML = parseError else {
                return XCTFail("expected malformedXML error, got \(error)")
            }
        }
    }

    func testMissingFileThrowsFileUnreadable() {
        let missing = tempDir.appendingPathComponent("does-not-exist.xml")
        XCTAssertThrowsError(try ChatLogXMLParser.parse(fileAt: missing)) { error in
            guard let parseError = error as? TranscriptParseError, case .fileUnreadable = parseError else {
                return XCTFail("expected fileUnreadable error, got \(error)")
            }
        }
    }

    func testEmptyChatIsNotAnError() throws {
        let xml = """
        <chat xmlns="http://purl.org/net/ulf/ns/0.4-02" account="me" service="AIM"></chat>
        """
        let transcript = try ChatLogXMLParser.parse(fileAt: write(xml))
        XCTAssertEqual(transcript.entries.count, 0)
    }

    func testProbeFirstTimestampFindsEarliestTimeAttribute() {
        let url = write(TestFixtures.sampleTranscriptXML)
        let date = ChatLogXMLParser.probeFirstTimestamp(fileAt: url)
        XCTAssertNotNil(date)
    }
}
