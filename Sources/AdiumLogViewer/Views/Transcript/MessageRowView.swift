import SwiftUI

struct MessageRowView: View {
    let message: Message
    let baseURL: URL?
    let showTimestamps: Bool

    @State private var rendered: AttributedString?

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .medium
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Text(message.displayName)
                    .font(.subheadline).bold()
                    .foregroundStyle(message.isOutgoing ? .blue : .primary)
                if message.isAuto {
                    Text("(Autoreply)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if showTimestamps, let time = message.time {
                    Text(Self.timeFormatter.string(from: time))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Group {
                if let rendered {
                    Text(rendered)
                } else {
                    Text(" ")
                        .redacted(reason: .placeholder)
                }
            }
            .textSelection(.enabled)
        }
        .padding(.vertical, 2)
        .task(id: message.id) {
            let xml = message.rawInnerXML
            let url = baseURL
            let result = await Task.detached(priority: .userInitiated) {
                MessageHTMLRenderer.render(innerXML: xml, baseURL: url)
            }.value
            rendered = result
        }
    }
}
