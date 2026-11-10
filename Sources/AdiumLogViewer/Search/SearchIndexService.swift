import Foundation

/// Lazy, in-memory search over a `LogRoot`. Deliberately avoids reimplementing
/// SearchKit or standing up a persistent index/database — for a personal-scale
/// collection (thousands of files, tens of MB) a metadata walk plus an on-demand
/// raw-text scan is fast enough and much simpler.
///
/// Known limitation: matching is a plain substring search against each log's raw
/// XML text, so a query phrase that happens to be split across an HTML tag
/// boundary (e.g. mid-word bold) can produce a false negative. Acceptable for v1.
actor SearchIndexService {
    private let discovery: LogDiscoveryService
    private var cachedIndex: [(contact: ContactSummary, log: ChatLogMetadata)]?

    /// Files are read concurrently in batches of this size so a very large
    /// collection doesn't open thousands of file handles at once.
    private let batchSize = 32

    init(discovery: LogDiscoveryService) {
        self.discovery = discovery
    }

    /// Walks the entire root once (metadata/filenames only, no file content read)
    /// and caches the flat list for subsequent searches. Cheap even for thousands
    /// of logs since it never opens a chat transcript's contents.
    func buildIndexIfNeeded() async throws -> [(contact: ContactSummary, log: ChatLogMetadata)] {
        if let cachedIndex { return cachedIndex }

        var results: [(contact: ContactSummary, log: ChatLogMetadata)] = []
        let accounts = try discovery.discoverAccounts()
        for account in accounts {
            try Task.checkCancellation()
            let contacts = try discovery.discoverContacts(in: account)
            for contact in contacts {
                try Task.checkCancellation()
                let logs = try discovery.discoverLogs(for: contact)
                for log in logs {
                    results.append((contact, log))
                }
            }
        }
        cachedIndex = results
        return results
    }

    /// Cancelable, best-effort search. Callers should wrap this in a `Task` keyed
    /// to the query text (e.g. SwiftUI's `.task(id:)`) so a new keystroke cancels
    /// any still-running search for the previous query.
    func search(_ query: String) async throws -> [SearchResult] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return [] }

        let index = try await buildIndexIfNeeded()
        var results: [SearchResult] = []

        for batch in index.chunked(into: batchSize) {
            try Task.checkCancellation()
            try await withThrowingTaskGroup(of: SearchResult?.self) { group in
                for entry in batch {
                    group.addTask {
                        try Task.checkCancellation()
                        return Self.searchSingle(contact: entry.contact, log: entry.log, query: trimmed, discovery: self.discovery)
                    }
                }
                for try await result in group {
                    if let result { results.append(result) }
                }
            }
        }

        return results.sorted { (lhs, rhs) in
            (lhs.matchTime ?? .distantPast) > (rhs.matchTime ?? .distantPast)
        }
    }

    nonisolated private static func searchSingle(
        contact: ContactSummary, log: ChatLogMetadata, query: String, discovery: LogDiscoveryService
    ) -> SearchResult? {
        let contentURL: URL?
        switch log.format {
        case .legacyHTML:
            contentURL = log.url
        case .xmlChatlogBundle, .xmlChatlogFlatFile:
            contentURL = discovery.xmlFileURL(forChatlogItem: log.url, format: log.format)
        }
        guard let contentURL, let rawText = try? String(contentsOf: contentURL, encoding: .utf8) else {
            return nil
        }
        guard rawText.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil else {
            return nil
        }

        // Only files with a raw hit get fully parsed, to build an accurate snippet.
        if log.format != .legacyHTML, let transcript = try? ChatLogXMLParser.parse(fileAt: contentURL) {
            for entry in transcript.entries {
                if case .message(let message) = entry {
                    let plain = MessageHTMLRenderer.plainTextFallback(innerXML: message.rawInnerXML)
                    let plainString = String(plain.characters)
                    if plainString.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                        return SearchResult(log: log, contact: contact, snippet: snippet(around: query, in: plainString), matchTime: message.time)
                    }
                }
                if case .status(let status) = entry, let inner = status.rawInnerXML {
                    let plain = String(MessageHTMLRenderer.plainTextFallback(innerXML: inner).characters)
                    if plain.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
                        return SearchResult(log: log, contact: contact, snippet: snippet(around: query, in: plain), matchTime: status.time)
                    }
                }
            }
        }

        // Fell back: matched the raw text but not any individual rendered entry
        // (legacy HTML log, or a match that landed on a tag/attribute) — still
        // report it, using a tag-stripped snippet so raw markup doesn't leak into
        // the results list.
        let plainRawText = String(MessageHTMLRenderer.plainTextFallback(innerXML: rawText).characters)
        let snippetSource = plainRawText.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            ? plainRawText
            : rawText
        return SearchResult(log: log, contact: contact, snippet: snippet(around: query, in: snippetSource), matchTime: log.date)
    }

    private static func snippet(around query: String, in text: String, contextChars: Int = 60) -> String {
        guard let range = text.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return String(text.prefix(contextChars * 2))
        }
        let start = text.index(range.lowerBound, offsetBy: -contextChars, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: contextChars, limitedBy: text.endIndex) ?? text.endIndex
        var result = String(text[start..<end])
        if start != text.startIndex { result = "…" + result }
        if end != text.endIndex { result += "…" }
        return result.replacingOccurrences(of: "\n", with: " ")
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
