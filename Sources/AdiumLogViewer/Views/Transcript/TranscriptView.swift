import SwiftUI

struct TranscriptView: View {
    let viewModel: LogViewerViewModel

    var body: some View {
        Group {
            if !viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                SearchResultsView(viewModel: viewModel)
            } else if let result = viewModel.transcriptResult {
                loadedContent(for: result)
            } else if viewModel.isLoadingTranscript {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("Select a Conversation", systemImage: "text.bubble")
            }
        }
        .toolbar {
            ToolbarItem {
                Toggle(isOn: Binding(
                    get: { viewModel.showTimestamps },
                    set: { viewModel.showTimestamps = $0 }
                )) {
                    Image(systemName: "clock")
                }
                .help("Show Timestamps")
            }
        }
    }

    @ViewBuilder
    private func loadedContent(for result: TranscriptLoadResult) -> some View {
        switch result.outcome {
        case .success(let transcript):
            let baseURL = baseURL(for: result.metadata)
            ScrollViewReader { proxy in
                List(transcript.entries) { entry in
                    row(for: entry, baseURL: baseURL)
                        .id(entry.id)
                        .listRowSeparator(.hidden)
                }
                .onAppear {
                    if let last = transcript.entries.last {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        case .failure(let error):
            ContentUnavailableView {
                Label("Unable to Parse Transcript", systemImage: "exclamationmark.triangle")
            } description: {
                Text(error.localizedDescription)
            }
        }
    }

    @ViewBuilder
    private func row(for entry: TranscriptEntry, baseURL: URL?) -> some View {
        switch entry {
        case .message(let message):
            MessageRowView(message: message, baseURL: baseURL, showTimestamps: viewModel.showTimestamps)
        case .status(let status):
            StatusEventRowView(status: status, showTimestamps: viewModel.showTimestamps)
        case .event(let event):
            WindowEventRowView(event: event, showTimestamps: viewModel.showTimestamps)
        case .rawHTML(let block):
            RawHTMLBlockView(block: block, baseURL: baseURL)
        }
    }

    private func baseURL(for log: ChatLogMetadata) -> URL? {
        switch log.format {
        case .xmlChatlogBundle:
            return log.url
        case .xmlChatlogFlatFile:
            return log.url.deletingLastPathComponent()
        case .legacyHTML:
            return log.url.deletingLastPathComponent()
        }
    }
}
