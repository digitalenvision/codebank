import SwiftUI

/// Sidebar showing projects and navigation
struct SidebarView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.openSettings) private var openSettings
    
    @State private var isShowingNewProjectSheet = false
    @State private var newProjectName = ""
    @State private var newProjectIcon = "folder.fill"
    @State private var editingProject: Project?
    @State private var settingsHovered = false
    
    var body: some View {
        @Bindable var state = appState
        
        VStack(spacing: 0) {
            List(selection: $state.selectedSidebarItem) {
                // All Items
                SidebarRow(
                    label: "All Items",
                    icon: "tray.fill",
                    badge: appState.items.count,
                    isSelected: appState.selectedSidebarItem == .allItems
                )
                .tag(SidebarItem.allItems)
                
                // Projects Section
                Section("Projects") {
                    ForEach(appState.projects) { project in
                        SidebarRow(
                            label: project.name,
                            icon: project.icon,
                            badge: itemCount(for: project),
                            isSelected: appState.selectedSidebarItem == .project(project.id)
                        )
                        .tag(SidebarItem.project(project.id))
                        .contextMenu {
                            Button("Edit") {
                                editingProject = project
                            }
                            Button("Delete", role: .destructive) {
                                deleteProject(project)
                            }
                        }
                    }
                    
                    // New Project button - subtle styling
                    Button {
                        isShowingNewProjectSheet = true
                    } label: {
                        Label("New Project", systemImage: "plus")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                
            }
            .listStyle(.sidebar)
            
            Divider()
            
            // Settings button - OUTSIDE the List so it's always clickable
            Button {
                openSettings()
            } label: {
                HStack {
                    Label("Settings", systemImage: "gearshape")
                    Spacer()
                    Text("⌘,")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(settingsHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.5) : Color.clear)
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .onHover { hovering in
                settingsHovered = hovering
            }
        }
        .navigationTitle("CodeBank")
        .sheet(isPresented: $isShowingNewProjectSheet) {
            newProjectSheet
        }
        .sheet(item: $editingProject) { project in
            editProjectSheet(project)
        }
    }
    
    // MARK: - Item Count Helpers
    
    private func itemCount(for project: Project) -> Int {
        appState.items.filter { $0.projectId == project.id }.count
    }
    
    
    // MARK: - New Project Sheet
    
    private var newProjectSheet: some View {
        VStack(spacing: 20) {
            Text("New Project")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("Project name", text: $newProjectName)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Icon")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                iconPicker
            }
            
            HStack {
                Button("Cancel") {
                    resetNewProjectForm()
                    isShowingNewProjectSheet = false
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Create") {
                    createProject()
                }
                .keyboardShortcut(.return)
                .disabled(newProjectName.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
    
    // MARK: - Edit Project Sheet
    
    private func editProjectSheet(_ project: Project) -> some View {
        @State var name = project.name
        @State var icon = project.icon
        
        return VStack(spacing: 20) {
            Text("Edit Project")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Name")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                TextField("Project name", text: $name)
                    .textFieldStyle(.roundedBorder)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Icon")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                iconPickerFor(selection: $icon)
            }
            
            HStack {
                Button("Cancel") {
                    editingProject = nil
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Save") {
                    var updated = project
                    updated.name = name
                    updated.icon = icon
                    Task {
                        try? await appState.updateProject(updated)
                    }
                    editingProject = nil
                }
                .keyboardShortcut(.return)
                .disabled(name.isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
    }
    
    // MARK: - Icon Picker
    
    private var iconPicker: some View {
        iconPickerFor(selection: $newProjectIcon)
    }
    
    private func iconPickerFor(selection: Binding<String>) -> some View {
        let icons = [
            "folder.fill", "server.rack", "macwindow", "iphone",
            "globe", "cloud.fill", "externaldrive.fill", "cylinder.fill",
            "cpu.fill", "memorychip.fill", "network", "wifi",
            "key.fill", "lock.fill", "shield.fill", "person.fill"
        ]
        
        return LazyVGrid(columns: Array(repeating: GridItem(.fixed(36)), count: 8), spacing: 8) {
            ForEach(icons, id: \.self) { icon in
                Button {
                    selection.wrappedValue = icon
                } label: {
                    Image(systemName: icon)
                        .font(.title3)
                        .frame(width: 32, height: 32)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(selection.wrappedValue == icon ? Color(nsColor: .separatorColor) : Color.clear)
                        }
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    // MARK: - Actions
    
    private func createProject() {
        Task {
            try? await appState.createProject(name: newProjectName, icon: newProjectIcon)
            resetNewProjectForm()
            isShowingNewProjectSheet = false
        }
    }
    
    private func resetNewProjectForm() {
        newProjectName = ""
        newProjectIcon = "folder.fill"
    }
    
    private func deleteProject(_ project: Project) {
        Task {
            try? await appState.deleteProject(project)
        }
    }
    
}

// MARK: - Sidebar Row

/// Custom sidebar row with visible selection state
struct SidebarRow: View {
    let label: String
    let icon: String
    var badge: Int = 0
    var isSelected: Bool = false
    
    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .fontWeight(isSelected ? .semibold : .regular)
            
            Spacer()
            
            if badge > 0 {
                Text("\(badge)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color(nsColor: .controlAccentColor).opacity(0.2) : Color(nsColor: .separatorColor).opacity(0.5))
                    )
            }
        }
        .foregroundStyle(isSelected ? .primary : .secondary)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color(nsColor: .selectedContentBackgroundColor) : Color.clear)
                .padding(.horizontal, 4)
        )
    }
}

#Preview {
    SidebarView()
        .environment(AppState.shared)
        .frame(width: 250, height: 500)
}
