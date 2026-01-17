import Foundation
import SwiftUI

/// Item type identifiers
enum ItemType: String, CaseIterable, Codable, Hashable {
    case apiKey = "api_key"
    case database = "database"
    case server = "server"
    case ssh = "ssh"
    case command = "command"
    case secureNote = "secure_note"
    
    var displayName: String {
        switch self {
        case .apiKey: return "API Key"
        case .database: return "Database"
        case .server: return "Server"
        case .ssh: return "SSH Connection"
        case .command: return "Command"
        case .secureNote: return "Secure Note"
        }
    }
    
    var icon: String {
        switch self {
        case .apiKey: return "key.fill"
        case .database: return "cylinder.fill"
        case .server: return "server.rack"
        case .ssh: return "terminal.fill"
        case .command: return "command"
        case .secureNote: return "doc.text.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .apiKey: return .orange
        case .database: return .purple
        case .server: return .blue
        case .ssh: return .green
        case .command: return .red
        case .secureNote: return .gray
        }
    }
}

/// Shell types for commands
enum ShellType: String, CaseIterable, Codable, Hashable {
    case zsh = "/bin/zsh"
    case bash = "/bin/bash"
    case sh = "/bin/sh"
    
    var displayName: String {
        switch self {
        case .zsh: return "zsh"
        case .bash: return "bash"
        case .sh: return "sh"
        }
    }
}

/// Supported terminal applications
enum TerminalApp: String, CaseIterable, Hashable {
    case terminal = "Terminal"
    case iterm = "iTerm"
    
    var bundleIdentifier: String {
        switch self {
        case .terminal: return "com.apple.Terminal"
        case .iterm: return "com.googlecode.iterm2"
        }
    }
}
