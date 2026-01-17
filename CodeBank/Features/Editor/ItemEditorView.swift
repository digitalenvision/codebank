import SwiftUI

/// Editor view for creating and editing items
struct ItemEditorView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    
    @State private var item: Item
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didLoad = false
    @State private var showSSHPassword = false
    @State private var showSSHPassphrase = false
    
    init() {
        // Initialize with default API key field - will be properly updated in task if different type
        let defaultAPIKeyData = APIKeyData(fields: [CredentialField(name: "API Key", value: "", isSecret: true)])
        _item = State(initialValue: Item(name: "", type: .apiKey, data: .apiKey(defaultAPIKeyData)))
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Basic Info Section
                Section("Basic Info") {
                    TextField("Name", text: $item.name)
                    
                    Picker("Project", selection: Binding(
                        get: { item.projectId },
                        set: { item.projectId = $0 }
                    )) {
                        Text("None").tag(nil as UUID?)
                        ForEach(appState.projects) { project in
                            Label(project.name, systemImage: project.icon)
                                .tag(project.id as UUID?)
                        }
                    }
                }
                
                // Type-specific fields
                typeSpecificFields
            }
            .formStyle(.grouped)
            .navigationTitle(isNewItem ? "New \(item.type.displayName)" : "Edit \(item.type.displayName)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNewItem ? "Create" : "Save") {
                        save()
                    }
                    .disabled(item.name.isEmpty || isSaving)
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") {
                    errorMessage = nil
                }
            } message: {
                if let error = errorMessage {
                    Text(error)
                }
            }
            .task {
                loadItemIfNeeded()
            }
        }
    }
    
    // MARK: - Load Item
    
    private func loadItemIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        
        if let editingItem = appState.editingItem {
            // Editing existing item
            item = editingItem
        } else if let itemType = appState.newItemType {
            // Creating new item with specific type and default data
            let defaultData = createDefaultData(for: itemType)
            var newItem = Item(name: "", type: itemType, data: defaultData)
            
            if case .project(let projectId) = appState.selectedSidebarItem {
                newItem.projectId = projectId
            }
            
            item = newItem
        } else {
            // Fallback: if no specific type, use API key with default field
            let defaultData = createDefaultData(for: .apiKey)
            item = Item(name: "", type: .apiKey, data: defaultData)
        }
    }
    
    /// Creates default item data with pre-populated fields based on type
    private func createDefaultData(for type: ItemType) -> ItemData {
        switch type {
        case .apiKey:
            return .apiKey(APIKeyData(
                fields: [CredentialField(name: "API Key", value: "", isSecret: true)]
            ))
        case .database:
            return .database(DatabaseData())
        case .server:
            return .server(ServerData())
        case .ssh:
            return .ssh(SSHData())
        case .command:
            return .command(CommandData())
        case .secureNote:
            return .secureNote(SecureNoteData())
        }
    }
    
    // MARK: - Type-Specific Fields
    
    @ViewBuilder
    private var typeSpecificFields: some View {
        switch item.type {
        case .apiKey:
            apiKeyFields
        case .database:
            databaseFields
        case .server:
            serverFields
        case .ssh:
            sshFields
        case .command:
            commandFields
        case .secureNote:
            secureNoteFields
        }
    }
    
    // MARK: - API Key Fields
    
    @ViewBuilder
    private var apiKeyFields: some View {
        Section {
            VStack(spacing: 12) {
                if apiKeyFieldsBinding.wrappedValue.isEmpty {
                    // Empty state
                    VStack(spacing: 12) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.tertiary)
                        
                        VStack(spacing: 4) {
                            Text("No credentials added")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundStyle(.secondary)
                            Text("Add API keys, secrets, URLs, or custom fields")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(nsColor: .windowBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(Color(nsColor: .separatorColor).opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6]))
                            )
                    )
                } else {
                    // Credential fields list
                    ForEach(apiKeyFieldsBinding.indices, id: \.self) { index in
                        CredentialFieldRow(
                            field: apiKeyFieldsBinding[index],
                            onDelete: {
                                removeCredentialField(at: index)
                            }
                        )
                    }
                }
                
                // Add field button
                Menu {
                    Section("Keys & Secrets") {
                        Button {
                            addCredentialField(name: "API Key", isSecret: true)
                        } label: {
                            Label("API Key", systemImage: "key.fill")
                        }
                        
                        Button {
                            addCredentialField(name: "Secret Key", isSecret: true)
                        } label: {
                            Label("Secret Key", systemImage: "key.fill")
                        }
                        
                        Button {
                            addCredentialField(name: "Publishable Key", isSecret: false)
                        } label: {
                            Label("Publishable Key", systemImage: "key")
                        }
                        
                        Button {
                            addCredentialField(name: "Access Token", isSecret: true)
                        } label: {
                            Label("Access Token", systemImage: "person.badge.key.fill")
                        }
                    }
                    
                    Section("URLs") {
                        Button {
                            addCredentialField(name: "Base URL", isSecret: false)
                        } label: {
                            Label("Base URL", systemImage: "link")
                        }
                        
                        Button {
                            addCredentialField(name: "Webhook URL", isSecret: false)
                        } label: {
                            Label("Webhook URL", systemImage: "arrow.turn.down.right")
                        }
                        
                        Button {
                            addCredentialField(name: "Callback URL", isSecret: false)
                        } label: {
                            Label("Callback URL", systemImage: "arrow.uturn.backward")
                        }
                    }
                    
                    Section {
                        Button {
                            addCredentialField(name: "", isSecret: true)
                        } label: {
                            Label("Custom Field", systemImage: "plus")
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                        Text("Add Field")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.accentColor)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.1))
                    )
                }
                .menuStyle(.borderlessButton)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } header: {
            Text("Credentials")
        }
        
        Section("Notes") {
            TextEditor(text: apiKeyNotesBinding)
                .frame(minHeight: 60)
                .font(.body)
        }
    }
    
    private var apiKeyNotesBinding: Binding<String> {
        Binding(
            get: { item.apiKeyData?.notes ?? "" },
            set: { newValue in
                if var data = item.apiKeyData {
                    data.notes = newValue.isEmpty ? nil : newValue
                    item.data = .apiKey(data)
                }
            }
        )
    }
    
    private var apiKeyFieldsBinding: Binding<[CredentialField]> {
        Binding(
            get: { item.apiKeyData?.fields ?? [] },
            set: { newValue in
                if var data = item.apiKeyData {
                    data.fields = newValue
                    item.data = .apiKey(data)
                }
            }
        )
    }
    
    private func addCredentialField(name: String = "", isSecret: Bool = true) {
        if var data = item.apiKeyData {
            data.fields.append(CredentialField(name: name, value: "", isSecret: isSecret))
            item.data = .apiKey(data)
        }
    }
    
    private func removeCredentialField(at index: Int) {
        if var data = item.apiKeyData {
            data.fields.remove(at: index)
            item.data = .apiKey(data)
        }
    }
    
    // MARK: - Database Fields
    
    @ViewBuilder
    private var databaseFields: some View {
        Section("Connection") {
            HStack {
                TextField("Host", text: databaseBinding.host)
                TextField("Port", value: databaseBinding.port, format: .number)
                    .frame(width: 80)
            }
            TextField("Database Name", text: databaseBinding.databaseName)
            
            Picker("Database Type", selection: databaseBinding.databaseType) {
                Text("PostgreSQL").tag("postgresql")
                Text("MySQL").tag("mysql")
                Text("MongoDB").tag("mongodb")
                Text("Redis").tag("redis")
                Text("SQLite").tag("sqlite")
                Text("SQL Server").tag("sqlserver")
                Text("Oracle").tag("oracle")
                Text("Other").tag("other")
            }
        }
        
        Section("Credentials") {
            TextField("Username", text: databaseBinding.username)
            SecureField("Password", text: databaseBinding.password)
        }
        
        Section("Connection String (optional)") {
            SecureField("Connection String", text: databaseBinding.connectionString)
        }
        
        // Custom fields section
        Section {
            VStack(spacing: 12) {
                ForEach(databaseCustomFieldsBinding.indices, id: \.self) { index in
                    CredentialFieldRow(
                        field: databaseCustomFieldsBinding[index],
                        onDelete: { removeDatabaseCustomField(at: index) }
                    )
                }
                
                Button {
                    addDatabaseCustomField()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                        Text("Add Field")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.accentColor)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } header: {
            Text("Additional Fields")
        }
        
        Section("Notes") {
            TextEditor(text: databaseBinding.notes)
                .frame(minHeight: 60)
        }
    }
    
    private var databaseCustomFieldsBinding: Binding<[CredentialField]> {
        Binding(
            get: { item.databaseData?.customFields ?? [] },
            set: { newValue in
                if var data = item.databaseData {
                    data.customFields = newValue
                    item.data = .database(data)
                }
            }
        )
    }
    
    private func addDatabaseCustomField() {
        if var data = item.databaseData {
            data.customFields.append(CredentialField(name: "", value: "", isSecret: true))
            item.data = .database(data)
        }
    }
    
    private func removeDatabaseCustomField(at index: Int) {
        if var data = item.databaseData {
            data.customFields.remove(at: index)
            item.data = .database(data)
        }
    }
    
    private var databaseBinding: (host: Binding<String>, port: Binding<Int>, databaseName: Binding<String>, username: Binding<String>, password: Binding<String>, connectionString: Binding<String>, databaseType: Binding<String>, notes: Binding<String>) {
        (
            host: Binding(
                get: { item.databaseData?.host ?? "" },
                set: { newValue in
                    if var data = item.databaseData {
                        data.host = newValue
                        item.data = .database(data)
                    }
                }
            ),
            port: Binding(
                get: { item.databaseData?.port ?? 5432 },
                set: { newValue in
                    if var data = item.databaseData {
                        data.port = newValue
                        item.data = .database(data)
                    }
                }
            ),
            databaseName: Binding(
                get: { item.databaseData?.databaseName ?? "" },
                set: { newValue in
                    if var data = item.databaseData {
                        data.databaseName = newValue
                        item.data = .database(data)
                    }
                }
            ),
            username: Binding(
                get: { item.databaseData?.username ?? "" },
                set: { newValue in
                    if var data = item.databaseData {
                        data.username = newValue
                        item.data = .database(data)
                    }
                }
            ),
            password: Binding(
                get: { item.databaseData?.password ?? "" },
                set: { newValue in
                    if var data = item.databaseData {
                        data.password = newValue
                        item.data = .database(data)
                    }
                }
            ),
            connectionString: Binding(
                get: { item.databaseData?.connectionString ?? "" },
                set: { newValue in
                    if var data = item.databaseData {
                        data.connectionString = newValue.isEmpty ? nil : newValue
                        item.data = .database(data)
                    }
                }
            ),
            databaseType: Binding(
                get: { item.databaseData?.databaseType ?? "postgresql" },
                set: { newValue in
                    if var data = item.databaseData {
                        data.databaseType = newValue
                        item.data = .database(data)
                    }
                }
            ),
            notes: Binding(
                get: { item.databaseData?.notes ?? "" },
                set: { newValue in
                    if var data = item.databaseData {
                        data.notes = newValue.isEmpty ? nil : newValue
                        item.data = .database(data)
                    }
                }
            )
        )
    }
    
    // MARK: - Server Fields
    
    @ViewBuilder
    private var serverFields: some View {
        Section("Server") {
            TextField("Hostname", text: serverBinding.hostname)
            TextField("IP Address (optional)", text: serverBinding.ipAddress)
            
            HStack {
                Text("SSH Port")
                Spacer()
                TextField("22", value: serverBinding.port, format: .number)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
            }
            
            HStack {
                Text("HTTP Port")
                Spacer()
                TextField("80", value: serverBinding.httpPort, format: .number)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
            }
            
            HStack {
                Text("HTTPS Port")
                Spacer()
                TextField("443", value: serverBinding.httpsPort, format: .number)
                    .frame(width: 80)
                    .multilineTextAlignment(.trailing)
            }
        }
        
        Section("Credentials") {
            TextField("Username", text: serverBinding.username)
            SecureField("Password", text: serverBinding.password)
            SecureField("Root Password (optional)", text: serverBinding.rootPassword)
        }
        
        Section("Admin") {
            TextField("Admin URL (optional)", text: serverBinding.adminUrl)
        }
        
        // Custom fields section
        Section {
            VStack(spacing: 12) {
                ForEach(serverCustomFieldsBinding.indices, id: \.self) { index in
                    CredentialFieldRow(
                        field: serverCustomFieldsBinding[index],
                        onDelete: { removeServerCustomField(at: index) }
                    )
                }
                
                Button {
                    addServerCustomField()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                        Text("Add Field")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.accentColor)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } header: {
            Text("Additional Fields")
        } footer: {
            Text("Add API keys, certificates, monitoring URLs, etc.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        
        Section("Notes") {
            TextEditor(text: serverBinding.notes)
                .frame(minHeight: 60)
        }
    }
    
    private var serverCustomFieldsBinding: Binding<[CredentialField]> {
        Binding(
            get: { item.serverData?.customFields ?? [] },
            set: { newValue in
                if var data = item.serverData {
                    data.customFields = newValue
                    item.data = .server(data)
                }
            }
        )
    }
    
    private func addServerCustomField() {
        if var data = item.serverData {
            data.customFields.append(CredentialField(name: "", value: "", isSecret: false))
            item.data = .server(data)
        }
    }
    
    private func removeServerCustomField(at index: Int) {
        if var data = item.serverData {
            data.customFields.remove(at: index)
            item.data = .server(data)
        }
    }
    
    private var serverBinding: (hostname: Binding<String>, ipAddress: Binding<String>, port: Binding<Int>, httpPort: Binding<Int?>, httpsPort: Binding<Int?>, username: Binding<String>, password: Binding<String>, rootPassword: Binding<String>, adminUrl: Binding<String>, notes: Binding<String>) {
        (
            hostname: Binding(
                get: { item.serverData?.hostname ?? "" },
                set: { newValue in
                    if var data = item.serverData {
                        data.hostname = newValue
                        item.data = .server(data)
                    }
                }
            ),
            ipAddress: Binding(
                get: { item.serverData?.ipAddress ?? "" },
                set: { newValue in
                    if var data = item.serverData {
                        data.ipAddress = newValue.isEmpty ? nil : newValue
                        item.data = .server(data)
                    }
                }
            ),
            port: Binding(
                get: { item.serverData?.port ?? 22 },
                set: { newValue in
                    if var data = item.serverData {
                        data.port = newValue
                        item.data = .server(data)
                    }
                }
            ),
            httpPort: Binding(
                get: { item.serverData?.httpPort },
                set: { newValue in
                    if var data = item.serverData {
                        data.httpPort = newValue
                        item.data = .server(data)
                    }
                }
            ),
            httpsPort: Binding(
                get: { item.serverData?.httpsPort },
                set: { newValue in
                    if var data = item.serverData {
                        data.httpsPort = newValue
                        item.data = .server(data)
                    }
                }
            ),
            username: Binding(
                get: { item.serverData?.username ?? "" },
                set: { newValue in
                    if var data = item.serverData {
                        data.username = newValue
                        item.data = .server(data)
                    }
                }
            ),
            password: Binding(
                get: { item.serverData?.password ?? "" },
                set: { newValue in
                    if var data = item.serverData {
                        data.password = newValue.isEmpty ? nil : newValue
                        item.data = .server(data)
                    }
                }
            ),
            rootPassword: Binding(
                get: { item.serverData?.rootPassword ?? "" },
                set: { newValue in
                    if var data = item.serverData {
                        data.rootPassword = newValue.isEmpty ? nil : newValue
                        item.data = .server(data)
                    }
                }
            ),
            adminUrl: Binding(
                get: { item.serverData?.adminUrl ?? "" },
                set: { newValue in
                    if var data = item.serverData {
                        data.adminUrl = newValue.isEmpty ? nil : newValue
                        item.data = .server(data)
                    }
                }
            ),
            notes: Binding(
                get: { item.serverData?.notes ?? "" },
                set: { newValue in
                    if var data = item.serverData {
                        data.notes = newValue.isEmpty ? nil : newValue
                        item.data = .server(data)
                    }
                }
            )
        )
    }
    
    // MARK: - SSH Fields
    
    @ViewBuilder
    private var sshFields: some View {
        Section("SSH Connection") {
            HStack {
                TextField("Host", text: sshBinding.host)
                TextField("Port", value: sshBinding.port, format: .number)
                    .frame(width: 80)
            }
            TextField("Username", text: sshBinding.user)
        }
        
        Section("Authentication") {
            HStack {
                if showSSHPassword {
                    TextField("Password (optional)", text: sshBinding.password)
                } else {
                    SecureField("Password (optional)", text: sshBinding.password)
                }
                Button {
                    showSSHPassword.toggle()
                } label: {
                    Image(systemName: showSSHPassword ? "eye.fill" : "eye.slash.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            TextField("Identity Key Path", text: sshBinding.identityKeyPath)
            
            HStack {
                if showSSHPassphrase {
                    TextField("Key Passphrase (optional)", text: sshBinding.passphrase)
                } else {
                    SecureField("Key Passphrase (optional)", text: sshBinding.passphrase)
                }
                Button {
                    showSSHPassphrase.toggle()
                } label: {
                    Image(systemName: showSSHPassphrase ? "eye.fill" : "eye.slash.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        
        Section("Jump Host / Bastion (optional)") {
            HStack {
                TextField("Jump Host", text: sshBinding.jumpHost)
                TextField("Jump User", text: sshBinding.jumpUser)
            }
        }
        
        Section("Port Forwarding (optional)") {
            TextField("Local Forward (e.g., 8080:localhost:80)", text: sshBinding.localPortForward)
            TextField("Remote Forward", text: sshBinding.remotePortForward)
        }
        
        // Custom fields section
        Section {
            VStack(spacing: 12) {
                ForEach(sshCustomFieldsBinding.indices, id: \.self) { index in
                    CredentialFieldRow(
                        field: sshCustomFieldsBinding[index],
                        onDelete: { removeSSHCustomField(at: index) }
                    )
                }
                
                Button {
                    addSSHCustomField()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                        Text("Add Field")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.accentColor)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } header: {
            Text("Additional Fields")
        }
        
        Section("Notes") {
            TextEditor(text: sshBinding.notes)
                .frame(minHeight: 60)
        }
    }
    
    private var sshCustomFieldsBinding: Binding<[CredentialField]> {
        Binding(
            get: { item.sshData?.customFields ?? [] },
            set: { newValue in
                if var data = item.sshData {
                    data.customFields = newValue
                    item.data = .ssh(data)
                }
            }
        )
    }
    
    private func addSSHCustomField() {
        if var data = item.sshData {
            data.customFields.append(CredentialField(name: "", value: "", isSecret: false))
            item.data = .ssh(data)
        }
    }
    
    private func removeSSHCustomField(at index: Int) {
        if var data = item.sshData {
            data.customFields.remove(at: index)
            item.data = .ssh(data)
        }
    }
    
    private var sshBinding: (host: Binding<String>, port: Binding<Int>, user: Binding<String>, password: Binding<String>, identityKeyPath: Binding<String>, passphrase: Binding<String>, jumpHost: Binding<String>, jumpUser: Binding<String>, localPortForward: Binding<String>, remotePortForward: Binding<String>, notes: Binding<String>) {
        (
            host: Binding(
                get: { item.sshData?.host ?? "" },
                set: { newValue in
                    if var data = item.sshData {
                        data.host = newValue
                        item.data = .ssh(data)
                    }
                }
            ),
            port: Binding(
                get: { item.sshData?.port ?? 22 },
                set: { newValue in
                    if var data = item.sshData {
                        data.port = newValue
                        item.data = .ssh(data)
                    }
                }
            ),
            user: Binding(
                get: { item.sshData?.user ?? "" },
                set: { newValue in
                    if var data = item.sshData {
                        data.user = newValue
                        item.data = .ssh(data)
                    }
                }
            ),
            password: Binding(
                get: { item.sshData?.password ?? "" },
                set: { newValue in
                    if var data = item.sshData {
                        data.password = newValue.isEmpty ? nil : newValue
                        item.data = .ssh(data)
                    }
                }
            ),
            identityKeyPath: Binding(
                get: { item.sshData?.identityKeyPath ?? "" },
                set: { newValue in
                    if var data = item.sshData {
                        data.identityKeyPath = newValue.isEmpty ? nil : newValue
                        item.data = .ssh(data)
                    }
                }
            ),
            passphrase: Binding(
                get: { item.sshData?.passphrase ?? "" },
                set: { newValue in
                    if var data = item.sshData {
                        data.passphrase = newValue.isEmpty ? nil : newValue
                        item.data = .ssh(data)
                    }
                }
            ),
            jumpHost: Binding(
                get: { item.sshData?.jumpHost ?? "" },
                set: { newValue in
                    if var data = item.sshData {
                        data.jumpHost = newValue.isEmpty ? nil : newValue
                        item.data = .ssh(data)
                    }
                }
            ),
            jumpUser: Binding(
                get: { item.sshData?.jumpUser ?? "" },
                set: { newValue in
                    if var data = item.sshData {
                        data.jumpUser = newValue.isEmpty ? nil : newValue
                        item.data = .ssh(data)
                    }
                }
            ),
            localPortForward: Binding(
                get: { item.sshData?.localPortForward ?? "" },
                set: { newValue in
                    if var data = item.sshData {
                        data.localPortForward = newValue.isEmpty ? nil : newValue
                        item.data = .ssh(data)
                    }
                }
            ),
            remotePortForward: Binding(
                get: { item.sshData?.remotePortForward ?? "" },
                set: { newValue in
                    if var data = item.sshData {
                        data.remotePortForward = newValue.isEmpty ? nil : newValue
                        item.data = .ssh(data)
                    }
                }
            ),
            notes: Binding(
                get: { item.sshData?.notes ?? "" },
                set: { newValue in
                    if var data = item.sshData {
                        data.notes = newValue.isEmpty ? nil : newValue
                        item.data = .ssh(data)
                    }
                }
            )
        )
    }
    
    // MARK: - Command Fields
    
    @ViewBuilder
    private var commandFields: some View {
        Section("Command") {
            TextEditor(text: commandBinding.command)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 100)
        }
        
        Section("Options") {
            Picker("Shell", selection: commandBinding.shell) {
                ForEach(ShellType.allCases, id: \.self) { shell in
                    Text(shell.displayName).tag(shell.rawValue)
                }
            }
            
            TextField("Working Directory (optional)", text: commandBinding.workingDirectory)
        }
        
        // Environment variables
        Section {
            VStack(spacing: 12) {
                ForEach(commandEnvVarsBinding.indices, id: \.self) { index in
                    CredentialFieldRow(
                        field: commandEnvVarsBinding[index],
                        onDelete: { removeCommandEnvVar(at: index) }
                    )
                }
                
                Button {
                    addCommandEnvVar()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                        Text("Add Variable")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.accentColor)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } header: {
            Text("Environment Variables")
        }
        
        // Custom fields (related commands, scripts)
        Section {
            VStack(spacing: 12) {
                ForEach(commandCustomFieldsBinding.indices, id: \.self) { index in
                    CredentialFieldRow(
                        field: commandCustomFieldsBinding[index],
                        onDelete: { removeCommandCustomField(at: index) }
                    )
                }
                
                Button {
                    addCommandCustomField()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 14))
                        Text("Add Field")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    .foregroundColor(.accentColor)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.accentColor.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } header: {
            Text("Related Commands / Scripts")
        }
        
        Section("Safety") {
            Toggle("Requires Confirmation", isOn: commandBinding.requiresConfirmation)
            Toggle("Dangerous Command", isOn: commandBinding.isDangerous)
        }
        
        Section("Notes") {
            TextEditor(text: commandBinding.notes)
                .frame(minHeight: 60)
        }
    }
    
    private var commandEnvVarsBinding: Binding<[CredentialField]> {
        Binding(
            get: { item.commandData?.environmentVariables ?? [] },
            set: { newValue in
                if var data = item.commandData {
                    data.environmentVariables = newValue
                    item.data = .command(data)
                }
            }
        )
    }
    
    private var commandCustomFieldsBinding: Binding<[CredentialField]> {
        Binding(
            get: { item.commandData?.customFields ?? [] },
            set: { newValue in
                if var data = item.commandData {
                    data.customFields = newValue
                    item.data = .command(data)
                }
            }
        )
    }
    
    private func addCommandEnvVar() {
        if var data = item.commandData {
            data.environmentVariables.append(CredentialField(name: "", value: "", isSecret: true))
            item.data = .command(data)
        }
    }
    
    private func removeCommandEnvVar(at index: Int) {
        if var data = item.commandData {
            data.environmentVariables.remove(at: index)
            item.data = .command(data)
        }
    }
    
    private func addCommandCustomField() {
        if var data = item.commandData {
            data.customFields.append(CredentialField(name: "", value: "", isSecret: false))
            item.data = .command(data)
        }
    }
    
    private func removeCommandCustomField(at index: Int) {
        if var data = item.commandData {
            data.customFields.remove(at: index)
            item.data = .command(data)
        }
    }
    
    private var commandBinding: (command: Binding<String>, shell: Binding<String>, workingDirectory: Binding<String>, requiresConfirmation: Binding<Bool>, isDangerous: Binding<Bool>, notes: Binding<String>) {
        (
            command: Binding(
                get: { item.commandData?.command ?? "" },
                set: { newValue in
                    if var data = item.commandData {
                        data.command = newValue
                        item.data = .command(data)
                    }
                }
            ),
            shell: Binding(
                get: { item.commandData?.shell ?? ShellType.zsh.rawValue },
                set: { newValue in
                    if var data = item.commandData {
                        data.shell = newValue
                        item.data = .command(data)
                    }
                }
            ),
            workingDirectory: Binding(
                get: { item.commandData?.workingDirectory ?? "" },
                set: { newValue in
                    if var data = item.commandData {
                        data.workingDirectory = newValue.isEmpty ? nil : newValue
                        item.data = .command(data)
                    }
                }
            ),
            requiresConfirmation: Binding(
                get: { item.commandData?.requiresConfirmation ?? false },
                set: { newValue in
                    if var data = item.commandData {
                        data.requiresConfirmation = newValue
                        item.data = .command(data)
                    }
                }
            ),
            isDangerous: Binding(
                get: { item.commandData?.isDangerous ?? false },
                set: { newValue in
                    if var data = item.commandData {
                        data.isDangerous = newValue
                        item.data = .command(data)
                    }
                }
            ),
            notes: Binding(
                get: { item.commandData?.notes ?? "" },
                set: { newValue in
                    if var data = item.commandData {
                        data.notes = newValue.isEmpty ? nil : newValue
                        item.data = .command(data)
                    }
                }
            )
        )
    }
    
    // MARK: - Secure Note Fields
    
    @ViewBuilder
    private var secureNoteFields: some View {
        Section("Secure Content") {
            TextEditor(text: secureNoteBinding.content)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 150)
        }
        
        Section("Notes") {
            TextEditor(text: secureNoteBinding.notes)
                .frame(minHeight: 60)
        }
    }
    
    private var secureNoteBinding: (content: Binding<String>, notes: Binding<String>) {
        (
            content: Binding(
                get: { item.secureNoteData?.content ?? "" },
                set: { newValue in
                    if var data = item.secureNoteData {
                        data.content = newValue
                        item.data = .secureNote(data)
                    }
                }
            ),
            notes: Binding(
                get: { item.secureNoteData?.notes ?? "" },
                set: { newValue in
                    if var data = item.secureNoteData {
                        data.notes = newValue.isEmpty ? nil : newValue
                        item.data = .secureNote(data)
                    }
                }
            )
        )
    }
    
    // MARK: - Save
    
    private var isNewItem: Bool {
        appState.editingItem == nil || appState.editingItem?.name.isEmpty == true
    }
    
    private func save() {
        isSaving = true
        
        Task {
            do {
                if isNewItem {
                    try await appState.createItem(item)
                } else {
                    try await appState.updateItem(item)
                }
                appState.closeEditor()
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }
}

// MARK: - Credential Field Row

/// A row for editing a single credential field
struct CredentialFieldRow: View {
    @Binding var field: CredentialField
    let onDelete: () -> Void
    
    @State private var showValue = false
    @FocusState private var isNameFocused: Bool
    @FocusState private var isValueFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header row with field name and controls
            HStack(spacing: 8) {
                // Field type icon
                Image(systemName: field.isSecret ? "key.fill" : "text.alignleft")
                    .font(.system(size: 14))
                    .foregroundStyle(field.isSecret ? .orange : .secondary)
                    .frame(width: 20)
                
                // Field name input
                TextField("Field Name", text: $field.name)
                    .font(.system(.subheadline, weight: .medium))
                    .textFieldStyle(.plain)
                    .focused($isNameFocused)
                
                Spacer()
                
                // Field type toggle
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        field.isSecret.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: field.isSecret ? "lock.fill" : "lock.open")
                            .font(.system(size: 11))
                        Text(field.isSecret ? "Secret" : "Visible")
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(field.isSecret ? .orange : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(field.isSecret ? Color.orange.opacity(0.15) : Color.secondary.opacity(0.1))
                    )
                }
                .buttonStyle(.plain)
                .help(field.isSecret ? "Click to make visible" : "Click to make secret")
                
                // Delete button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        onDelete()
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary.opacity(0.6))
                }
                .buttonStyle(.plain)
                .help("Remove field")
            }
            
            // Value input field - entire row is clickable
            HStack(spacing: 8) {
                if field.isSecret && !showValue {
                    SecureField("Value", text: $field.value)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .focused($isValueFocused)
                } else {
                    TextField("Value", text: $field.value)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .focused($isValueFocused)
                }
                
                Spacer(minLength: 0)
                
                // Show/hide toggle for secrets
                if field.isSecret {
                    Button {
                        showValue.toggle()
                    } label: {
                        Image(systemName: showValue ? "eye.fill" : "eye.slash.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help(showValue ? "Hide value" : "Show value")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .textBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isValueFocused ? Color.accentColor : Color(nsColor: .separatorColor), lineWidth: isValueFocused ? 2 : 1)
            )
            .contentShape(Rectangle())
            .onTapGesture {
                isValueFocused = true
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 1)
        )
    }
}

#Preview {
    ItemEditorView()
        .environment(AppState.shared)
}
