import SwiftUI

struct StatusEventRowView: View {
    let status: StatusEvent
    let showTimestamps: Bool

    @State private var rendered: AttributedString?

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .medium
        return f
    }()

    var body: some View {
        HStack(spacing: 4) {
            Spacer()
            Text(status.summary)
            if let rendered {
                Text(rendered)
            }
            if showTimestamps, let time = status.time {
                Text("(\(Self.timeFormatter.string(from: time)))")
            }
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.vertical, 2)
        .task(id: status.id) {
            guard let xml = status.rawInnerXML, !xml.isEmpty else { return }
            rendered = await Task.detached(priority: .userInitiated) {
                MessageHTMLRenderer.render(innerXML: xml, baseURL: nil)
            }.value
        }
    }
}

struct WindowEventRowView: View {
    let event: WindowEvent
    let showTimestamps: Bool

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .medium
        return f
    }()

    var body: some View {
        HStack {
            Spacer()
            Text(event.summary)
            if showTimestamps, let time = event.time {
                Text("(\(Self.timeFormatter.string(from: time)))")
            }
            Spacer()
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.vertical, 2)
    }}
