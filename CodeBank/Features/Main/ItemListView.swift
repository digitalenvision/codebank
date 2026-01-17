import SwiftUI

/// List of items in the selected scope
struct ItemListView: View {
    @Environment(AppState.self) private var appState
    
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .name
    @State private var filterType: ItemType?
    @State private var showENVImport = false
    @State private var showMoveSheet = false
    
    enum SortOrder: String, CaseIterable {
        case name = "Name"
        case type = "Type"
        case dateCreated = "Date Created"
        case dateModified = "Date Modified"
    }
    
    var body: some View {
        @Bindable var state = appState
        
        // Access items to ensure view observes changes
        let _ = appState.items
        
        VStack(spacing: 0) {
            // Selection bar (shown when multiple items selected)
            if appState.selectedItemIds.count > 1 {
                selectionBar
                Divider()
            }
            
            // Header with filters
            filterBar
            
            Divider()
            
            // Item list with multi-selection
            if filteredAndSortedItems.isEmpty {
                emptyState
            } else {
                List(selection: $state.selectedItemIds) {
                    ForEach(filteredAndSortedItems) { item in
                        ItemRow(item: item)
                            .tag(item.id)
                            .contextMenu {
                                if appState.selectedItemIds.count > 1 && appState.selectedItemIds.contains(item.id) {
                                    multiSelectContextMenu
                                } else {
                                    itemContextMenu(for: item)
                                }
                            }
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .onKeyPress(.upArrow) {
                    navigateUp()
                    return .handled
                }
                .onKeyPress(.downArrow) {
                    navigateDown()
                    return .handled
                }
            }
        }
        .navigationTitle(navigationTitle)
        .id(appState.selectedSidebarItem)
        .onChange(of: appState.selectedItemIds) { _, newValue in
            // Update single selection for detail view (use first selected item)
            if let firstId = newValue.first, newValue.count == 1 {
                appState.selectedItemId = firstId
            } else if newValue.isEmpty {
                appState.selectedItemId = nil
            }
        }
        .sheet(isPresented: $showENVImport) {
            ENVImportView()
        }
        .sheet(isPresented: $showMoveSheet) {
            MoveToProjectSheet(itemIds: appState.selectedItemIds)
        }
        .alert("Delete \(appState.selectedItemIds.count) Items?", isPresented: $state.showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    if appState.selectedItemIds.count > 1 {
                        try? await appState.deleteSelectedItems()
                    } else {
                        try? await appState.deleteSelectedItem()
                    }
                }
            }
        } message: {
            if appState.selectedItemIds.count > 1 {
                Text("Are you sure you want to delete these \(appState.selectedItemIds.count) items? This cannot be undone.")
            } else if let item = appState.selectedItem {
                Text("Are you sure you want to delete \"\(item.name)\"? This cannot be undone.")
            }
        }
    }
    
    // MARK: - Selection Bar
    
    private var selectionBar: some View {
        HStack(spacing: 12) {
            Text("\(appState.selectedItemIds.count) items selected")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Button {
                showMoveSheet = true
            } label: {
                Label("Move", systemImage: "folder")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Button(role: .destructive) {
                appState.showDeleteConfirmation = true
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            
            Button {
                appState.clearSelection()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
    
    // MARK: - Keyboard Navigation
    
    private func navigateUp() {
        let items = filteredAndSortedItems
        guard !items.isEmpty else { return }
        
        if let currentId = appState.selectedItemIds.first,
           let currentIndex = items.firstIndex(where: { $0.id == currentId }),
           currentIndex > 0 {
            let newId = items[currentIndex - 1].id
            appState.selectedItemIds = [newId]
            appState.selectedItemId = newId
        } else if appState.selectedItemIds.isEmpty {
            let firstId = items[0].id
            appState.selectedItemIds = [firstId]
            appState.selectedItemId = firstId
        }
    }
    
    private func navigateDown() {
        let items = filteredAndSortedItems
        guard !items.isEmpty else { return }
        
        if let currentId = appState.selectedItemIds.first,
           let currentIndex = items.firstIndex(where: { $0.id == currentId }),
           currentIndex < items.count - 1 {
            let newId = items[currentIndex + 1].id
            appState.selectedItemIds = [newId]
            appState.selectedItemId = newId
        } else if appState.selectedItemIds.isEmpty {
            let firstId = items[0].id
            appState.selectedItemIds = [firstId]
            appState.selectedItemId = firstId
        }
    }
    
    // MARK: - Navigation Title
    
    private var navigationTitle: String {
        switch appState.selectedSidebarItem {
        case .allItems:
            return "All Items"
        case .project(let id):
            return appState.projects.first { $0.id == id }?.name ?? "Project"
        case .tag(let id):
            return appState.tags.first { $0.id == id }?.name ?? "Tag"
        case .settings:
            return "Settings"
        case .none:
            return ""
        }
    }
    
    // MARK: - Filtered Items
    
    private var filteredAndSortedItems: [Item] {
        var items = appState.filteredItems
        
        // Apply search filter
        if !searchText.isEmpty {
            items = items.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply type filter
        if let filterType = filterType {
            items = items.filter { $0.type == filterType }
        }
        
        // Apply sort
        switch sortOrder {
        case .name:
            items.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .type:
            items.sort { $0.type.rawValue < $1.type.rawValue }
        case .dateCreated:
            items.sort { $0.createdAt > $1.createdAt }
        case .dateModified:
            items.sort { $0.updatedAt > $1.updatedAt }
        }
        
        return items
    }
    
    // MARK: - Filter Bar
    
    private var filterBar: some View {
        HStack(spacing: 12) {
            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                
                TextField("Search items...", text: $searchText)
                    .textFieldStyle(.plain)
                
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(6)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
            }
            
            // Type filter
            Menu {
                Button("All Types") {
                    filterType = nil
                }
                
                Divider()
                
                ForEach(ItemType.allCases, id: \.self) { type in
                    Button {
                        filterType = type
                    } label: {
                        Label(type.displayName, systemImage: type.icon)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    if let filterType = filterType {
                        Image(systemName: filterType.icon)
                        Text(filterType.displayName)
                    } else {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                        Text("Filter")
                    }
                }
                .font(.caption)
            }
            .menuStyle(.borderlessButton)
            
            // Sort order
            Menu {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Button {
                        sortOrder = order
                    } label: {
                        HStack {
                            Text(order.rawValue)
                            if sortOrder == order {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text(sortOrder.rawValue)
                }
                .font(.caption)
            }
            .menuStyle(.borderlessButton)
        }
        .padding(8)
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: searchText.isEmpty ? "tray" : "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            if searchText.isEmpty {
                Text("No Items")
                    .font(.headline)
                
                Text("Add your first item to get started")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Menu("Add Item") {
                    Button {
                        appState.showNewItemEditor(type: .apiKey)
                    } label: {
                        Label("API Key", systemImage: "key.fill")
                        Text("⌘1")
                    }
                    
                    Button {
                        appState.showNewItemEditor(type: .database)
                    } label: {
                        Label("Database", systemImage: "cylinder.fill")
                        Text("⌘2")
                    }
                    
                    Button {
                        appState.showNewItemEditor(type: .server)
                    } label: {
                        Label("Server", systemImage: "server.rack")
                        Text("⌘3")
                    }
                    
                    Button {
                        appState.showNewItemEditor(type: .ssh)
                    } label: {
                        Label("SSH Connection", systemImage: "terminal.fill")
                        Text("⌘4")
                    }
                    
                    Button {
                        appState.showNewItemEditor(type: .command)
                    } label: {
                        Label("Command", systemImage: "command")
                        Text("⌘5")
                    }
                    
                    Button {
                        appState.showNewItemEditor(type: .secureNote)
                    } label: {
                        Label("Secure Note", systemImage: "doc.text.fill")
                        Text("⌘6")
                    }
                    
                    Divider()
                    
                    Button {
                        showENVImport = true
                    } label: {
                        Label("Import ENV File...", systemImage: "doc.text.fill.viewfinder")
                    }
                }
                .menuStyle(.borderedButton)
            } else {
                Text("No Results")
                    .font(.headline)
                
                Text("Try a different search term")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Context Menu (Single Item)
    
    @ViewBuilder
    private func itemContextMenu(for item: Item) -> some View {
        Button {
            Task {
                try? await appState.toggleFavorite(item)
            }
        } label: {
            Label(item.isFavorite ? "Remove from Favorites" : "Add to Favorites", 
                  systemImage: item.isFavorite ? "star.slash" : "star")
        }
        
        Divider()
        
        Button {
            appState.copyItemValue(item)
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        
        Button {
            Task {
                try? await appState.duplicateItem(item)
            }
        } label: {
            Label("Duplicate", systemImage: "plus.square.on.square")
        }
        
        if item.isExecutable {
            Button {
                Task {
                    try? await appState.executeItem(item)
                }
            } label: {
                Label(item.type == .ssh ? "Connect" : "Run", systemImage: item.type == .ssh ? "terminal" : "play.fill")
            }
        }
        
        Divider()
        
        // Move to project submenu
        Menu {
            Button {
                appState.selectedItemIds = [item.id]
                Task {
                    try? await appState.moveSelectedItems(to: nil)
                }
            } label: {
                Label("No Project", systemImage: "tray")
            }
            
            if !appState.projects.isEmpty {
                Divider()
                
                ForEach(appState.projects) { project in
                    Button {
                        appState.selectedItemIds = [item.id]
                        Task {
                            try? await appState.moveSelectedItems(to: project.id)
                        }
                    } label: {
                        Label(project.name, systemImage: project.icon)
                    }
                    .disabled(item.projectId == project.id)
                }
            }
        } label: {
            Label("Move to Project", systemImage: "folder")
        }
        
        Divider()
        
        Button {
            appState.showEditItemEditor(item)
        } label: {
            Label("Edit", systemImage: "pencil")
        }
        
        Button(role: .destructive) {
            appState.selectedItemIds = [item.id]
            appState.selectedItemId = item.id
            appState.showDeleteConfirmation = true
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }
    
    // MARK: - Context Menu (Multiple Items)
    
    @ViewBuilder
    private var multiSelectContextMenu: some View {
        Text("\(appState.selectedItemIds.count) items selected")
            .font(.caption)
            .foregroundStyle(.secondary)
        
        Divider()
        
        // Move to project submenu
        Menu {
            Button {
                Task {
                    try? await appState.moveSelectedItems(to: nil)
                }
            } label: {
                Label("No Project", systemImage: "tray")
            }
            
            if !appState.projects.isEmpty {
                Divider()
                
                ForEach(appState.projects) { project in
                    Button {
                        Task {
                            try? await appState.moveSelectedItems(to: project.id)
                        }
                    } label: {
                        Label(project.name, systemImage: project.icon)
                    }
                }
            }
        } label: {
            Label("Move to Project", systemImage: "folder")
        }
        
        Divider()
        
        Button(role: .destructive) {
            appState.showDeleteConfirmation = true
        } label: {
            Label("Delete \(appState.selectedItemIds.count) Items", systemImage: "trash")
        }
    }
}

// MARK: - Move to Project Sheet

struct MoveToProjectSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    let itemIds: Set<UUID>
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Move \(itemIds.count) Items")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            Text("Select a project to move the selected items to:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            
            // Project list
            ScrollView {
                VStack(spacing: 4) {
                    // No project option
                    ProjectOptionRow(
                        icon: "tray",
                        name: "No Project",
                        isSelected: false
                    ) {
                        moveToProject(nil)
                    }
                    
                    if !appState.projects.isEmpty {
                        Divider()
                            .padding(.vertical, 8)
                        
                        ForEach(appState.projects) { project in
                            ProjectOptionRow(
                                icon: project.icon,
                                name: project.name,
                                isSelected: false
                            ) {
                                moveToProject(project.id)
                            }
                        }
                    }
                }
                .padding(4)
            }
            .frame(maxHeight: 200)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
            )
            
            // Actions
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
            }
        }
        .padding(20)
        .frame(width: 320, height: 380)
    }
    
    private func moveToProject(_ projectId: UUID?) {
        Task {
            try? await appState.moveSelectedItems(to: projectId)
            dismiss()
        }
    }
}

struct ProjectOptionRow: View {
    let icon: String
    let name: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
                
                Text(name)
                    .font(.body)
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(.green)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.5) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Item Row

struct ItemRow: View {
    let item: Item
    
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: item.icon)
                .font(.title3)
                .foregroundStyle(item.color)
                .frame(width: 28)
            
            // Name and subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.body)
                    .lineLimit(1)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Indicators
            HStack(spacing: 6) {
                if item.isFavorite {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundStyle(.yellow)
                }
                
                if item.isDangerous {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    private var subtitle: String {
        switch item.data {
        case .apiKey(let data):
            return data.service.isEmpty ? item.type.displayName : data.service
        case .database(let data):
            return data.host.isEmpty ? item.type.displayName : data.host
        case .server(let data):
            return data.hostname.isEmpty ? item.type.displayName : data.hostname
        case .ssh(let data):
            return data.host.isEmpty ? item.type.displayName : "\(data.user)@\(data.host)"
        case .command(let data):
            return data.command.truncated(to: 40)
        case .secureNote:
            return item.type.displayName
        }
    }
}

#Preview {
    ItemListView()
        .environment(AppState.shared)
        .frame(width: 300, height: 500)
}
