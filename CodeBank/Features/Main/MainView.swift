import SwiftUI

/// Main three-column layout view
struct MainView: View {
    @Environment(AppState.self) private var appState
    @Environment(VaultService.self) private var vaultService
    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingENVImport = false
    @State private var isShowingNewProjectSheet = false
    @State private var newProjectName = ""
    @State private var newProjectIcon = "folder.fill"
    
    var body: some View {
        @Bindable var state = appState
        
        ZStack(alignment: .topTrailing) {
            // Use two-column layout when no item selected, three-column when item selected
            if appState.selectedItemId != nil {
                // Three-column layout with detail
                NavigationSplitView {
                    SidebarView()
                        .navigationSplitViewColumnWidth(min: Constants.UI.sidebarMinWidth, ideal: 220, max: Constants.UI.sidebarMaxWidth)
                } content: {
                    ItemListView()
                        .navigationSplitViewColumnWidth(min: Constants.UI.listMinWidth, ideal: 350)
                } detail: {
                    ItemDetailView()
                        .preventScreenshots() // Prevent screenshots of sensitive data
                }
                .navigationSplitViewStyle(.balanced)
                .navigationTitle("")
                .toolbar {
                    leadingToolbarContent
                }
                .sheet(isPresented: $state.isShowingItemEditor) {
                    ItemEditorView()
                }
                .sheet(isPresented: $isShowingENVImport) {
                    ENVImportView()
                }
            } else {
                // Two-column layout without detail
                NavigationSplitView {
                    SidebarView()
                        .navigationSplitViewColumnWidth(min: Constants.UI.sidebarMinWidth, ideal: 220, max: Constants.UI.sidebarMaxWidth)
                } detail: {
                    ItemListView()
                }
                .navigationSplitViewStyle(.balanced)
                .navigationTitle("")
                .toolbar {
                    leadingToolbarContent
                }
                .sheet(isPresented: $state.isShowingItemEditor) {
                    ItemEditorView()
                }
                .sheet(isPresented: $isShowingENVImport) {
                    ENVImportView()
                }
            }
            
            // New Item button positioned in the toolbar row (top-right)
            // Using negative padding to position in the toolbar area
            VStack {
                newItemButton
                Spacer()
            }
            .padding(.top, -44) // Move up into toolbar area
            .padding(.trailing, 12)
            
            // Quick Search Overlay
            if appState.isQuickSearchVisible {
                quickSearchOverlay
            }
            
            // Toast notifications
            ToastOverlay()
        }
        .onAppear {
            appState.recordActivity()
        }
        .onChange(of: appState.selectedItemId) { _, _ in
            appState.recordActivity()
        }
        .onChange(of: appState.showNewProjectSheet) { _, newValue in
            if newValue {
                isShowingNewProjectSheet = true
                appState.showNewProjectSheet = false
            }
        }
        .onChange(of: appState.focusSearch) { _, newValue in
            if newValue {
                appState.toggleQuickSearch()
                appState.focusSearch = false
            }
        }
        .sheet(isPresented: $isShowingNewProjectSheet) {
            newProjectSheet
        }
    }
    
    // MARK: - New Item Button (top-right)
    
    private var newItemButton: some View {
        Menu {
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
                isShowingENVImport = true
            } label: {
                Label("Import ENV File...", systemImage: "doc.text.fill.viewfinder")
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text("New Item")
                    .font(.system(size: 12, weight: .semibold))
            }
            // White button in dark mode, black button in light mode
            .foregroundColor(colorScheme == .dark ? .black : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(colorScheme == .dark ? Color.white : Color.black)
            )
        }
        .buttonStyle(.plain)
        .fixedSize()
    }
    
    // MARK: - Quick Search Overlay
    
    private var quickSearchOverlay: some View {
        ZStack(alignment: .top) {
            // Dimmed background
            Color.black.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture {
                    appState.hideQuickSearch()
                }
            
            // Quick Search Panel - positioned like Spotlight
            QuickSearchPanel {
                appState.hideQuickSearch()
            }
            .padding(.top, 60)
        }
        .transition(.opacity)
        .animation(.easeInOut(duration: 0.12), value: appState.isQuickSearchVisible)
    }
    
    // MARK: - Leading Toolbar (left side)
    
    @ToolbarContentBuilder
    private var leadingToolbarContent: some ToolbarContent {
        // Search button
        ToolbarItem(placement: .primaryAction) {
            Button {
                appState.toggleQuickSearch()
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .keyboardShortcut(.space, modifiers: [.command, .shift])
            .help("Quick Search (⌘⇧Space)")
        }
        
        // Lock button
        ToolbarItem(placement: .primaryAction) {
            Button {
                vaultService.lock()
            } label: {
                Image(systemName: "lock.fill")
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
            .help("Lock Vault (⌘⇧L)")
        }
    }
    
    // MARK: - New Project Sheet
    
    private var newProjectSheet: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("New Project")
                    .font(.headline)
                Spacer()
                Button {
                    isShowingNewProjectSheet = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            
            Divider()
            
            // Project name (moved to top for better UX)
            VStack(alignment: .leading, spacing: 6) {
                Text("Name")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                TextField("Project name", text: $newProjectName)
                    .textFieldStyle(.roundedBorder)
            }
            
            // Project icon picker
            VStack(alignment: .leading, spacing: 6) {
                Text("Icon")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 6), count: 8), spacing: 6) {
                        ForEach(projectIcons, id: \.self) { icon in
                            Button {
                                newProjectIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.system(size: 16))
                                    .foregroundStyle(newProjectIcon == icon ? Color.primary : Color.secondary)
                                    .frame(width: 34, height: 34)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(newProjectIcon == icon ? Color(nsColor: .controlAccentColor).opacity(0.25) : Color(nsColor: .controlBackgroundColor))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(newProjectIcon == icon ? Color(nsColor: .controlAccentColor) : Color.clear, lineWidth: 2)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(6)
                }
                .frame(height: 200)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor).opacity(0.5))
                )
            }
            
            Spacer()
            
            // Actions
            HStack {
                Button("Cancel") {
                    isShowingNewProjectSheet = false
                    newProjectName = ""
                    newProjectIcon = "folder.fill"
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Create") {
                    createProject()
                }
                .keyboardShortcut(.return)
                .disabled(newProjectName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 400, height: 420)
    }
    
    private let projectIcons = [
        // Folders & Storage
        "folder.fill", "folder.badge.gear", "folder.badge.person.crop",
        "tray.full.fill", "archivebox.fill", "shippingbox.fill",
        // Work & Business
        "briefcase.fill", "building.2.fill", "house.fill",
        "building.columns.fill", "storefront.fill", "cart.fill",
        // Tech & Devices
        "globe", "cloud.fill", "server.rack",
        "desktopcomputer", "laptopcomputer", "iphone",
        "applewatch", "gamecontroller.fill", "tv.fill",
        // Code & Development
        "terminal.fill", "chevron.left.forwardslash.chevron.right", "cpu.fill",
        "memorychip.fill", "network", "antenna.radiowaves.left.and.right",
        // General
        "sparkles", "star.fill", "heart.fill",
        "bolt.fill", "flame.fill", "leaf.fill",
        "drop.fill", "snowflake", "sun.max.fill",
        "moon.fill", "camera.fill", "photo.fill",
        "music.note", "book.fill", "bookmark.fill",
        "flag.fill", "tag.fill", "pin.fill",
        "lock.fill", "key.fill", "shield.fill"
    ]
    
    private func createProject() {
        guard !newProjectName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        Task {
            try? await appState.createProject(name: newProjectName, icon: newProjectIcon)
            isShowingNewProjectSheet = false
            newProjectName = ""
            newProjectIcon = "folder.fill"
        }
    }
}

#Preview {
    MainView()
        .environment(AppState.shared)
        .environment(VaultService.shared)
        .frame(width: 1000, height: 600)
}
