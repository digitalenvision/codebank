import Foundation
import SwiftUI

/// Application-wide constants
enum Constants {
    /// App metadata
    enum App {
        static let name = "CodeBank"
        static let bundleIdentifier = "com.digitalenvision.codebank"
        static let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        static let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        static let exportFileExtension = "codebank"
        static let exportSchemaVersion = "1.0"
    }
    
    /// Security settings
    enum Security {
        /// Default clipboard auto-clear timeout in seconds
        static let defaultClipboardTimeout: TimeInterval = 30
        
        /// Available clipboard timeout options
        static let clipboardTimeoutOptions: [TimeInterval] = [10, 30, 60, 120, 0] // 0 = never
        
        /// Default auto-lock timeout in minutes
        static let defaultAutoLockTimeout: TimeInterval = 5 * 60 // 5 minutes
        
        /// Available auto-lock timeout options (in seconds)
        static let autoLockTimeoutOptions: [TimeInterval] = [60, 300, 600, 900, 1800, 0] // 0 = never
        
        /// Minimum password length
        static let minimumPasswordLength = 8
        
        /// PBKDF2 parameters
        /// Using SHA-512 with 600,000 iterations as recommended by OWASP 2023
        enum PBKDF2 {
            static let iterations: Int = 600_000
            static let saltLength = 16
            static let keyLength: UInt32 = 32 // 256 bits
        }
    }
    
    /// Keychain keys
    enum Keychain {
        static let serviceName = "com.digitalenvision.codebank"
        static let encryptionKeyAccount = "vault-encryption-key"
        static let saltAccount = "vault-salt"
        static let biometricKeyAccount = "vault-biometric-key"
    }
    
    /// User defaults keys
    enum UserDefaults {
        static let vaultCreated = "vault_created"
        static let biometricsEnabled = "biometrics_enabled"
        static let clipboardTimeout = "clipboard_timeout"
        static let autoLockTimeout = "auto_lock_timeout"
        static let lastUnlockDate = "last_unlock_date"
        static let preferredTerminal = "preferred_terminal"
        static let showMenuBarIcon = "show_menu_bar_icon"
    }
    
    /// Database
    enum Database {
        static let fileName = "codebank.db"
        static let schemaVersion = 1
    }
    
    /// Global hotkey
    enum Hotkey {
        static let quickSearchModifiers: NSEvent.ModifierFlags = [.command, .shift]
        static let quickSearchKeyCode: UInt16 = 49 // Space
    }
    
    /// UI dimensions
    enum UI {
        static let mainWindowMinWidth: CGFloat = 900
        static let mainWindowMinHeight: CGFloat = 600
        static let sidebarMinWidth: CGFloat = 200
        static let sidebarMaxWidth: CGFloat = 300
        static let listMinWidth: CGFloat = 250
        static let detailMinWidth: CGFloat = 350
        
        static let quickSearchWidth: CGFloat = 600
        static let quickSearchMaxHeight: CGFloat = 400
    }
    
}
