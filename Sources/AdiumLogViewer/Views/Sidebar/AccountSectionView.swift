import SwiftUI

struct AccountSectionView: View {
    let account: AccountFolder

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 1) {
                Text(account.accountUID)
                    .font(.headline)
                if !account.service.isEmpty {
                    Text(account.service)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        } icon: {
            Image(systemName: "person.crop.circle")
        }
    }
}
