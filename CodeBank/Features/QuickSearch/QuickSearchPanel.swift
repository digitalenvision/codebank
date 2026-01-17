import SwiftUI

/// Spotlight-style quick search panel
struct QuickSearchPanel: View {
    var onDismiss: () -> Void
    
    @State private var viewModel = QuickSearchViewModel()
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Search input
            searchField
            
            // Only show content below if there's something to show
            if !viewModel.searchQuery.isEmpty || !viewModel.recentSearches.isEmpty {
                Divider()
                
                // Results
                if viewModel.searchQuery.isEmpty {
                    recentSearches
                } else if viewModel.isSearching {
                    loadingView
                } else if viewModel.results.isEmpty {
                    noResultsView
                } else {
                    resultsList
                }
            }
        }
        .frame(width: 680)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear {
            isSearchFocused = true
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
        .onKeyPress(.downArrow) {
            viewModel.selectNext()
            return .handled
        }
        .onKeyPress(.upArrow) {
            viewModel.selectPrevious()
            return .handled
        }
        .onKeyPress(.return) {
            if let result = viewModel.selectedResult {
                revealResult(result)
            }
            return .handled
        }
        .onKeyPress(keys: [.return], phases: .down) { press in
            // Cmd+Return executes (for commands/SSH)
            if press.modifiers.contains(.command) {
                if let result = viewModel.selectedResult, result.item.isExecutable {
                    executeResult(result)
                    onDismiss()
                }
                return .handled
            }
            return .ignored
        }
    }
    
    // MARK: - Search Field
    
    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 24, weight: .light))
                .foregroundStyle(.secondary)
            
            TextField("Search CodeBank", text: $viewModel.searchQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 22, weight: .light))
                .focused($isSearchFocused)
            
            if !viewModel.searchQuery.isEmpty {
                Button {
                    viewModel.searchQuery = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // MARK: - Results List
    
    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(viewModel.results) { result in
                        QuickSearchResultRow(
                            result: result,
                            isSelected: viewModel.selectedResultId == result.id
                        ) {
                            // Click or Enter opens the item
                            revealResult(result)
                        } onExecute: {
                            executeResult(result)
                        }
                        .id(result.id)
                    }
                }
                .padding(8)
            }
            .onChange(of: viewModel.selectedResultId) { _, newId in
                if let id = newId {
                    withAnimation {
                        proxy.scrollTo(id, anchor: .center)
                    }
                }
            }
        }
    }
    
    // MARK: - Recent Searches
    
    private var recentSearches: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Recent")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                
                Spacer()
                
                Button("Clear") {
                    viewModel.clearRecentSearches()
                }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
            .padding(.bottom, 4)
            
            ForEach(viewModel.recentSearches, id: \.self) { search in
                Button {
                    viewModel.searchQuery = search
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "clock")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                        Text(search)
                            .font(.system(size: 14))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.clear)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 8)
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        HStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.7)
            Text("Searching...")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
    
    // MARK: - No Results View
    
    private var noResultsView: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundStyle(.tertiary)
            
            Text("No results for \"\(viewModel.searchQuery)\"")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }
    
    // MARK: - Actions
    
    private func executeResult(_ result: SearchResult) {
        viewModel.addToRecentSearches()
        Task {
            try? await AppState.shared.executeItem(result.item)
        }
    }
    
    private func revealResult(_ result: SearchResult) {
        viewModel.addToRecentSearches()
        
        let appState = AppState.shared
        appState.selectedItemId = result.item.id
        
        if let projectId = result.item.projectId {
            appState.selectedSidebarItem = .project(projectId)
        } else {
            appState.selectedSidebarItem = .allItems
        }
        
        // Bring main window to front
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        }
        
        onDismiss()
    }
}

#Preview {
    QuickSearchPanel {
        print("Dismissed")
    }
    .frame(height: 400)
}
