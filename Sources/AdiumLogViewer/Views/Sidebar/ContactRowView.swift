import SwiftUI

struct ContactRowView: View {
    let contact: ContactSummary

    var body: some View {
        HStack {
            Text(contact.contactUID)
            Spacer()
            if let count = contact.logCount {
                Text("\(count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
