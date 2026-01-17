import Foundation
import AppKit

/// UserDefaults key for terminal preference
private let preferredTerminalKey = "preferred_terminal"

/// Errors that can occur during command execution
enum CommandError: LocalizedError {
    case terminalNotFound
    case executionFailed(String)
    case invalidCommand
    case userCancelled
    
    var errorDescription: String? {
        switch self {
        case .terminalNotFound:
            return "Terminal application not found"
        case .executionFailed(let reason):
            return "Command execution failed: \(reason)"
        case .invalidCommand:
            return "Invalid command"
        case .userCancelled:
            return "Command execution cancelled by user"
        }
    }
}

/// Handles executing commands and SSH connections in Terminal
@MainActor
final class CommandService {
    
    // MARK: - Singleton
    
    static let shared = CommandService()
    
    // MARK: - Properties
    
    /// The preferred terminal application
    var preferredTerminal: TerminalApp {
        get {
            if let stored = UserDefaults.standard.string(forKey: preferredTerminalKey),
               let terminal = TerminalApp(rawValue: stored) {
                return terminal
            }
            return .terminal
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: preferredTerminalKey)
        }
    }
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Command Execution
    
    /// Executes a command item in Terminal
    /// - Parameter item: The command item to execute
    /// - Throws: `CommandError` if execution fails
    func execute(_ item: Item) async throws {
        guard item.type == .command, let commandData = item.commandData else {
            throw CommandError.invalidCommand
        }
        
        // Build the full command
        let command = commandData.fullCommand()
        
        try await executeInTerminal(command)
    }
    
    /// Executes a raw command string in Terminal
    /// - Parameter command: The command to execute
    /// - Throws: `CommandError` if execution fails
    func executeInTerminal(_ command: String) async throws {
        guard !command.isEmpty else {
            throw CommandError.invalidCommand
        }
        
        switch preferredTerminal {
        case .terminal:
            try await executeInAppleTerminal(command)
        case .iterm:
            try await executeInITerm(command)
        }
    }
    
    // MARK: - Apple Terminal
    
    private func executeInAppleTerminal(_ command: String) async throws {
        let escapedCommand = escapeForAppleScript(command)
        
        let script = """
        tell application "Terminal"
            activate
            do script "\(escapedCommand)"
        end tell
        """
        
        try await runAppleScript(script)
    }
    
    // MARK: - iTerm
    
    private func executeInITerm(_ command: String) async throws {
        // Check if iTerm is installed
        guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: TerminalApp.iterm.bundleIdentifier) != nil else {
            // Fall back to Apple Terminal
            try await executeInAppleTerminal(command)
            return
        }
        
        let escapedCommand = escapeForAppleScript(command)
        
        let script = """
        tell application "iTerm"
            activate
            if (count of windows) = 0 then
                create window with default profile
            end if
            tell current session of current window
                write text "\(escapedCommand)"
            end tell
        end tell
        """
        
        try await runAppleScript(script)
    }
    
    // MARK: - SSH Execution
    
    /// Opens an SSH connection in Terminal
    /// - Parameter item: The SSH item to connect
    /// - Throws: `CommandError` if execution fails
    func openSSH(_ item: Item) async throws {
        guard item.type == .ssh, let sshData = item.sshData else {
            throw CommandError.invalidCommand
        }
        
        let command = sshData.sshCommand()
        try await executeInTerminal(command)
    }
    
    /// Opens an SSH connection with the given parameters
    /// - Parameters:
    ///   - user: The SSH username
    ///   - host: The SSH host
    ///   - port: The SSH port (default: 22)
    ///   - identityKeyPath: Optional path to the identity key
    func openSSH(user: String, host: String, port: Int = 22, identityKeyPath: String? = nil) async throws {
        var command = "ssh"
        
        if port != 22 {
            command += " -p \(port)"
        }
        
        if let keyPath = identityKeyPath, !keyPath.isEmpty {
            command += " -i \"\(keyPath)\""
        }
        
        command += " \(user)@\(host)"
        
        try await executeInTerminal(command)
    }
    
    // MARK: - Command Preview
    
    /// Generates a preview of the command that will be executed
    /// - Parameter item: The item to preview
    /// - Returns: The command string that would be executed
    func previewCommand(_ item: Item) -> String? {
        switch item.type {
        case .command:
            return item.commandData?.fullCommand()
        case .ssh:
            return item.sshData?.sshCommand()
        default:
            return nil
        }
    }
    
    // MARK: - Helper Methods
    
    /// Escapes a string for use in AppleScript
    private func escapeForAppleScript(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
    
    /// Runs an AppleScript
    private func runAppleScript(_ script: String) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var error: NSDictionary?
                
                guard let appleScript = NSAppleScript(source: script) else {
                    continuation.resume(throwing: CommandError.executionFailed("Failed to create AppleScript"))
                    return
                }
                
                appleScript.executeAndReturnError(&error)
                
                if let error = error {
                    let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                    continuation.resume(throwing: CommandError.executionFailed(message))
                } else {
                    continuation.resume()
                }
            }
        }
    }
    
    // MARK: - Terminal Availability
    
    /// Checks if the preferred terminal is available
    var isTerminalAvailable: Bool {
        let bundleId = preferredTerminal.bundleIdentifier
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleId) != nil
    }
    
    /// Gets a list of available terminals
    var availableTerminals: [TerminalApp] {
        TerminalApp.allCases.filter { terminal in
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminal.bundleIdentifier) != nil
        }
    }
}

// MARK: - Shell Command Escaping

extension String {
    /// Escapes the string for safe use in shell commands
    var shellEscaped: String {
        // Wrap in single quotes and escape any existing single quotes
        "'" + self.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
    
    /// Escapes the string for use in double-quoted shell strings
    var doubleQuoteEscaped: String {
        self
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")
    }
}
