import SwiftUI
import UniformTypeIdentifiers

struct ENVImportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppState.self) private var appState
    
    @State private var parsedItems: [ENVParserService.ParsedEnvItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var selectedProjectId: UUID?
    @State private var importProgress: Double = 0
    @State private var isImporting = false
    @State private var showFileImporter = true
    
    private let parser = ENVParserService.shared
    
    /// Allowed file types for ENV import - use .item to allow any file
    /// since env files can have many naming conventions (.env, env.example, .env.local, etc.)
    private static let allowedTypes: [UTType] = [.item]
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            if isLoading {
                loadingView
            } else if let error = errorMessage {
                errorView(error)
            } else if parsedItems.isEmpty {
                emptyView
            } else {
                // Items list
                itemsList
            }
            
            Divider()
            
            // Footer
            footer
        }
        .frame(width: 600, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: Self.allowedTypes,
            allowsMultipleSelection: true
        ) { result in
            handleFileSelection(result)
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "doc.text.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                
                Text("Import ENV File")
                    .font(.headline)
                
                Spacer()
                
                Button("Select Files...") {
                    showFileImporter = true
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            
            Text("Automatically extract and create items from your .env files")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
    
    // MARK: - Items List
    
    private var itemsList: some View {
        VStack(spacing: 0) {
            // Project selector
            HStack {
                Text("Import to:")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Picker("", selection: $selectedProjectId) {
                    Text("No Project").tag(nil as UUID?)
                    ForEach(appState.projects) { project in
                        Text(project.name).tag(project.id as UUID?)
                    }
                }
                .labelsHidden()
                .frame(width: 200)
                
                Spacer()
                
                // Select all / none
                Button("Select All") {
                    selectAll()
                }
                .buttonStyle(GhostButtonStyle())
                
                Button("Select None") {
                    selectNone()
                }
                .buttonStyle(GhostButtonStyle())
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            Divider()
            
            // Items
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach($parsedItems) { $item in
                        ENVImportRow(item: $item)
                    }
                }
                .padding(.vertical, 8)
            }
            
            // Progress bar during import
            if isImporting {
                ProgressView(value: importProgress)
                    .progressViewStyle(.linear)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Parsing ENV file...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            
            Text("Error")
                .font(.headline)
            
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                errorMessage = nil
                showFileImporter = true
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.text")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            
            Text("No Items Found")
                .font(.headline)
            
            Text("Select an ENV file to import variables")
                .foregroundStyle(.secondary)
            
            Button("Select File") {
                showFileImporter = true
            }
            .buttonStyle(SecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        HStack {
            if !parsedItems.isEmpty {
                let selectedCount = parsedItems.filter(\.isSelected).count
                Text("\(selectedCount) of \(parsedItems.count) items selected")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Button("Cancel") {
                dismiss()
            }
            .buttonStyle(SecondaryButtonStyle())
            .keyboardShortcut(.escape)
            
            Button("Import") {
                importItems()
            }
            .buttonStyle(PrimaryButtonStyle())
            .keyboardShortcut(.return)
            .disabled(parsedItems.filter(\.isSelected).isEmpty || isImporting)
        }
        .padding()
    }
    
    // MARK: - Actions
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            parseFiles(urls)
        case .failure(let error):
            if (error as NSError).code != NSFileReadUnknownError {
                // User cancelled - just dismiss if no items
                if parsedItems.isEmpty {
                    dismiss()
                }
            }
        }
    }
    
    private func parseFiles(_ urls: [URL]) {
        isLoading = true
        errorMessage = nil
        
        Task {
            var allItems: [ENVParserService.ParsedEnvItem] = []
            
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else {
                    continue
                }
                
                defer { url.stopAccessingSecurityScopedResource() }
                
                do {
                    let content = try String(contentsOf: url, encoding: .utf8)
                    let items = parser.parse(content)
                    allItems.append(contentsOf: items)
                } catch {
                    await MainActor.run {
                        errorMessage = "Failed to read file: \(error.localizedDescription)"
                    }
                    return
                }
            }
            
            await MainActor.run {
                parsedItems = allItems
                isLoading = false
                
                if allItems.isEmpty {
                    errorMessage = "No valid environment variables found in the selected file(s)"
                }
            }
        }
    }
    
    private func selectAll() {
        for index in parsedItems.indices {
            parsedItems[index].isSelected = true
        }
    }
    
    private func selectNone() {
        for index in parsedItems.indices {
            parsedItems[index].isSelected = false
        }
    }
    
    private func importItems() {
        let selectedItems = parsedItems.filter(\.isSelected)
        guard !selectedItems.isEmpty else { return }
        
        isImporting = true
        importProgress = 0
        
        Task {
            let total = Double(selectedItems.count)
            var completed = 0.0
            
            for parsed in selectedItems {
                let item = parser.createItem(from: parsed, projectId: selectedProjectId)
                
                do {
                    try await appState.createItem(item)
                } catch {
                    print("Failed to save item: \(error)")
                }
                
                completed += 1
                importProgress = completed / total
            }
            
            // Show toast and dismiss
            ToastManager.shared.show("Imported \(selectedItems.count) items")
            dismiss()
        }
    }
}

// MARK: - Row View

struct ENVImportRow: View {
    @Binding var item: ENVParserService.ParsedEnvItem
    @State private var isHovered = false
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                // Checkbox
                Toggle("", isOn: $item.isSelected)
                    .toggleStyle(.checkbox)
                    .labelsHidden()
                
                // Expand/collapse button for multiple variables
                if item.variables.count > 1 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 16)
                    }
                    .buttonStyle(.plain)
                } else {
                    Spacer()
                        .frame(width: 16)
                }
                
                // Type icon
                itemTypeIcon
                    .frame(width: 28, height: 28)
                    .background(iconBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                // Content
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(item.name)
                            .font(.system(.body, weight: .medium))
                        
                        // Variable count badge
                        if item.variables.count > 1 {
                            Text("\(item.variables.count) vars")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(nsColor: .separatorColor).opacity(0.3))
                                .clipShape(Capsule())
                        }
                        
                        Spacer()
                        
                        // Type picker
                        Picker("", selection: $item.suggestedType) {
                            ForEach(ItemType.allCases, id: \.self) { type in
                                Text(type.displayName).tag(type)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 130)
                    }
                    
                    // Show variable keys preview
                    Text(variableKeysPreview)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    
                    // Show primary secret if API key type
                    if item.suggestedType == .apiKey, let secret = item.primarySecret {
                        Text(maskedValue(secret))
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.1) : Color.clear)
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
            
            // Expanded variable list
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(item.variables, id: \.key) { variable in
                        HStack {
                            Text(variable.key)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Text(maskedValue(variable.value))
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .padding(.leading, 72) // Indent to align with content
                    }
                }
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.3))
            }
        }
    }
    
    private var variableKeysPreview: String {
        let keys = item.variables.map { $0.key }
        if keys.count <= 2 {
            return keys.joined(separator: ", ")
        }
        return "\(keys[0]), \(keys[1]), +\(keys.count - 2) more"
    }
    
    private func maskedValue(_ value: String) -> String {
        if value.count > 12 {
            let prefix = String(value.prefix(4))
            let suffix = String(value.suffix(4))
            return "\(prefix)••••\(suffix)"
        } else if value.count > 4 {
            let prefix = String(value.prefix(2))
            return "\(prefix)••••••"
        }
        return String(repeating: "•", count: value.count)
    }
    
    @ViewBuilder
    private var itemTypeIcon: some View {
        switch item.suggestedType {
        case .apiKey:
            Image(systemName: "key.fill")
                .foregroundStyle(.orange)
        case .database:
            Image(systemName: "cylinder.fill")
                .foregroundStyle(.purple)
        case .server:
            Image(systemName: "server.rack")
                .foregroundStyle(.blue)
        case .ssh:
            Image(systemName: "terminal.fill")
                .foregroundStyle(.green)
        case .command:
            Image(systemName: "chevron.left.forwardslash.chevron.right")
                .foregroundStyle(.pink)
        case .secureNote:
            Image(systemName: "doc.text.fill")
                .foregroundStyle(.gray)
        }
    }
    
    private var iconBackground: Color {
        switch item.suggestedType {
        case .apiKey: return .orange.opacity(0.15)
        case .database: return .purple.opacity(0.15)
        case .server: return .blue.opacity(0.15)
        case .ssh: return .green.opacity(0.15)
        case .command: return .pink.opacity(0.15)
        case .secureNote: return Color(nsColor: .systemGray).opacity(0.15)
        }
    }
}

// MARK: - Preview

#Preview {
    ENVImportView()
        .environment(AppState.shared)
}
