import SwiftUI

/// Renders a legacy HTML transcript's whole captured document as one block — no
/// per-message header chrome, since the document already contains its own
/// message-style-rendered sender/timestamp presentation.
struct RawHTMLBlockView: View {
    let block: RawHTMLBlock
    let baseURL: URL?

    @State private var rendered: AttributedString?

    var body: some View {
        Group {
            if let rendered {
                Text(rendered)
                    .textSelection(.enabled)
            } else {
                ProgressView()
            }
        }
        .task(id: block.id) {
            let html = block.html
            let url = baseURL
            rendered = await Task.detached(priority: .userInitiated) {
                MessageHTMLRenderer.renderDocument(html: html, baseURL: url)
            }.value
        }
    }
}
