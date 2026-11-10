import SwiftUI

struct DateListView: View {
    let viewModel: LogViewerViewModel

    var body: some View {
        Group {
            if viewModel.selectedContact == nil {
                ContentUnavailableView("Select a Contact", systemImage: "person")
            } else if viewModel.logsForSelectedContact.isEmpty {
                if viewModel.logsByContact[viewModel.selectedContactID ?? ""] == nil {
                    ProgressView()
                } else {
                    ContentUnavailableView("No conversations found", systemImage: "bubble.left.and.bubble.right")
                }
            } else {
                List(viewModel.logsForSelectedContact, selection: logSelectionBinding) { log in
                    DateListRowView(log: log)
                        .tag(log.id)
                        .contextMenu {
                            ExportConversationButtons(viewModel: viewModel, log: log)
                        }
                }
            }
        }
        .navigationTitle(viewModel.selectedContact?.contactUID ?? "")
    }

    private var logSelectionBinding: Binding<String?> {
        Binding(
            get: { viewModel.selectedLogID },
            set: { newID in
                guard let newID, let log = viewModel.logsForSelectedContact.first(where: { $0.id == newID }) else { return }
                viewModel.selectLog(log)
            }
        )
    }
}
