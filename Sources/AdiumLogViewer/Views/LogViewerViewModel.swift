import Foundation
import Observation

@MainActor
@Observable
final class LogViewerViewModel {
    var logRoot: LogRoot?
    var rootLoadError: String?

    private(set) var accounts: [AccountFolder] = []
    private(set) var contactsByAccount: [String: [ContactSummary]] = [:]
    private(set) var logsByContact: [String: [ChatLogMetadata]] = [:]

    var selectedAccountID: String?
    var selectedContactID: String?
    var selectedLogID: String?
    /// Accounts whose sidebar `DisclosureGroup` should render expanded. Owned here
    /// (rather than as local `@State` in `SidebarView`) so navigation that isn't a
    /// direct sidebar click — e.g. opening a search result — can also reveal the
    /// destination contact.
    var expandedAccountIDs: Set<String> = []

    private(set) var transcriptResult: TranscriptLoadResult?
    private(set) var isLoadingTranscript = false

    var searchQuery: String = ""
    private(set) var searchResults: [SearchResult] = []
    private(set) var isSearching = false
    /// Bumped by the Cmd-F menu command; `ContentView` observes this to move
    /// keyboard focus into the search field.
    var focusSearchTrigger = 0

    var showTimestamps: Bool {
        get { UserDefaults.standard.object(forKey: UserDefaultsKeys.showTimestamps) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: UserDefaultsKeys.showTimestamps) }
    }

    private(set) var foldersThatFailedToRead: [String] = []

    private var discoveryService: LogDiscoveryService?
    private var searchService: SearchIndexService?

    var selectedAccount: AccountFolder? {
        accounts.first { $0.id == selectedAccountID }
    }

    var selectedContact: ContactSummary? {
        guard let selectedAccountID else { return nil }
        return contactsByAccount[selectedAccountID]?.first { $0.id == selectedContactID }
    }

    var contactsForSelectedAccount: [ContactSummary] {
        guard let selectedAccountID else { return [] }
        return contactsByAccount[selectedAccountID] ?? []
    }

    var logsForSelectedContact: [ChatLogMetadata] {
        guard let selectedContactID else { return [] }
        return logsByContact[selectedContactID] ?? []
    }

    var selectedLog: ChatLogMetadata? {
        logsForSelectedContact.first { $0.id == selectedLogID }
    }

    // MARK: - Root selection

    func launchAutoDetect() {
        if let savedPath = UserDefaults.standard.string(forKey: UserDefaultsKeys.lastLogRootPath) {
            let url = URL(fileURLWithPath: savedPath)
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                setRoot(url)
                return
            }
        }
        if let detected = FolderPicker.detectDefaultAdiumLogsFolder() {
            setRoot(detected)
        }
    }

    func chooseFolder() {
        guard let url = FolderPicker.chooseFolder(prompt: "Choose Logs Folder") else { return }
        setRoot(url)
    }

    private func setRoot(_ url: URL) {
        let root = LogRoot(url: url)
        logRoot = root
        rootLoadError = nil
        discoveryService = LogDiscoveryService(root: root)
        searchService = SearchIndexService(discovery: discoveryService!)
        accounts = []
        contactsByAccount = [:]
        logsByContact = [:]
        selectedAccountID = nil
        selectedContactID = nil
        selectedLogID = nil
        transcriptResult = nil
        foldersThatFailedToRead = []
        UserDefaults.standard.set(url.path, forKey: UserDefaultsKeys.lastLogRootPath)
        loadAccounts()
    }

    // MARK: - Discovery

    private func loadAccounts() {
        guard let discoveryService else { return }
        Task {
            do {
                let accounts = try await Task.detached(priority: .userInitiated) {
                    try discoveryService.discoverAccounts()
                }.value
                self.accounts = accounts
            } catch {
                rootLoadError = "Could not read the chosen folder: \(error.localizedDescription)"
            }
        }
    }

    /// Loads (and caches) the contacts for an account without changing the current
    /// selection — used when a sidebar `DisclosureGroup` is expanded.
    func ensureContactsLoaded(for account: AccountFolder) {
        guard contactsByAccount[account.id] == nil, let discoveryService else { return }
        Task {
            do {
                let contacts = try await Task.detached(priority: .userInitiated) {
                    try discoveryService.discoverContacts(in: account)
                }.value
                contactsByAccount[account.id] = contacts
            } catch {
                foldersThatFailedToRead.append(account.folderName)
            }
        }
    }

    func selectContact(_ contact: ContactSummary) {
        selectedAccountID = contact.account.id
        selectedContactID = contact.id
        expandedAccountIDs.insert(contact.account.id)
        selectedLogID = nil
        transcriptResult = nil
        guard logsByContact[contact.id] == nil, let discoveryService else { return }
        Task {
            do {
                let logs = try await Task.detached(priority: .userInitiated) {
                    try discoveryService.discoverLogs(for: contact)
                }.value
                logsByContact[contact.id] = logs
                updateContactSummary(contact, logCount: logs.count, mostRecent: logs.first?.date)
            } catch {
                foldersThatFailedToRead.append(contact.contactUID)
            }
        }
    }

    private func updateContactSummary(_ contact: ContactSummary, logCount: Int, mostRecent: Date?) {
        guard var list = contactsByAccount[contact.account.id],
              let index = list.firstIndex(where: { $0.id == contact.id }) else { return }
        list[index].logCount = logCount
        list[index].mostRecentDate = mostRecent
        contactsByAccount[contact.account.id] = list
    }

    func selectLog(_ log: ChatLogMetadata) {
        selectedLogID = log.id
        transcriptResult = nil
        guard let discoveryService else { return }

        isLoadingTranscript = true
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                let outcome: TranscriptLoadResult.Outcome
                do {
                    let transcript: Transcript
                    switch log.format {
                    case .xmlChatlogBundle, .xmlChatlogFlatFile:
                        guard let xmlURL = discoveryService.xmlFileURL(forChatlogItem: log.url, format: log.format) else {
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
            }.value

            isLoadingTranscript = false
            if selectedLogID == log.id {
                transcriptResult = result
            }
        }
    }

    // MARK: - Search

    /// Intended to be driven by SwiftUI's `.task(id: searchQuery)`, which already
    /// cancels the previous invocation whenever the query text changes — so this
    /// only needs its own debounce delay, not separate cancellation bookkeeping.
    func performSearch() async {
        let query = searchQuery
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            searchResults = []
            isSearching = false
            return
        }
        guard let searchService else { return }

        isSearching = true
        try? await Task.sleep(nanoseconds: 250_000_000)
        guard !Task.isCancelled else { return }

        let results = (try? await searchService.search(query)) ?? []
        guard !Task.isCancelled else { return }

        searchResults = results
        isSearching = false
    }

    func openSearchResult(_ result: SearchResult) {
        ensureContactsLoaded(for: result.contact.account)
        selectContact(result.contact)
        selectLog(result.log)
        searchQuery = ""
        searchResults = []
    }
}
