import AppKit

enum ExportPanel {
    /// Presents an `NSSavePanel` for an export of the given format. Characters that
    /// are awkward in filenames (`/`, `:`) are replaced in the suggested name.
    @MainActor
    static func chooseDestination(defaultName: String, format: ExportFormat) -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export as \(format.displayName)"
        panel.allowedContentTypes = [format.contentType]
        panel.canCreateDirectories = true
        panel.isExtensionHidden = false
        let safeName = defaultName
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
        panel.nameFieldStringValue = "\(safeName).\(format.fileExtension)"
        return panel.runModal() == .OK ? panel.url : nil
    }
}
