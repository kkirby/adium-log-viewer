import SwiftUI

@main
struct AdiumLogViewerApp: App {
    @State private var viewModel = LogViewerViewModel()

    var body: some Scene {
        WindowGroup("Adium Chat Transcript Viewer") {
            ContentView(viewModel: viewModel)
                .frame(minWidth: 900, minHeight: 600)
                .onAppear { viewModel.launchAutoDetect() }
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Choose Logs Folder…") {
                    viewModel.chooseFolder()
                }
                .keyboardShortcut("o", modifiers: [.command])
            }
            CommandGroup(after: .textEditing) {
                Button("Find") {
                    viewModel.focusSearchTrigger += 1
                }
                .keyboardShortcut("f", modifiers: [.command])
            }
            ExportCommands(viewModel: viewModel)
        }
    }
}
