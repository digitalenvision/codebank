import SwiftUI

/// Main application entry point
@main
struct CodeBankApp: App {
    
    // MARK: - App Delegate
    
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // MARK: - State
    
    @State private var appState = AppState.shared
    @State private var vaultService = VaultService.shared
    @State private var shortcutManager = KeyboardShortcutManager.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage(Constants.UserDefaults.showMenuBarIcon) private var showMenuBarIcon = true
    
    // MARK: - Body
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(vaultService)
                .onAppear {
                    configureAppearance()
                }
                .sheet(isPresented: $appState.showPasswordGenerator) {
                    PasswordGeneratorView()
                }
                .sheet(isPresented: .init(
                    get: { !hasCompletedOnboarding && vaultService.state == .needsSetup },
                    set: { _ in }
                )) {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: Constants.UI.mainWindowMinWidth, height: Constants.UI.mainWindowMinHeight)
        .commands {
            appCommands
        }
        
        // Menu Bar
        MenuBarExtra("CodeBank", systemImage: vaultService.state == .unlocked ? "shield.fill" : "shield.slash.fill", isInserted: $showMenuBarIcon) {
            MenuBarView()
                .environment(appState)
                .environment(vaultService)
        }
        .menuBarExtraStyle(.window)
        
        Settings {
            SettingsView()
                .environment(appState)
                .environment(vaultService)
        }
    }
    
    // MARK: - Commands
    
    @CommandsBuilder
    private var appCommands: some Commands {
        // File menu - New items
        CommandGroup(replacing: .newItem) {
            Menu("New Item") {
                ForEach(ItemType.allCases, id: \.self) { type in
                    Button {
                        appState.showNewItemEditor(type: type)
                    } label: {
                        Label(type.displayName, systemImage: type.icon)
                    }
                    .keyboardShortcut(keyboardShortcut(for: type))
                    .disabled(vaultService.state != .unlocked)
                }
            }
            .disabled(vaultService.state != .unlocked)
            
            Divider()
            
            Button("New Project") {
                appState.showNewProjectSheet = true
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(vaultService.state != .unlocked)
        }
        
        // Edit menu - Item actions
        CommandGroup(after: .pasteboard) {
            Divider()
            
            Button("Duplicate Item") {
                if let item = appState.selectedItem {
                    Task {
                        try? await appState.duplicateItem(item)
                    }
                }
            }
            .keyboardShortcut("d", modifiers: [.command])
            .disabled(vaultService.state != .unlocked || appState.selectedItem == nil)
            
            Button("Delete Item") {
                if appState.selectedItem != nil {
                    appState.showDeleteConfirmation = true
                }
            }
            .keyboardShortcut(.delete, modifiers: [.command])
            .disabled(vaultService.state != .unlocked || appState.selectedItem == nil)
            
            Divider()
            
            Button("Toggle Favorite") {
                if let item = appState.selectedItem {
                    Task {
                        try? await appState.toggleFavorite(item)
                    }
                }
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .disabled(vaultService.state != .unlocked || appState.selectedItem == nil)
        }
        
        // View menu - Search and navigation
        CommandGroup(after: .sidebar) {
            Button("Search") {
                appState.focusSearch = true
            }
            .keyboardShortcut("f", modifiers: [.command])
            .disabled(vaultService.state != .unlocked)
            
            Button("Quick Search") {
                appState.toggleQuickSearch()
            }
            .keyboardShortcut(.space, modifiers: [.command, .shift])
            .disabled(vaultService.state != .unlocked)
            
            Divider()
            
            Button("Lock Vault") {
                vaultService.lock()
            }
            .keyboardShortcut("l", modifiers: [.command, .shift])
            .disabled(vaultService.state != .unlocked)
        }
        
        // Tools menu - add as a separate menu
        CommandMenu("Tools") {
            Button("Generate Password...") {
                appState.showPasswordGenerator = true
            }
            .keyboardShortcut("g", modifiers: [.command])
            .disabled(vaultService.state != .unlocked)
        }
        
        // File menu - Import/Export
        CommandGroup(replacing: .importExport) {
            Button("Export Encrypted...") {
                // Show export dialog
            }
            .disabled(vaultService.state != .unlocked)
            
            Button("Export Plaintext...") {
                // Show export dialog with warning
            }
            .disabled(vaultService.state != .unlocked)
            
            Divider()
            
            Button("Import...") {
                // Show import dialog
            }
            .disabled(vaultService.state != .unlocked)
        }
    }
    
    // MARK: - Helpers
    
    private func keyboardShortcut(for type: ItemType) -> KeyboardShortcut? {
        switch type {
        case .apiKey: return KeyboardShortcut("1", modifiers: [.command])
        case .database: return KeyboardShortcut("2", modifiers: [.command])
        case .server: return KeyboardShortcut("3", modifiers: [.command])
        case .ssh: return KeyboardShortcut("4", modifiers: [.command])
        case .command: return KeyboardShortcut("5", modifiers: [.command])
        case .secureNote: return KeyboardShortcut("6", modifiers: [.command])
        }
    }
    
    private func configureAppearance() {
        // Configure any global appearance settings
    }
}

// MARK: - Content View

/// Root content view that switches between setup, unlock, and main views
struct ContentView: View {
    @Environment(VaultService.self) private var vaultService
    @Environment(AppState.self) private var appState
    
    var body: some View {
        Group {
            switch vaultService.state {
            case .needsSetup:
                SetupView()
                
            case .locked:
                UnlockView()
                
            case .unlocked:
                MainView()
                    .task {
                        await appState.loadData()
                    }
                
            case .error(let message):
                errorView(message: message)
            }
        }
        .frame(
            minWidth: Constants.UI.mainWindowMinWidth,
            minHeight: Constants.UI.mainWindowMinHeight
        )
        .animation(.easeInOut(duration: 0.3), value: vaultService.state)
    }
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.red)
            
            Text("Error")
                .font(.title)
                .fontWeight(.semibold)
            
            Text(message)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                // Reset state
            }
            .primaryButtonStyle()
        }
        .padding(40)
    }
}
