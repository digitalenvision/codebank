import SwiftUI

/// Menu bar status item view
struct MenuBarView: View {
    @Environment(AppState.self) private var appState
    @Environment(VaultService.self) private var vaultService
    
    var body: some View {
        VStack(spacing: 0) {
            if vaultService.state == .unlocked {
                unlockedContent
            } else {
                lockedContent
            }
        }
        .frame(width: 280)
    }
    
    // MARK: - Locked Content
    
    private var lockedContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.fill")
                .font(.system(size: 32))
                .foregroundStyle(.secondary)
            
            Text("Vault Locked")
                .font(.headline)
            
            Text("Open CodeBank to unlock")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            Button("Open CodeBank") {
                openMainWindow()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(20)
    }
    
    // MARK: - Unlocked Content
    
    private var unlockedContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Spacer()
                CodeBankLogo(size: .small)
                Spacer()
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            
            Divider()
            
            // Quick actions
            VStack(spacing: 2) {
                // Recent/Favorite items
                if !appState.items.isEmpty {
                    let favorites = appState.items.filter { $0.isFavorite }.prefix(5)
                    
                    if !favorites.isEmpty {
                        ForEach(Array(favorites)) { item in
                            MenuBarItemRow(item: item)
                        }
                        
                        Divider()
                            .padding(.vertical, 4)
                    }
                }
                
                // Actions
                MenuBarButton(icon: "magnifyingglass", title: "Quick Search", shortcut: "⌘⇧Space") {
                    openMainWindow()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        appState.toggleQuickSearch()
                    }
                }
                
                // New Item with submenu
                MenuBarSubmenu(icon: "plus", title: "New Item") {
                    ForEach(ItemType.allCases, id: \.self) { type in
                        Button {
                            openMainWindow()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                appState.showNewItemEditor(type: type)
                            }
                        } label: {
                            Label(type.displayName, systemImage: type.icon)
                        }
                    }
                }
                
                MenuBarButton(icon: "key.fill", title: "Generate Password", shortcut: "⌘G") {
                    openMainWindow()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        appState.showPasswordGenerator = true
                    }
                }
                
                Divider()
                    .padding(.vertical, 4)
                
                MenuBarButton(icon: "lock.fill", title: "Lock Vault", shortcut: "⌘⇧L") {
                    vaultService.lock()
                }
                
                // Settings using SettingsLink for proper macOS integration
                SettingsLink {
                    HStack(spacing: 10) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 12))
                            .frame(width: 16)
                        
                        Text("Settings...")
                            .font(.system(size: 13))
                        
                        Spacer()
                        
                        Text("⌘,")
                            .font(.system(size: 11))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(MenuBarLinkStyle())
            }
            .padding(.vertical, 4)
            
            Divider()
            
            // Footer
            HStack {
                Text("\(appState.items.count) items")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .font(.caption)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }
            .padding(10)
        }
    }
    
    // MARK: - Actions
    
    private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.title == "CodeBank" || !($0 is NSPanel) }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // Open new window if needed
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }
    
    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}

// MARK: - Menu Bar Item Row

struct MenuBarItemRow: View {
    let item: Item
    
    var body: some View {
        Button {
            copyPrimaryValue()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: item.icon)
                    .font(.system(size: 12))
                    .foregroundStyle(item.color)
                    .frame(width: 16)
                
                Text(item.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                
                Spacer()
                
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(Color.clear)
    }
    
    private func copyPrimaryValue() {
        if let value = item.primaryValue {
            ClipboardService.shared.copySecret(value)
            ToastManager.shared.showCopied(item.name)
        }
    }
}

// MARK: - Menu Bar Button

struct MenuBarButton: View {
    let icon: String
    let title: String
    var shortcut: String? = nil
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
                
                Text(title)
                    .font(.system(size: 13))
                
                Spacer()
                
                if let shortcut = shortcut {
                    Text(shortcut)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.5) : Color.clear)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Menu Bar Submenu

struct MenuBarSubmenu<Content: View>: View {
    let icon: String
    let title: String
    @ViewBuilder let content: () -> Content
    
    @State private var isHovered = false
    
    var body: some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12))
                    .frame(width: 16)
                
                Text(title)
                    .font(.system(size: 13))
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(MenuBarSubmenuButtonStyle(isHovered: isHovered))
        .menuIndicator(.hidden)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// Custom button style for submenu to match MenuBarButton exactly
struct MenuBarSubmenuButtonStyle: ButtonStyle {
    let isHovered: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(isHovered || configuration.isPressed ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.5) : Color.clear)
    }
}

// MARK: - Menu Bar Link Style (for SettingsLink)

struct MenuBarLinkStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(isHovered || configuration.isPressed ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.5) : Color.clear)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

#Preview {
    MenuBarView()
        .environment(AppState.shared)
        .environment(VaultService.shared)
}
