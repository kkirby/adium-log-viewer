import os

enum AppLog {
    static let discovery = Logger(subsystem: "us.kirbatski.AdiumLogViewer", category: "discovery")
    static let parsing = Logger(subsystem: "us.kirbatski.AdiumLogViewer", category: "parsing")
    static let search = Logger(subsystem: "us.kirbatski.AdiumLogViewer", category: "search")
}
