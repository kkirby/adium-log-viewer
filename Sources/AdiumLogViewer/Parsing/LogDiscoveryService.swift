import Foundation

/// Walks an Adium-style Logs folder. Ports `AILoggerPlugin`'s non-recursive,
/// three-level `contentsOfDirectoryAtPath:` walk (account folders -> contact
/// folders -> individual logs) as three separate, independently-callable
/// entry points, so a caller only pays for the level it actually needs right now
/// (e.g. the sidebar only calls `discoverContacts` when a section is expanded).
struct LogDiscoveryService: Sendable {
    let root: LogRoot

    private let keys: [URLResourceKey] = [.isDirectoryKey]
    private let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles]
    private var fileManager: FileManager { .default }

    /// Level 1: `"<service>.<accountUID>"` folders directly under the root.
    func discoverAccounts() throws -> [AccountFolder] {
        try directoryContents(of: root.url)
            .filter { isDirectory($0) }
            .map { AccountFolder(url: $0) }
            .sorted { $0.folderName.localizedCaseInsensitiveCompare($1.folderName) == .orderedAscending }
    }

    /// Level 2: contact folders directly under one account folder.
    func discoverContacts(in account: AccountFolder) throws -> [ContactSummary] {
        try directoryContents(of: account.url)
            .filter { isDirectory($0) }
            .map { ContactSummary(url: $0, account: account) }
            .sorted { $0.contactUID.localizedCaseInsensitiveCompare($1.contactUID) == .orderedAscending }
    }

    /// Level 3: individual logs under one contact folder, classified by format and
    /// dated from the filename (falling back to a cheap XML probe, then to nil).
    func discoverLogs(for contact: ContactSummary) throws -> [ChatLogMetadata] {
        let items = try directoryContents(of: contact.url)
        var results: [ChatLogMetadata] = []

        for itemURL in items {
            guard let format = classify(itemURL) else { continue }
            let relativePath = relativePath(of: itemURL)
            let filename = itemURL.lastPathComponent
            var date = FilenameDateParser.date(fromFilename: filename)

            if date == nil, format == .xmlChatlogBundle || format == .xmlChatlogFlatFile {
                let xmlURL = xmlFileURL(forChatlogItem: itemURL, format: format)
                date = xmlURL.flatMap { ChatLogXMLParser.probeFirstTimestamp(fileAt: $0) }
            }

            results.append(ChatLogMetadata(
                relativePath: relativePath,
                url: itemURL,
                from: contact.account.accountUID,
                to: contact.contactUID,
                service: contact.account.service,
                date: date,
                format: format
            ))
        }

        return results.sorted { (lhs, rhs) in
            switch (lhs.date, rhs.date) {
            case let (l?, r?): return l > r
            case (nil, _?): return false
            case (_?, nil): return true
            case (nil, nil): return lhs.relativePath > rhs.relativePath
            }
        }
    }

    /// The actual `.xml` file for a `.chatlog` item, resolving the bundle-directory
    /// case (`<name>.chatlog/<name>.xml`) vs. the legacy flat-file case.
    func xmlFileURL(forChatlogItem itemURL: URL, format: LogFormat) -> URL? {
        switch format {
        case .xmlChatlogBundle:
            let base = itemURL.deletingPathExtension().lastPathComponent
            return itemURL.appendingPathComponent(base).appendingPathExtension("xml")
        case .xmlChatlogFlatFile:
            return itemURL
        case .legacyHTML:
            return nil
        }
    }

    // MARK: - Helpers

    private func directoryContents(of url: URL) throws -> [URL] {
        try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: keys, options: options)
    }

    private func isDirectory(_ url: URL) -> Bool {
        (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }

    private func classify(_ url: URL) -> LogFormat? {
        let ext = url.pathExtension.lowercased()
        let name = url.lastPathComponent

        if ext == "chatlog" {
            return isDirectory(url) ? .xmlChatlogBundle : .xmlChatlogFlatFile
        }
        if ext == "html" || ext == "bak" || name.hasSuffix(".AdiumHTMLLog") {
            return .legacyHTML
        }
        return nil
    }

    private func relativePath(of url: URL) -> String {
        let rootPath = root.url.standardizedFileURL.path
        let itemPath = url.standardizedFileURL.path
        if itemPath.hasPrefix(rootPath) {
            var relative = String(itemPath.dropFirst(rootPath.count))
            if relative.hasPrefix("/") { relative.removeFirst() }
            return relative
        }
        return itemPath
    }
}
