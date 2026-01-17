import SwiftUI

/// Detail view that shows the appropriate detail for the selected item type
struct ItemDetailView: View {
    @Environment(AppState.self) private var appState
    
    var body: some View {
        if let item = appState.selectedItem {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header
                    itemHeader(item)
                    
                    Divider()
                        .padding(.vertical, 16)
                    
                    // Type-specific content
                    itemContent(item)
                    
                    Spacer()
                }
                .padding(24)
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    if item.isExecutable {
                        Button {
                            executeItem(item)
                        } label: {
                            Label(item.type == .ssh ? "Connect" : "Run", systemImage: item.type == .ssh ? "terminal" : "play.fill")
                        }
                        .help(item.type == .ssh ? "Open SSH Connection" : "Run Command")
                    }
                }
            }
        } else {
            emptyDetailView
        }
    }
    
    // MARK: - Empty State
    
    private var emptyDetailView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sidebar.right")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            Text("Select an Item")
                .font(.title2)
                .foregroundStyle(.secondary)
            
            Text("Choose an item from the list to view its details")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Item Header
    
    private func itemHeader(_ item: Item) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(item.color.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: item.icon)
                    .font(.title)
                    .foregroundStyle(item.color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                HStack(spacing: 8) {
                    Text(item.type.displayName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background {
                            Capsule()
                                .fill(item.color.opacity(0.15))
                        }
                    
                    if item.isDangerous {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text("Dangerous")
                        }
                        .font(.caption)
                        .foregroundStyle(.orange)
                    }
                }
            }
            
            Spacer()
            
            // Edit button
            Button {
                appState.showEditItemEditor(item)
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Item Content
    
    @ViewBuilder
    private func itemContent(_ item: Item) -> some View {
        switch item.data {
        case .apiKey(let data):
            APIKeyDetailContent(data: data)
        case .database(let data):
            DatabaseDetailContent(data: data)
        case .server(let data):
            ServerDetailContent(data: data)
        case .ssh(let data):
            SSHDetailContent(data: data)
        case .command(let data):
            CommandDetailContent(data: data, item: item)
        case .secureNote(let data):
            SecureNoteDetailContent(data: data)
        }
        
        // Metadata
        VStack(alignment: .leading, spacing: 8) {
            Divider()
                .padding(.vertical, 16)
            
            HStack {
                Text("Created")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(item.createdAt, format: .dateTime.day().month().year())
            }
            .font(.caption)
            
            HStack {
                Text("Modified")
                    .foregroundStyle(.secondary)
                Spacer()
                Text(item.updatedAt, format: .dateTime.day().month().year().hour().minute())
            }
            .font(.caption)
        }
    }
    
    // MARK: - Helpers
    
    private func executeItem(_ item: Item) {
        if item.requiresConfirmation {
            // Show confirmation dialog
            // For now, just execute
        }
        
        Task {
            try? await appState.executeItem(item)
        }
    }
}

#Preview {
    ItemDetailView()
        .environment(AppState.shared)
        .frame(width: 400, height: 600)
}
