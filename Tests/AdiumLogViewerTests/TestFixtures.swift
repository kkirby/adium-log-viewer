import Foundation

/// Builds a throwaway, on-disk Adium-style Logs folder tree for tests, mirroring
/// the real layout: `<root>/<service>.<accountUID>/<contactUID>/<name> (<date>).chatlog/<name>.xml`.
enum TestFixtures {
    static func makeTempRoot() -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("AdiumLogViewerTests-\(UUID().uuidString)")
        try! FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    static func writeChatlogBundle(
        root: URL,
        service: String,
        accountUID: String,
        contactUID: String,
        filenameDate: String,
        xml: String
    ) -> URL {
        let contactDir = root
            .appendingPathComponent("\(service).\(accountUID)")
            .appendingPathComponent(contactUID)
        try! FileManager.default.createDirectory(at: contactDir, withIntermediateDirectories: true)

        let baseName = "\(contactUID) (\(filenameDate))"
        let bundleDir = contactDir.appendingPathComponent("\(baseName).chatlog")
        try! FileManager.default.createDirectory(at: bundleDir, withIntermediateDirectories: true)

        let xmlURL = bundleDir.appendingPathComponent("\(baseName).xml")
        try! xml.write(to: xmlURL, atomically: true, encoding: .utf8)
        return bundleDir
    }

    static func writeLegacyHTMLLog(
        root: URL,
        service: String,
        accountUID: String,
        contactUID: String,
        filenameDate: String,
        html: String
    ) -> URL {
        let contactDir = root
            .appendingPathComponent("\(service).\(accountUID)")
            .appendingPathComponent(contactUID)
        try! FileManager.default.createDirectory(at: contactDir, withIntermediateDirectories: true)

        let fileURL = contactDir.appendingPathComponent("\(contactUID) (\(filenameDate)).AdiumHTMLLog")
        try! html.write(to: fileURL, atomically: true, encoding: .utf8)
        return fileURL
    }

    static let sampleTranscriptXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <chat xmlns="http://purl.org/net/ulf/ns/0.4-02" account="myscreenname" service="AIM" adiumversion="1.5.10" buildid="1">
    <event type="windowOpened" sender="myscreenname" time="2011-05-01T20:15:00-04:00"/>
    <message sender="myscreenname" time="2011-05-01T20:15:03-04:00"><div>hello <b>there</b></div></message>
    <message sender="theirscreenname" time="2011-05-01T20:15:10-04:00" alias="Bob"><div>hi &amp; welcome</div></message>
    <status type="away" sender="theirscreenname" time="2011-05-01T20:16:00-04:00" alias="Bob">be right back</status>
    <event type="windowClosed" sender="myscreenname" time="2011-05-01T20:17:00-04:00"/>
    </chat>
    """

    static let malformedXML = """
    <?xml version="1.0" encoding="UTF-8"?>
    <chat xmlns="http://purl.org/net/ulf/ns/0.4-02" account="myscreenname" service="AIM">
    <message sender="myscreenname" time="2011-05-01T20:15:03-04:00"><div>oops
    """
}
