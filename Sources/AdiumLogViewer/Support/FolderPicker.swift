import AppKit

enum FolderPicker {
    /// Presents a plain `NSOpenPanel` folder picker. No security-scoped bookmark
    /// handling — this app is intentionally unsandboxed, so a plain path is enough.
    @MainActor
    static func chooseFolder(prompt: String = "Choose") -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.prompt = prompt
        panel.message = "Choose the Adium Logs folder to browse."
        return panel.runModal() == .OK ? panel.url : nil
    }

    /// Probes the conventional Adium install location for a Logs folder, trying
    /// every profile under `Users/` since most installs only ever have one
    /// ("Default") but custom profile names are possible.
    static func detectDefaultAdiumLogsFolder() -> URL? {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let usersDir = appSupport.appendingPathComponent("Adium 2.0/Users")
        guard let profiles = try? fm.contentsOfDirectory(at: usersDir, includingPropertiesForKeys: [.isDirectoryKey]) else {
            return nil
        }
        for profile in profiles {
            let logs = profile.appendingPathComponent("Logs")
            var isDir: ObjCBool = false
            if fm.fileExists(atPath: logs.path, isDirectory: &isDir), isDir.boolValue {
                return logs
            }
        }
        return nil
    }
}
