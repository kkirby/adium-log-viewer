import Foundation

/// Loads one log item from disk into a `TranscriptLoadResult`, dispatching on its
/// on-disk format. Synchronous and nonisolated — callers run it off the main actor.
/// Shared by the transcript view and export so both parse logs identically.
enum TranscriptLoader {
    static func load(_ log: ChatLogMetadata, discovery: LogDiscoveryService) -> TranscriptLoadResult {
        let outcome: TranscriptLoadResult.Outcome
        do {
            let transcript: Transcript
            switch log.format {
            case .xmlChatlogBundle, .xmlChatlogFlatFile:
                guard let xmlURL = discovery.xmlFileURL(forChatlogItem: log.url, format: log.format) else {
                    throw TranscriptParseError.notAChatlog
                }
                transcript = try ChatLogXMLParser.parse(fileAt: xmlURL)
            case .legacyHTML:
                transcript = try LegacyHTMLLogParser.parse(fileAt: log.url)
            }
            outcome = .success(transcript)
        } catch let error as TranscriptParseError {
            outcome = .failure(error)
        } catch {
            outcome = .failure(.fileUnreadable(underlying: error))
        }
        return TranscriptLoadResult(metadata: log, outcome: outcome)
    }
}
