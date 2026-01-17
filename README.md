# CodeBank

A native macOS developer vault application for securely storing API keys, database credentials, server details, SSH connections, commands, and secure notes.

## Features

- **Secure Local Storage**: All data is encrypted at rest using AES-256-GCM
- **Master Password Protection**: Vault protected with PBKDF2-SHA512 key derivation
- **Biometric Unlock**: Support for Touch ID and Face ID
- **Global Quick Search**: Press `⌘⇧Space` to quickly find and access items
- **Command Execution**: Run saved commands directly in Terminal
- **SSH Connections**: One-click SSH session opening
- **Import/Export**: Encrypted backups with versioned schema
- **Auto-Lock**: Configurable auto-lock on idle and system sleep

## Requirements

- macOS 14.0 (Sonoma) or later
- Xcode 15.0 or later
- Swift 5.9 or later

## Building

1. Open `CodeBank.xcodeproj` in Xcode
2. Wait for Swift Package Manager to resolve dependencies
3. Select your development team in Signing & Capabilities
4. Build and run (⌘R)

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| [SQLite.swift](https://github.com/stephencelis/SQLite.swift) | 0.15.0+ | SQLite database wrapper |
| [swift-crypto](https://github.com/apple/swift-crypto) | 3.0.0+ | AES-GCM encryption |
| [Highlightr](https://github.com/raspu/Highlightr) | 2.1.0+ | Syntax highlighting |

**Note:** Key derivation uses PBKDF2-SHA512 via CommonCrypto (built into macOS).

## Project Structure

```
CodeBank/
├── App/                    # App entry point and state
├── Features/
│   ├── Setup/             # First-run setup wizard
│   ├── Unlock/            # Vault unlock screen
│   ├── Main/              # Main window views
│   ├── QuickSearch/       # Global quick search panel
│   ├── Editor/            # Item editor and syntax highlighting
│   └── Settings/          # App settings
├── Core/
│   ├── Models/            # Domain models
│   ├── Services/          # Business logic services
│   └── Crypto/            # Encryption utilities
├── Shared/
│   ├── Components/        # Reusable UI components
│   └── Extensions/        # Swift extensions
└── Resources/             # Assets and localization
```

## Security Architecture

### Encryption
- **Algorithm**: AES-256-GCM (authenticated encryption)
- **Key Derivation**: PBKDF2-SHA512 with 600,000 iterations (OWASP 2023 recommendation)
- **Key Storage**: Derived key stored in Keychain with biometric protection

### Data Protection
- All item data encrypted at field level before storage
- Master password never stored, only used for key derivation
- Clipboard auto-clear with configurable timeout
- Auto-lock on idle, sleep, and screen saver

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘⇧Space | Open Quick Search |
| ⌘⇧L | Lock Vault |
| ⌘1-6 | Create new item of type |
| ⌘N | New Project |

## Item Types

1. **API Key**: Store API keys with service and environment info
2. **Database**: Store database credentials with auto-generated connection strings
3. **Server**: Store server hostnames and access details
4. **SSH Connection**: One-click SSH session opening
5. **Command**: Stored commands with syntax highlighting and terminal execution
6. **Secure Note**: Free-form encrypted notes

## License

Copyright © 2026 Digital Envision. All rights reserved.

## Contributing

This is a private project. Please contact Digital Envision for contribution guidelines.
