import SwiftUI

struct SidebarView: View {
    let viewModel: LogViewerViewModel

    var body: some View {
        List(selection: contactSelectionBinding) {
            ForEach(viewModel.accounts) { account in
                DisclosureGroup(isExpanded: expandedBinding(for: account)) {
                    let contacts = viewModel.contactsByAccount[account.id]
                    if let contacts {
                        if contacts.isEmpty {
                            Text("No conversations found")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(contacts) { contact in
                                ContactRowView(contact: contact)
                                    .tag(contact.id)
                                    .contextMenu {
                                        ExportContactButtons(viewModel: viewModel, contact: contact)
                                    }
                            }
                        }
                    } else {
                        ProgressView()
                            .controlSize(.small)
                    }
                } label: {
                    AccountSectionView(account: account)
                }
            }
        }
        .listStyle(.sidebar)
        .overlay {
            if viewModel.accounts.isEmpty {
                Text("No accounts found in this folder")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var contactSelectionBinding: Binding<String?> {
        Binding(
            get: { viewModel.selectedContactID },
            set: { newID in
                guard let newID else { return }
                for contacts in viewModel.contactsByAccount.values {
                    if let contact = contacts.first(where: { $0.id == newID }) {
                        viewModel.selectContact(contact)
                        return
                    }
                }
            }
        )
    }

    private func expandedBinding(for account: AccountFolder) -> Binding<Bool> {
        Binding(
            get: { viewModel.expandedAccountIDs.contains(account.id) },
            set: { isExpanded in
                if isExpanded {
                    viewModel.expandedAccountIDs.insert(account.id)
                    viewModel.ensureContactsLoaded(for: account)
                } else {
                    viewModel.expandedAccountIDs.remove(account.id)
                }
            }
        )
    }
}
