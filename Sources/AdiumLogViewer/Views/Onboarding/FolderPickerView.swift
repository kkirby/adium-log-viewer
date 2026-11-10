import SwiftUI

struct FolderPickerView: View {
    let viewModel: LogViewerViewModel
    private let detectedDefault = FolderPicker.detectDefaultAdiumLogsFolder()

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Adium Chat Transcript Viewer")
                .font(.title2).bold()
            Text("Choose the Adium “Logs” folder to browse.\nTypically at ~/Library/Application Support/Adium 2.0/Users/Default/Logs")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if let error = viewModel.rootLoadError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Choose Folder…") {
                    viewModel.chooseFolder()
                }
                .keyboardShortcut(.defaultAction)

                if let detectedDefault {
                    Button("Use Detected Logs Folder") {
                        viewModel.logRoot = nil
                        UserDefaults.standard.set(detectedDefault.path, forKey: UserDefaultsKeys.lastLogRootPath)
                        viewModel.launchAutoDetect()
                    }
                }
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
