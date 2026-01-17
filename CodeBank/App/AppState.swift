import Foundation
import SwiftUI
import Combine

/// Global application state
@MainActor
@Observable
final class AppState {
    
    // MARK: - Singleton
    
    static let shared = AppState()
    
    // MARK: - Navigation State
    
    /// Currently selected navigation destination in sidebar
    var selectedSidebarItem: SidebarItem? = .allItems
    
    /// Currently selected project ID (when viewing a project)
    var selectedProjectId: UUID?
    
    /// Currently selected item ID (single selection for detail view)
    var selectedItemId: UUID?
    
    /// Currently selected item IDs (multi-selection)
    var selectedItemIds: Set<UUID> = []
    
    /// Whether to show move to project sheet
    var showMoveToProjectSheet: Bool = false
    
    /// Whether the item editor sheet is shown
    var isShowingItemEditor: Bool = false
    
    /// Item being edited (nil for new item)
    var editingItem: Item?
    
    /// Type of new item being created
    var newItemType: ItemType?
    
    // MARK: - Quick Search
    
    /// Whether the quick search panel is visible
    var isQuickSearchVisible: Bool = false
    
    // MARK: - UI State
    
    /// Whether to focus the search field
    var focusSearch: Bool = false
    
    /// Whether to show the password generator
    var showPasswordGenerator: Bool = false
    
    /// Whether to show delete confirmation dialog
    var showDeleteConfirmation: Bool = false
    
    /// Whether to show new project sheet
    var showNewProjectSheet: Bool = false
    
    // MARK: - Data
    
    /// All projects
    var projects: [Project] = []
    
    /// All items
    var items: [Item] = []
    
    /// All tags
    var tags: [Tag] = []
    
    // MARK: - Services
    
    let vaultService: VaultService
    let storageService: StorageService
    let searchService: SearchService
    let clipboardService: ClipboardService
    let commandService: CommandService
    let importExportService: ImportExportService
    
    // MARK: - Initialization
    
    private init() {
        self.vaultService = VaultService.shared
        self.storageService = StorageService.shared
        self.searchService = SearchService.shared
        self.clipboardService = ClipboardService.shared
        self.commandService = CommandService.shared
        self.importExportService = ImportExportService.shared
    }
    
    // MARK: - Data Loading
    
    /// Loads all data from storage
    func loadData() async {
        do {
            projects = try storageService.fetchAllProjects()
            items = try storageService.fetchAllItems()
            tags = try storageService.fetchAllTags()
        } catch {
            print("Failed to load data: \(error)")
        }
    }
    
    // MARK: - Project Operations
    
    func createProject(name: String, icon: String = "folder.fill") async throws {
        let project = Project(name: name, icon: icon)
        try storageService.createProject(project)
        await loadData()
    }
    
    func updateProject(_ project: Project) async throws {
        try storageService.updateProject(project)
        await loadData()
    }
    
    func deleteProject(_ project: Project) async throws {
        try storageService.deleteProject(id: project.id)
        if selectedProjectId == project.id {
            selectedProjectId = nil
            selectedSidebarItem = .allItems
        }
        await loadData()
    }
    
    // MARK: - Item Operations
    
    func createItem(_ item: Item) async throws {
        try storageService.createItem(item)
        await loadData()
    }
    
    func updateItem(_ item: Item) async throws {
        try storageService.updateItem(item)
        await loadData()
    }
    
    func deleteItem(_ item: Item) async throws {
        try storageService.deleteItem(id: item.id)
        if selectedItemId == item.id {
            selectedItemId = nil
        }
        await loadData()
    }
    
    func duplicateItem(_ item: Item) async throws {
        var newItem = item
        newItem.id = UUID()
        newItem.name = "\(item.name) (Copy)"
        newItem.createdAt = Date()
        newItem.updatedAt = Date()
        try storageService.createItem(newItem)
        await loadData()
        selectedItemId = newItem.id
    }
    
    func toggleFavorite(_ item: Item) async throws {
        var updatedItem = item
        updatedItem.isFavorite.toggle()
        updatedItem.updatedAt = Date()
        try storageService.updateItem(updatedItem)
        await loadData()
    }
    
    /// Delete the currently selected item with confirmation
    func deleteSelectedItem() async throws {
        guard let item = selectedItem else { return }
        try await deleteItem(item)
    }
    
    // MARK: - Bulk Operations
    
    /// Delete multiple selected items
    func deleteSelectedItems() async throws {
        for itemId in selectedItemIds {
            try storageService.deleteItem(id: itemId)
        }
        selectedItemIds.removeAll()
        selectedItemId = nil
        await loadData()
    }
    
    /// Move multiple selected items to a project
    func moveSelectedItems(to projectId: UUID?) async throws {
        for itemId in selectedItemIds {
            if var item = items.first(where: { $0.id == itemId }) {
                item.projectId = projectId
                item.updatedAt = Date()
                try storageService.updateItem(item)
            }
        }
        selectedItemIds.removeAll()
        await loadData()
    }
    
    /// Get items for the current selection
    var selectedItems: [Item] {
        items.filter { selectedItemIds.contains($0.id) }
    }
    
    /// Clear multi-selection
    func clearSelection() {
        selectedItemIds.removeAll()
    }
    
    // MARK: - Tag Operations
    
    func createTag(name: String, color: String = "blue") async throws {
        let tag = Tag(name: name, color: color)
        try storageService.createTag(tag)
        await loadData()
    }
    
    func deleteTag(_ tag: Tag) async throws {
        try storageService.deleteTag(id: tag.id)
        await loadData()
    }
    
    // MARK: - Filtered Data
    
    /// Items filtered by current sidebar selection (favorites first)
    var filteredItems: [Item] {
        let baseItems: [Item]
        switch selectedSidebarItem {
        case .allItems:
            baseItems = items
        case .project(let id):
            baseItems = items.filter { $0.projectId == id }
        case .tag(let id):
            baseItems = items.filter { $0.tagIds.contains(id) }
        case .settings, .none:
            baseItems = []
        }
        // Sort with favorites first, then by name
        return baseItems.sorted { lhs, rhs in
            if lhs.isFavorite != rhs.isFavorite {
                return lhs.isFavorite
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }
    
    /// Currently selected item
    var selectedItem: Item? {
        guard let id = selectedItemId else { return nil }
        return items.first { $0.id == id }
    }
    
    /// Currently selected project
    var selectedProject: Project? {
        guard let id = selectedProjectId else { return nil }
        return projects.first { $0.id == id }
    }
    
    // MARK: - Editor
    
    func showNewItemEditor(type: ItemType, projectId: UUID? = nil) {
        editingItem = nil
        newItemType = type
        var item = Item(name: "", type: type, projectId: projectId ?? selectedProjectId)
        if case .project(let id) = selectedSidebarItem {
            item = Item(name: "", type: type, projectId: id)
        }
        editingItem = item
        isShowingItemEditor = true
    }
    
    func showEditItemEditor(_ item: Item) {
        editingItem = item
        newItemType = item.type
        isShowingItemEditor = true
    }
    
    func closeEditor() {
        isShowingItemEditor = false
        editingItem = nil
        newItemType = nil
    }
    
    // MARK: - Quick Search
    
    func toggleQuickSearch() {
        isQuickSearchVisible.toggle()
        if !isQuickSearchVisible {
            searchService.clear()
        }
    }
    
    func showQuickSearch() {
        isQuickSearchVisible = true
    }
    
    func hideQuickSearch() {
        isQuickSearchVisible = false
        searchService.clear()
    }
    
    // MARK: - Actions
    
    func copyItemValue(_ item: Item) {
        guard let value = item.primaryValue else { return }
        
        let isSecret = item.type == .apiKey ||
                       item.type == .database ||
                       item.type == .secureNote
        
        if isSecret {
            clipboardService.copySecret(value)
        } else {
            clipboardService.copy(value)
        }
    }
    
    func executeItem(_ item: Item) async throws {
        guard item.isExecutable else { return }
        
        if item.type == .command {
            try await commandService.execute(item)
        } else if item.type == .ssh {
            try await commandService.openSSH(item)
        }
    }
    
    // MARK: - Activity Recording
    
    func recordActivity() {
        vaultService.recordActivity()
    }
}

// MARK: - Sidebar Items

enum SidebarItem: Hashable, Identifiable {
    case allItems
    case project(UUID)
    case tag(UUID)
    case settings
    
    var id: String {
        switch self {
        case .allItems: return "all"
        case .project(let id): return "project-\(id)"
        case .tag(let id): return "tag-\(id)"
        case .settings: return "settings"
        }
    }
}
