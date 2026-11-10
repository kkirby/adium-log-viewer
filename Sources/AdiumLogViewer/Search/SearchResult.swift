import Foundation

struct SearchResult: Identifiable {
    let id = UUID()
    let log: ChatLogMetadata
    let contact: ContactSummary
    let snippet: String
    let matchTime: Date?
}
