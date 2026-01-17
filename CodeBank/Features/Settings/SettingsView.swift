import SwiftUI

/// Main settings view
struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(VaultService.self) private var vaultService
    
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
            
            SecuritySettingsView()
                .tabItem {
                    Label("Security", systemImage: "lock.shield")
                }
            
            PrivacySettingsView()
                .tabItem {
                    Label("Privacy", systemImage: "hand.raised.fill")
                }
            
            DataSettingsView()
                .tabItem {
                    Label("Data", systemImage: "externaldrive")
                }
            
            SupportSettingsView()
                .tabItem {
                    Label("Support", systemImage: "questionmark.circle")
                }
        }
        .frame(width: 500, height: 480)
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @AppStorage(Constants.UserDefaults.preferredTerminal) private var preferredTerminal = TerminalApp.terminal.rawValue
    @AppStorage(Constants.UserDefaults.showMenuBarIcon) private var showMenuBarIcon = true
    @State private var shortcutManager = KeyboardShortcutManager.shared
    
    var body: some View {
        Form {
            Section("Menu Bar") {
                Toggle("Show Menu Bar Icon", isOn: $showMenuBarIcon)
                
                Text("When enabled, a shield icon appears in the menu bar for quick access to CodeBank.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Terminal") {
                Picker("Preferred Terminal", selection: $preferredTerminal) {
                    ForEach(TerminalApp.allCases, id: \.self) { terminal in
                        Text(terminal.rawValue).tag(terminal.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                
                Text("Commands and SSH connections will open in the selected terminal application.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section {
                ShortcutRecorderView(action: .quickSearch)
                ShortcutRecorderView(action: .searchItems)
                ShortcutRecorderView(action: .lockVault)
                ShortcutRecorderView(action: .generatePassword)
            } header: {
                HStack {
                    Text("General Shortcuts")
                    Spacer()
                    Button("Reset All") {
                        shortcutManager.resetAllShortcuts()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
            } footer: {
                Text("Click on a shortcut to change it. Press Escape to cancel.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            Section("New Item Shortcuts") {
                ShortcutRecorderView(action: .newAPIKey)
                ShortcutRecorderView(action: .newDatabase)
                ShortcutRecorderView(action: .newServer)
                ShortcutRecorderView(action: .newSSH)
                ShortcutRecorderView(action: .newCommand)
                ShortcutRecorderView(action: .newSecureNote)
            }
            
            Section("Action Shortcuts") {
                ShortcutRecorderView(action: .newProject)
                ShortcutRecorderView(action: .duplicateItem)
                ShortcutRecorderView(action: .deleteItem)
                ShortcutRecorderView(action: .toggleFavorite)
            }
            
            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("\(Constants.App.version) (\(Constants.App.build))")
                        .foregroundStyle(.secondary)
                }
                
                HStack {
                    Text("Developer")
                    Spacer()
                    Text("Digital Envision")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Data Settings

struct DataSettingsView: View {
    @Environment(AppState.self) private var appState
    
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var exportPassword = ""
    @State private var importPassword = ""
    @State private var showExportPasswordSheet = false
    @State private var showImportPasswordSheet = false
    @State private var showImportSheet = false
    @State private var showPlaintextWarning = false
    @State private var importURL: URL?
    @State private var importError: String?
    @State private var importSheetError: String? // Inline error shown in import sheet
    @State private var showImportError = false
    @State private var showImportSuccess = false
    @State private var importedItemCount = 0
    
    var body: some View {
        Form {
            Section("Export") {
                Button {
                    showExportPasswordSheet = true
                } label: {
                    Label("Export Encrypted Backup", systemImage: "lock.doc")
                }
                .disabled(appState.vaultService.state != .unlocked)
                
                Button {
                    showPlaintextWarning = true
                } label: {
                    Label("Export Plaintext (Unsafe)", systemImage: "doc")
                }
                .disabled(appState.vaultService.state != .unlocked)
                
                Text("Encrypted exports require a password to decrypt. Plaintext exports contain unencrypted data and should only be used for migration.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Section("Import") {
                Button {
                    showImportSheet = true
                } label: {
                    Label("Import from Backup", systemImage: "square.and.arrow.down")
                }
                .disabled(appState.vaultService.state != .unlocked)
                
                Text("Importing will add items from the backup to your vault.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $showExportPasswordSheet) {
            exportPasswordSheet
        }
        .sheet(isPresented: $showImportPasswordSheet) {
            importPasswordSheet
        }
        .alert("Export Plaintext?", isPresented: $showPlaintextWarning) {
            Button("Cancel", role: .cancel) {}
            Button("Export Anyway", role: .destructive) {
                exportPlaintext()
            }
        } message: {
            Text("Plaintext exports contain all your secrets in unencrypted form. Only use this for migration to other tools. The file should be deleted immediately after use.")
        }
        .alert("Import Error", isPresented: $showImportError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importError ?? "An unknown error occurred")
        }
        .alert("Import Successful", isPresented: $showImportSuccess) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Successfully imported \(importedItemCount) items from backup.")
        }
        .fileImporter(
            isPresented: $showImportSheet,
            allowedContentTypes: [.data, .json],
            allowsMultipleSelection: false
        ) { result in
            handleImport(result)
        }
    }
    
    // MARK: - Export Password Sheet
    
    private var exportPasswordSheet: some View {
        VStack(spacing: 20) {
            Text("Export Password")
                .font(.headline)
            
            Text("Enter a password to protect your export file. You'll need this password to import the backup later.")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            SecureTextField(title: "Export Password", text: $exportPassword)
            
            if !exportPassword.isEmpty && exportPassword.count < 8 {
                Text("Password must be at least 8 characters")
                    .font(.caption)
                    .foregroundStyle(.red)
            }
            
            HStack {
                Button("Cancel") {
                    exportPassword = ""
                    showExportPasswordSheet = false
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Export") {
                    exportEncrypted()
                }
                .keyboardShortcut(.return)
                .disabled(exportPassword.count < 8)
            }
        }
        .padding()
        .frame(width: 350)
    }
    
    // MARK: - Import Password Sheet
    
    @ViewBuilder
    private var importPasswordSheet: some View {
        ImportPasswordSheetContent(
            importPassword: $importPassword,
            isImporting: $isImporting,
            errorMessage: $importSheetError,
            onCancel: {
                importPassword = ""
                importURL = nil
                importSheetError = nil
                showImportPasswordSheet = false
            },
            onImport: { [self] in
                guard !importPassword.isEmpty else { return }
                guard importURL != nil else {
                    importSheetError = "No backup file selected"
                    return
                }
                importSheetError = nil // Clear previous error
                isImporting = true
                Task { @MainActor in
                    await doEncryptedImport()
                }
            }
        )
    }
    
    // MARK: - Export Functions
    
    private func exportEncrypted() {
        // Capture password before showing panel (in case state changes)
        let password = exportPassword
        guard !password.isEmpty, password.count >= 8 else {
            importError = "Password must be at least 8 characters"
            showImportError = true
            return
        }
        
        let panel = NSSavePanel()
        panel.nameFieldStringValue = appState.importExportService.generateExportFilename(encrypted: true)
        panel.allowedContentTypes = [.data]
        
        panel.begin { [self] response in
            guard response == .OK, let url = panel.url else { return }
            
            Task { @MainActor in
                do {
                    try await appState.importExportService.exportEncrypted(to: url, password: password)
                    exportPassword = ""
                    showExportPasswordSheet = false
                    ToastManager.shared.show("Backup exported successfully", icon: "checkmark.circle.fill")
                } catch {
                    importError = "Export failed: \(error.localizedDescription)"
                    showImportError = true
                }
            }
        }
    }
    
    private func exportPlaintext() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = appState.importExportService.generateExportFilename(encrypted: false)
        panel.allowedContentTypes = [.data]
        
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            
            Task {
                do {
                    try await appState.importExportService.exportPlaintext(to: url)
                    ToastManager.shared.show("Backup exported successfully", icon: "checkmark.circle.fill")
                } catch {
                    importError = error.localizedDescription
                    showImportError = true
                }
            }
        }
    }
    
    // MARK: - Import Functions
    
    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Start accessing the security-scoped resource
            guard url.startAccessingSecurityScopedResource() else {
                importError = "Unable to access the selected file"
                showImportError = true
                return
            }
            
            defer {
                url.stopAccessingSecurityScopedResource()
            }
            
            // Copy to a temporary location that we can access later
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            do {
                if FileManager.default.fileExists(atPath: tempURL.path) {
                    try FileManager.default.removeItem(at: tempURL)
                }
                try FileManager.default.copyItem(at: url, to: tempURL)
                importURL = tempURL
                
                // Check if encrypted
                let isEncrypted = try appState.importExportService.isEncrypted(at: tempURL)
                
                if isEncrypted {
                    // Show password prompt
                    showImportPasswordSheet = true
                } else {
                    // Import plaintext directly
                    performPlaintextImport()
                }
            } catch {
                importError = "Failed to read file: \(error.localizedDescription)"
                showImportError = true
            }
            
        case .failure(let error):
            importError = error.localizedDescription
            showImportError = true
        }
    }
    
    @MainActor
    private func doEncryptedImport() async {
        guard let url = importURL else {
            isImporting = false
            importSheetError = "No file selected"
            return
        }
        
        let password = importPassword
        
        // Verify file exists and is readable
        guard FileManager.default.fileExists(atPath: url.path) else {
            isImporting = false
            importSheetError = "Backup file not found"
            return
        }
        
        do {
            // Read the file data first to ensure we have access
            let fileData = try Data(contentsOf: url)
            guard !fileData.isEmpty else {
                throw ImportExportError.invalidFormat
            }
            
            let itemCountBefore = appState.items.count
            try await appState.importExportService.importEncrypted(from: url, password: password)
            await appState.loadData()
            
            let newCount = appState.items.count
            importedItemCount = max(newCount - itemCountBefore, newCount)
            
            // Clean up temp file
            try? FileManager.default.removeItem(at: url)
            
            // Clean up state - SUCCESS
            importPassword = ""
            importURL = nil
            importSheetError = nil
            isImporting = false
            showImportPasswordSheet = false
            
            // Show success after sheet is dismissed
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [self] in
                showImportSuccess = true
            }
        } catch ImportExportError.invalidPassword {
            // Show error inline in the sheet - user can retry with a different password
            isImporting = false
            importSheetError = "Incorrect password. Please try again."
        } catch let error as ImportExportError {
            // Show error inline in the sheet
            isImporting = false
            importSheetError = error.localizedDescription
        } catch {
            // Show error inline in the sheet
            isImporting = false
            importSheetError = "Import failed: \(error.localizedDescription)"
        }
    }
    
    private func performPlaintextImport() {
        guard let url = importURL else { return }
        
        Task {
            do {
                let itemCountBefore = appState.items.count
                try await appState.importExportService.importPlaintext(from: url)
                await appState.loadData()
                
                importedItemCount = appState.items.count - itemCountBefore
                if importedItemCount < 0 { importedItemCount = appState.items.count }
                
                // Clean up
                importURL = nil
                
                // Clean up temp file
                try? FileManager.default.removeItem(at: url)
                
                showImportSuccess = true
            } catch {
                importError = error.localizedDescription
                showImportError = true
            }
        }
    }
}

// MARK: - Privacy Settings

struct PrivacySettingsView: View {
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.green)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("100% Local & Offline")
                                .font(.headline)
                            Text("Your data never leaves your Mac")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 8)
            }
            
            Section("Privacy Guarantees") {
                PrivacyRow(
                    icon: "wifi.slash",
                    iconColor: .green,
                    title: "No Internet Required",
                    description: "CodeBank works completely offline. No network connection is ever needed."
                )
                
                PrivacyRow(
                    icon: "server.rack",
                    iconColor: .green,
                    title: "No Cloud Servers",
                    description: "Your secrets are never sent to any server. Everything stays on your Mac."
                )
                
                PrivacyRow(
                    icon: "chart.bar.xaxis",
                    iconColor: .green,
                    title: "No Analytics or Tracking",
                    description: "Zero telemetry. We don't track how you use the app."
                )
                
                PrivacyRow(
                    icon: "eye.slash.fill",
                    iconColor: .green,
                    title: "No Third-Party Services",
                    description: "No external APIs, no SDKs, no data sharing with anyone."
                )
            }
            
            Section("Where Your Data Lives") {
                VStack(alignment: .leading, spacing: 12) {
                    DataLocationRow(
                        title: "Encrypted Database",
                        path: "~/Library/Application Support/",
                        detail: "AES-256 encrypted SQLite database"
                    )
                    
                    Divider()
                    
                    DataLocationRow(
                        title: "Encryption Keys",
                        path: "macOS Keychain",
                        detail: "Protected by your Mac's Secure Enclave"
                    )
                }
                .padding(.vertical, 4)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Verify It Yourself")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text("Use network monitoring tools like Little Snitch, Lulu, or Wireshark to verify CodeBank makes zero network connections.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct PrivacyRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DataLocationRow: View {
    let title: String
    let path: String
    let detail: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Text(path)
                .font(.caption)
                .fontDesign(.monospaced)
                .foregroundStyle(.secondary)
            
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Support Settings

struct SupportSettingsView: View {
    private let supportEmail = "support@codebank.app"
    
    var body: some View {
        Form {
            Section("Get Help") {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Have questions, found a bug, or want to request a feature?")
                        .foregroundStyle(.secondary)
                    
                    Text("We'd love to hear from you!")
                }
                .padding(.vertical, 4)
            }
            
            Section("Contact Us") {
                VStack(alignment: .leading, spacing: 12) {
                    // Email support button
                    Button {
                        sendEmail(to: supportEmail, subject: "CodeBank Support")
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                                .frame(width: 32)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Email Support")
                                    .fontWeight(.medium)
                                Text(supportEmail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            
            Section("Quick Links") {
                // Bug report
                Button {
                    sendEmail(to: supportEmail, subject: "CodeBank Bug Report", body: bugReportTemplate)
                } label: {
                    Label("Report a Bug", systemImage: "ladybug")
                }
                .buttonStyle(.plain)
                
                // Feature request
                Button {
                    sendEmail(to: supportEmail, subject: "CodeBank Feature Request", body: featureRequestTemplate)
                } label: {
                    Label("Request a Feature", systemImage: "lightbulb")
                }
                .buttonStyle(.plain)
                
                // General question
                Button {
                    sendEmail(to: supportEmail, subject: "CodeBank Question")
                } label: {
                    Label("Ask a Question", systemImage: "bubble.left.and.bubble.right")
                }
                .buttonStyle(.plain)
            }
            
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 4) {
                        Text("Made with ❤️ by Digital Envision")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
    
    private var bugReportTemplate: String {
        """
        
        
        --- Please describe the bug below ---
        
        What happened:
        
        
        What I expected:
        
        
        Steps to reproduce:
        1. 
        2. 
        3. 
        
        --- System Info ---
        App Version: \(Constants.App.version) (\(Constants.App.build))
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        """
    }
    
    private var featureRequestTemplate: String {
        """
        
        
        --- Please describe your feature request below ---
        
        Feature description:
        
        
        Why it would be useful:
        
        
        --- System Info ---
        App Version: \(Constants.App.version) (\(Constants.App.build))
        """
    }
    
    private func sendEmail(to address: String, subject: String, body: String = "") {
        let encodedSubject = subject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? subject
        let encodedBody = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? body
        
        if let url = URL(string: "mailto:\(address)?subject=\(encodedSubject)&body=\(encodedBody)") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - Shortcut Row

struct ShortcutRow: View {
    let action: String
    let shortcut: String
    
    var body: some View {
        HStack {
            Text(action)
            Spacer()
            Text(shortcut)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Import Password Sheet Content

struct ImportPasswordSheetContent: View {
    @Binding var importPassword: String
    @Binding var isImporting: Bool
    @Binding var errorMessage: String?
    let onCancel: () -> Void
    let onImport: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "lock.doc.fill")
                    .font(.title)
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading) {
                    Text("Encrypted Backup")
                        .font(.headline)
                    Text("Enter the password to decrypt this backup")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
            }
            
            VStack(spacing: 8) {
                SecureField("Backup Password", text: $importPassword)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        if !importPassword.isEmpty && !isImporting {
                            onImport()
                        }
                    }
                    .onChange(of: importPassword) { _, _ in
                        // Clear error when user starts typing again
                        if errorMessage != nil {
                            errorMessage = nil
                        }
                    }
                
                // Error message shown inline - always reserve space
                if let error = errorMessage {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white)
                        Text(error)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: errorMessage)
            
            if isImporting {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Decrypting and importing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)
                .disabled(isImporting)
                
                Spacer()
                
                Button("Import") {
                    onImport()
                }
                .buttonStyle(.borderedProminent)
                .disabled(importPassword.isEmpty || isImporting)
            }
        }
        .padding(20)
        .frame(width: 400)
    }
}

#Preview {
    SettingsView()
        .environment(AppState.shared)
        .environment(VaultService.shared)
}
