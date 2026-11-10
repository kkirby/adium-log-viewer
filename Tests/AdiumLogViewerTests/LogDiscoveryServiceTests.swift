import XCTest
@testable import AdiumLogViewer

final class LogDiscoveryServiceTests: XCTestCase {
    var rootURL: URL!

    override func setUp() {
        super.setUp()
        rootURL = TestFixtures.makeTempRoot()
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: rootURL)
        super.tearDown()
    }

    private func service() -> LogDiscoveryService {
        LogDiscoveryService(root: LogRoot(url: rootURL))
    }

    func testDiscoverAccountsSplitsServiceAndAccountUID() throws {
        _ = TestFixtures.writeChatlogBundle(
            root: rootURL, service: "AIM", accountUID: "myscreenname", contactUID: "bob",
            filenameDate: "2011-05-01T20.15.03-0400", xml: TestFixtures.sampleTranscriptXML
        )
        let accounts = try service().discoverAccounts()
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0].service, "AIM")
        XCTAssertEqual(accounts[0].accountUID, "myscreenname")
    }

    func testAccountUIDContainingDotIsPreservedIntact() throws {
        // Jabber JIDs commonly contain "." in the UID itself; only the FIRST "."
        // in the folder name should be treated as the service/account separator.
        _ = TestFixtures.writeChatlogBundle(
            root: rootURL, service: "Jabber", accountUID: "me@example.com", contactUID: "friend@example.com",
            filenameDate: "2011-05-01T20.15.03-0400", xml: TestFixtures.sampleTranscriptXML
        )
        let accounts = try service().discoverAccounts()
        XCTAssertEqual(accounts.count, 1)
        XCTAssertEqual(accounts[0].service, "Jabber")
        XCTAssertEqual(accounts[0].accountUID, "me@example.com")
    }

    func testDiscoverContactsUnderAccount() throws {
        _ = TestFixtures.writeChatlogBundle(
            root: rootURL, service: "AIM", accountUID: "myscreenname", contactUID: "bob",
            filenameDate: "2011-05-01T20.15.03-0400", xml: TestFixtures.sampleTranscriptXML
        )
        _ = TestFixtures.writeChatlogBundle(
            root: rootURL, service: "AIM", accountUID: "myscreenname", contactUID: "alice",
            filenameDate: "2011-05-02T10.00.00-0400", xml: TestFixtures.sampleTranscriptXML
        )
        let account = try service().discoverAccounts()[0]
        let contacts = try service().discoverContacts(in: account)
        XCTAssertEqual(contacts.map(\.contactUID).sorted(), ["alice", "bob"])
    }

    func testDiscoverLogsClassifiesBundleAndSortsNewestFirst() throws {
        _ = TestFixtures.writeChatlogBundle(
            root: rootURL, service: "AIM", accountUID: "me", contactUID: "bob",
            filenameDate: "2011-05-01T20.15.03-0400", xml: TestFixtures.sampleTranscriptXML
        )
        _ = TestFixtures.writeChatlogBundle(
            root: rootURL, service: "AIM", accountUID: "me", contactUID: "bob",
            filenameDate: "2012-01-01T09.00.00-0400", xml: TestFixtures.sampleTranscriptXML
        )
        let svc = service()
        let account = try svc.discoverAccounts()[0]
        let contact = try svc.discoverContacts(in: account)[0]
        let logs = try svc.discoverLogs(for: contact)

        XCTAssertEqual(logs.count, 2)
        XCTAssertEqual(logs.allSatisfy { $0.format == .xmlChatlogBundle }, true)
        // Newest-first.
        XCTAssertGreaterThan(logs[0].date!, logs[1].date!)
    }

    func testDiscoverLogsFallsBackToXMLProbeWhenFilenameHasNoDate() throws {
        let contactDir = rootURL.appendingPathComponent("AIM.me").appendingPathComponent("bob")
        try FileManager.default.createDirectory(at: contactDir, withIntermediateDirectories: true)
        let bundleDir = contactDir.appendingPathComponent("bob.chatlog")
        try FileManager.default.createDirectory(at: bundleDir, withIntermediateDirectories: true)
        try TestFixtures.sampleTranscriptXML.write(
            to: bundleDir.appendingPathComponent("bob.xml"), atomically: true, encoding: .utf8
        )

        let svc = service()
        let account = try svc.discoverAccounts()[0]
        let contact = try svc.discoverContacts(in: account)[0]
        let logs = try svc.discoverLogs(for: contact)

        XCTAssertEqual(logs.count, 1)
        XCTAssertNotNil(logs[0].date, "should fall back to probing the XML's first time= attribute")
    }

    func testUnrecognizedFileIsExcludedFromResults() throws {
        _ = TestFixtures.writeChatlogBundle(
            root: rootURL, service: "AIM", accountUID: "me", contactUID: "bob",
            filenameDate: "2011-05-01T20.15.03-0400", xml: TestFixtures.sampleTranscriptXML
        )
        let contactDir = rootURL.appendingPathComponent("AIM.me").appendingPathComponent("bob")
        try "junk".write(to: contactDir.appendingPathComponent(".DS_Store"), atomically: true, encoding: .utf8)
        try "notes".write(to: contactDir.appendingPathComponent("notes.txt"), atomically: true, encoding: .utf8)

        let svc = service()
        let account = try svc.discoverAccounts()[0]
        let contact = try svc.discoverContacts(in: account)[0]
        let logs = try svc.discoverLogs(for: contact)

        XCTAssertEqual(logs.count, 1)
    }

    func testEmptyRootProducesNoAccounts() throws {
        let accounts = try service().discoverAccounts()
        XCTAssertEqual(accounts, [])
    }

    func testLegacyHTMLLogIsClassifiedAndDated() throws {
        _ = TestFixtures.writeLegacyHTMLLog(
            root: rootURL, service: "AIM", accountUID: "me", contactUID: "bob",
            filenameDate: "2006-03-30", html: "<html><body>hi</body></html>"
        )
        let svc = service()
        let account = try svc.discoverAccounts()[0]
        let contact = try svc.discoverContacts(in: account)[0]
        let logs = try svc.discoverLogs(for: contact)

        XCTAssertEqual(logs.count, 1)
        XCTAssertEqual(logs[0].format, .legacyHTML)
        let comps = Calendar(identifier: .gregorian).dateComponents([.year, .month, .day], from: logs[0].date!)
        XCTAssertEqual(comps.year, 2006)
        XCTAssertEqual(comps.month, 3)
        XCTAssertEqual(comps.day, 30)
    }

    func testMixedXMLAndLegacyHTMLLogsBothDiscovered() throws {
        _ = TestFixtures.writeChatlogBundle(
            root: rootURL, service: "AIM", accountUID: "me", contactUID: "bob",
            filenameDate: "2011-05-01T20.15.03-0400", xml: TestFixtures.sampleTranscriptXML
        )
        _ = TestFixtures.writeLegacyHTMLLog(
            root: rootURL, service: "AIM", accountUID: "me", contactUID: "bob",
            filenameDate: "2006-03-30", html: "<html><body>hi</body></html>"
        )
        let svc = service()
        let account = try svc.discoverAccounts()[0]
        let contact = try svc.discoverContacts(in: account)[0]
        let logs = try svc.discoverLogs(for: contact)

        XCTAssertEqual(logs.count, 2)
        XCTAssertEqual(Set(logs.map(\.format)), [.xmlChatlogBundle, .legacyHTML])
    }
}
