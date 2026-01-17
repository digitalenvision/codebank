import SwiftUI
import Carbon.HIToolbox

/// Identifies each customizable keyboard shortcut in the app
enum ShortcutAction: String, CaseIterable, Codable {
    case quickSearch = "quick_search"
    case searchItems = "search_items"
    case lockVault = "lock_vault"
    case generatePassword = "generate_password"
    case newAPIKey = "new_api_key"
    case newDatabase = "new_database"
    case newServer = "new_server"
    case newSSH = "new_ssh"
    case newCommand = "new_command"
    case newSecureNote = "new_secure_note"
    case newProject = "new_project"
    case duplicateItem = "duplicate_item"
    case deleteItem = "delete_item"
    case toggleFavorite = "toggle_favorite"
    
    var displayName: String {
        switch self {
        case .quickSearch: return "Quick Search"
        case .searchItems: return "Search Items"
        case .lockVault: return "Lock Vault"
        case .generatePassword: return "Generate Password"
        case .newAPIKey: return "New API Key"
        case .newDatabase: return "New Database"
        case .newServer: return "New Server"
        case .newSSH: return "New SSH"
        case .newCommand: return "New Command"
        case .newSecureNote: return "New Secure Note"
        case .newProject: return "New Project"
        case .duplicateItem: return "Duplicate Item"
        case .deleteItem: return "Delete Item"
        case .toggleFavorite: return "Toggle Favorite"
        }
    }
    
    var category: ShortcutCategory {
        switch self {
        case .quickSearch, .searchItems, .lockVault, .generatePassword:
            return .general
        case .newAPIKey, .newDatabase, .newServer, .newSSH, .newCommand, .newSecureNote:
            return .newItems
        case .newProject, .duplicateItem, .deleteItem, .toggleFavorite:
            return .actions
        }
    }
}

enum ShortcutCategory: String, CaseIterable {
    case general = "General"
    case newItems = "New Items"
    case actions = "Actions"
}

/// Represents a keyboard shortcut configuration
struct ShortcutConfig: Codable, Equatable {
    var key: String // The key character or special key name
    var modifiers: [String] // "command", "shift", "option", "control"
    
    var displayString: String {
        var parts: [String] = []
        if modifiers.contains("control") { parts.append("⌃") }
        if modifiers.contains("option") { parts.append("⌥") }
        if modifiers.contains("shift") { parts.append("⇧") }
        if modifiers.contains("command") { parts.append("⌘") }
        parts.append(keyDisplayString)
        return parts.joined()
    }
    
    var keyDisplayString: String {
        switch key.lowercased() {
        case "space": return "Space"
        case "delete", "backspace": return "⌫"
        case "return", "enter": return "↩"
        case "tab": return "⇥"
        case "escape": return "⎋"
        case "up": return "↑"
        case "down": return "↓"
        case "left": return "←"
        case "right": return "→"
        default: return key.uppercased()
        }
    }
    
    var swiftUIKey: KeyEquivalent {
        switch key.lowercased() {
        case "space": return .space
        case "delete", "backspace": return .delete
        case "return", "enter": return .return
        case "tab": return .tab
        case "escape": return .escape
        case "up": return .upArrow
        case "down": return .downArrow
        case "left": return .leftArrow
        case "right": return .rightArrow
        default:
            if let char = key.lowercased().first {
                return KeyEquivalent(char)
            }
            return KeyEquivalent("a")
        }
    }
    
    var swiftUIModifiers: SwiftUI.EventModifiers {
        var result: SwiftUI.EventModifiers = []
        if modifiers.contains("command") { result.insert(.command) }
        if modifiers.contains("shift") { result.insert(.shift) }
        if modifiers.contains("option") { result.insert(.option) }
        if modifiers.contains("control") { result.insert(.control) }
        return result
    }
}

/// Manages keyboard shortcuts for the application
@Observable
final class KeyboardShortcutManager {
    static let shared = KeyboardShortcutManager()
    
    private let userDefaultsKey = "custom_keyboard_shortcuts"
    
    /// Current shortcut configurations
    var shortcuts: [ShortcutAction: ShortcutConfig] = [:]
    
    private init() {
        loadShortcuts()
    }
    
    /// Default shortcuts
    static let defaults: [ShortcutAction: ShortcutConfig] = [
        .quickSearch: ShortcutConfig(key: "space", modifiers: ["command", "shift"]),
        .searchItems: ShortcutConfig(key: "f", modifiers: ["command"]),
        .lockVault: ShortcutConfig(key: "l", modifiers: ["command", "shift"]),
        .generatePassword: ShortcutConfig(key: "g", modifiers: ["command"]),
        .newAPIKey: ShortcutConfig(key: "1", modifiers: ["command"]),
        .newDatabase: ShortcutConfig(key: "2", modifiers: ["command"]),
        .newServer: ShortcutConfig(key: "3", modifiers: ["command"]),
        .newSSH: ShortcutConfig(key: "4", modifiers: ["command"]),
        .newCommand: ShortcutConfig(key: "5", modifiers: ["command"]),
        .newSecureNote: ShortcutConfig(key: "6", modifiers: ["command"]),
        .newProject: ShortcutConfig(key: "n", modifiers: ["command", "shift"]),
        .duplicateItem: ShortcutConfig(key: "d", modifiers: ["command"]),
        .deleteItem: ShortcutConfig(key: "delete", modifiers: ["command"]),
        .toggleFavorite: ShortcutConfig(key: "f", modifiers: ["command", "shift"]),
    ]
    
    /// Get shortcut for an action
    func shortcut(for action: ShortcutAction) -> ShortcutConfig {
        shortcuts[action] ?? Self.defaults[action]!
    }
    
    /// Update shortcut for an action
    func setShortcut(_ config: ShortcutConfig, for action: ShortcutAction) {
        shortcuts[action] = config
        saveShortcuts()
    }
    
    /// Reset a single shortcut to default
    func resetShortcut(for action: ShortcutAction) {
        shortcuts[action] = Self.defaults[action]
        saveShortcuts()
    }
    
    /// Reset all shortcuts to defaults
    func resetAllShortcuts() {
        shortcuts = Self.defaults
        saveShortcuts()
    }
    
    /// Load shortcuts from UserDefaults
    private func loadShortcuts() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([ShortcutAction: ShortcutConfig].self, from: data) {
            shortcuts = decoded
        } else {
            shortcuts = Self.defaults
        }
    }
    
    /// Save shortcuts to UserDefaults
    private func saveShortcuts() {
        if let encoded = try? JSONEncoder().encode(shortcuts) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }
}

// MARK: - Shortcut Recorder View

struct ShortcutRecorderView: View {
    let action: ShortcutAction
    @State private var isRecording = false
    @State private var currentConfig: ShortcutConfig
    @Environment(\.colorScheme) private var colorScheme
    
    private let shortcutManager = KeyboardShortcutManager.shared
    
    init(action: ShortcutAction) {
        self.action = action
        _currentConfig = State(initialValue: KeyboardShortcutManager.shared.shortcut(for: action))
    }
    
    var body: some View {
        HStack {
            Text(action.displayName)
            
            Spacer()
            
            // Shortcut display/recorder
            Button {
                isRecording = true
            } label: {
                Text(isRecording ? "Press keys..." : currentConfig.displayString)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(isRecording ? .cyan : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isRecording ? Color.cyan.opacity(0.15) : Color(nsColor: .controlBackgroundColor))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(isRecording ? Color.cyan : Color.clear, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .background(
                ShortcutRecorderHelper(
                    isRecording: $isRecording,
                    onShortcutRecorded: { config in
                        currentConfig = config
                        shortcutManager.setShortcut(config, for: action)
                    }
                )
            )
            
            // Reset button
            if currentConfig != KeyboardShortcutManager.defaults[action] {
                Button {
                    shortcutManager.resetShortcut(for: action)
                    currentConfig = shortcutManager.shortcut(for: action)
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Reset to default")
            }
        }
    }
}

// MARK: - Shortcut Recorder Helper (NSView-based keyboard capture)

struct ShortcutRecorderHelper: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onShortcutRecorded: (ShortcutConfig) -> Void
    
    func makeNSView(context: Context) -> ShortcutCaptureView {
        let view = ShortcutCaptureView()
        view.onShortcutRecorded = { config in
            onShortcutRecorded(config)
            isRecording = false
        }
        view.onCancel = {
            isRecording = false
        }
        return view
    }
    
    func updateNSView(_ nsView: ShortcutCaptureView, context: Context) {
        if isRecording {
            nsView.startRecording()
        } else {
            nsView.stopRecording()
        }
    }
}

class ShortcutCaptureView: NSView {
    var onShortcutRecorded: ((ShortcutConfig) -> Void)?
    var onCancel: (() -> Void)?
    private var eventMonitor: Any?
    
    override var acceptsFirstResponder: Bool { true }
    
    func startRecording() {
        window?.makeFirstResponder(self)
        
        // Use local event monitor to capture key events
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self = self else { return event }
            
            // Escape cancels recording
            if event.keyCode == 53 { // Escape
                self.onCancel?()
                return nil
            }
            
            // Ignore pure modifier key presses
            if event.type == .flagsChanged {
                return nil
            }
            
            // Build shortcut config
            var modifiers: [String] = []
            if event.modifierFlags.contains(.command) { modifiers.append("command") }
            if event.modifierFlags.contains(.shift) { modifiers.append("shift") }
            if event.modifierFlags.contains(.option) { modifiers.append("option") }
            if event.modifierFlags.contains(.control) { modifiers.append("control") }
            
            // Require at least one modifier (except for function keys)
            let isFunctionKey = event.keyCode >= 122 && event.keyCode <= 126
            if modifiers.isEmpty && !isFunctionKey {
                return nil
            }
            
            let key = self.keyString(for: event)
            if !key.isEmpty {
                let config = ShortcutConfig(key: key, modifiers: modifiers)
                self.onShortcutRecorded?(config)
            }
            
            return nil
        }
    }
    
    func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func keyString(for event: NSEvent) -> String {
        switch event.keyCode {
        case 49: return "space"
        case 51: return "delete"
        case 36: return "return"
        case 48: return "tab"
        case 53: return "escape"
        case 126: return "up"
        case 125: return "down"
        case 123: return "left"
        case 124: return "right"
        default:
            if let chars = event.charactersIgnoringModifiers, !chars.isEmpty {
                return String(chars.first!).lowercased()
            }
            return ""
        }
    }
    
    deinit {
        stopRecording()
    }
}
