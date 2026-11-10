import XCTest
@testable import AdiumLogViewer

final class LegacyHTMLLogParserTests: XCTestCase {
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

    func testParsesWholeDocumentAsSingleRawHTMLEntry() throws {
        let html = "<html><body><div class=\"send\"><b>hey</b> there</div></body></html>"
        let url = tempDir.appendingPathComponent("Bob (2006-03-30).AdiumHTMLLog")
        try html.write(to: url, atomically: true, encoding: .utf8)

        let transcript = try LegacyHTMLLogParser.parse(fileAt: url)
        XCTAssertEqual(transcript.entries.count, 1)
        guard case .rawHTML(let block) = transcript.entries[0] else {
            return XCTFail("expected a single rawHTML entry")
        }
        XCTAssertEqual(block.html, html)
    }

    func testMissingFileThrowsFileUnreadable() {
        let missing = tempDir.appendingPathComponent("does-not-exist.html")
        XCTAssertThrowsError(try LegacyHTMLLogParser.parse(fileAt: missing)) { error in
            guard let parseError = error as? TranscriptParseError, case .fileUnreadable = parseError else {
                return XCTFail("expected fileUnreadable error, got \(error)")
            }
        }
    }
}
