import SwiftUI

struct DateListRowView: View {
    let log: ChatLogMetadata

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        HStack {
            Text(log.date.map(Self.formatter.string(from:)) ?? "Unknown Date")
            Spacer()
        }
    }
}
