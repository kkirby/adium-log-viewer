import SwiftUI

struct SearchResultsView: View {
    let viewModel: LogViewerViewModel

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    var body: some View {
        Group {
            if viewModel.isSearching && viewModel.searchResults.isEmpty {
                ProgressView("Searching…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.searchResults.isEmpty {
                ContentUnavailableView.search
            } else {
                List(viewModel.searchResults) { result in
                    Button {
                        viewModel.openSearchResult(result)
                    } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(result.contact.contactUID)
                                    .font(.headline)
                                Spacer()
                                if let time = result.matchTime {
                                    Text(Self.dateFormatter.string(from: time))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(result.snippet)
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 3)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .task(id: viewModel.searchQuery) {
            await viewModel.performSearch()
        }
    }
}
