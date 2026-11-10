import SwiftUI

/// "Export as Text… / Export as HTML…" buttons for a single conversation.
struct ExportConversationButtons: View {
    let viewModel: LogViewerViewModel
    let log: ChatLogMetadata?

    var body: some View {
        ForEach(ExportFormat.allCases) { format in
            Button("Export Conversation as \(format.displayName)…") {
                if let log { viewModel.exportConversation(log, as: format) }
            }
        }
        .disabled(log == nil || viewModel.isExporting)
    }
}

/// Buttons that export every conversation with a contact into one file.
struct ExportContactButtons: View {
    let viewModel: LogViewerViewModel
    let contact: ContactSummary?

    var body: some View {
        ForEach(ExportFormat.allCases) { format in
            Button("Export All Conversations as \(format.displayName)…") {
                if let contact { viewModel.exportAllConversations(with: contact, as: format) }
            }
        }
        .disabled(contact == nil || viewModel.isExporting)
    }
}

/// File ▸ Export items, acting on the current selection.
struct ExportCommands: Commands {
    let viewModel: LogViewerViewModel

    var body: some Commands {
        CommandGroup(replacing: .importExport) {
            ExportConversationButtons(viewModel: viewModel, log: viewModel.selectedLog)
            Divider()
            ExportContactButtons(viewModel: viewModel, contact: viewModel.selectedContact)
        }
    }
}

/// Toolbar menu with the same actions as File ▸ Export.
struct ExportToolbarMenu: View {
    let viewModel: LogViewerViewModel

    var body: some View {
        Menu {
            ExportConversationButtons(viewModel: viewModel, log: viewModel.selectedLog)
            Divider()
            ExportContactButtons(viewModel: viewModel, contact: viewModel.selectedContact)
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .help("Export Conversations")
        .disabled(viewModel.selectedContact == nil)
    }
}
