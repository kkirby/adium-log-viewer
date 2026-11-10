import Foundation

/// Reads a legacy `.html`/`.html.bak`/`.AdiumHTMLLog` transcript. Adium's own log
/// viewer (`AILogViewerWindowController.m`) and Spotlight importer both treat these
/// as an opaque HTML blob rather than parsing individual messages out of them —
/// there is no reliable per-message markup convention to key off, since the file is
/// a raw capture of whatever third-party message style was active when it was
/// written. This parser does the same: load the whole file and hand it to the HTML
/// renderer as one block.
enum LegacyHTMLLogParser {
    static func parse(fileAt url: URL) throws -> Transcript {
        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw TranscriptParseError.fileUnreadable(underlying: error)
        }

        guard let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw TranscriptParseError.notAChatlog
        }

        return Transcript(account: "", service: "", adiumVersion: nil, entries: [.rawHTML(RawHTMLBlock(html: html))])
    }
}
