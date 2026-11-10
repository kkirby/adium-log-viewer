import SwiftUI

struct ContentView: View {
    let viewModel: LogViewerViewModel
    @FocusState private var searchFieldFocused: Bool

    var body: some View {
        if viewModel.logRoot == nil {
            FolderPickerView(viewModel: viewModel)
        } else {
            NavigationSplitView {
                SidebarView(viewModel: viewModel)
                    .navigationSplitViewColumnWidth(min: 180, ideal: 220)
            } content: {
                DateListView(viewModel: viewModel)
                    .navigationSplitViewColumnWidth(min: 200, ideal: 260)
            } detail: {
                TranscriptView(viewModel: viewModel)
            }
            .searchable(text: Binding(get: { viewModel.searchQuery }, set: { viewModel.searchQuery = $0 }),
                        placement: .toolbar,
                        prompt: "Search Transcripts")
            .searchFocused($searchFieldFocused)
            .onChange(of: viewModel.focusSearchTrigger) { _, _ in
                searchFieldFocused = true
            }
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button {
                        viewModel.chooseFolder()
                    } label: {
                        Image(systemName: "folder")
                    }
                    .help("Choose a Different Logs Folder")
                }
            }
            .overlay(alignment: .bottom) {
                if viewModel.isExporting {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("Exporting…").font(.caption)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 12)
                }
            }
            .alert("Export Failed", isPresented: Binding(
                get: { viewModel.exportError != nil },
                set: { if !$0 { viewModel.exportError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(viewModel.exportError ?? "")
            }
            .overlay(alignment: .top) {
                if !viewModel.foldersThatFailedToRead.isEmpty {
                    Text("\(viewModel.foldersThatFailedToRead.count) folder(s) could not be read")
                        .font(.caption)
                        .padding(6)
                        .background(.yellow.opacity(0.3), in: RoundedRectangle(cornerRadius: 6))
                        .padding(.top, 4)
                }
            }
        }
    }
}
