<p align="center">
  <img src="CodeBank/Resources/codebank_logo-dark.svg" alt="CodeBank Logo" width="300">
</p>

<h1 align="center">CodeBank</h1>

<p align="center">
  <strong>A secure, local-only vault for developers to store API keys, credentials, and secrets.</strong>
</p>

<p align="center">
  <a href="#features">Features</a> •
  <a href="#installation">Installation</a> •
  <a href="#building-from-source">Build</a> •
  <a href="#security">Security</a> •
  <a href="#contributing">Contributing</a> •
  <a href="#license">License</a>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Platform-macOS%2013%2B-blue" alt="Platform">
  <img src="https://img.shields.io/badge/Swift-5.9-orange" alt="Swift">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License">
</p>

---

## About

CodeBank is a native macOS application designed for developers who need a secure place to store their sensitive credentials. Unlike cloud-based password managers, CodeBank stores everything **locally on your Mac** with military-grade encryption. No accounts, no subscriptions, no cloud sync – just security.

## Features

### 🔐 Secure Storage
- **API Keys** – Store multiple keys per service (API key, secret key, publishable key, webhooks, etc.)
- **Database Credentials** – PostgreSQL, MySQL, MongoDB, Redis, SQLite, and more
- **SSH Connections** – One-click connect with password, key file, or jump host support
- **Server Details** – Hostnames, IPs, ports, and credentials
- **Shell Commands** – Save and execute frequently used commands
- **Secure Notes** – Encrypted freeform text storage

### 🛡️ Security First
- **AES-256-GCM Encryption** – Military-grade encryption for all stored data
- **PBKDF2-SHA512 Key Derivation** – 600,000 iterations as recommended by OWASP
- **Touch ID / Face ID** – Biometric unlock support
- **Auto-Lock** – Automatically locks after configurable idle time
- **Local-Only** – Your data never leaves your Mac
- **No Telemetry** – Zero analytics, tracking, or network connections

### ⚡ Developer Experience
- **Quick Search** – Global hotkey (⌘⇧Space) to search and access credentials instantly
- **One-Click SSH** – Open SSH connections directly in Terminal or iTerm
- **ENV Import** – Import credentials from `.env` files with intelligent grouping
- **Password Generator** – Generate strong passwords with customizable options
- **Encrypted Backups** – Export and import encrypted vault backups
- **Menu Bar Access** – Quick access from the macOS menu bar

### 🎨 Native macOS Experience
- Built with **SwiftUI** for a modern, native interface
- Supports **Light and Dark mode**
- Keyboard shortcuts throughout
- Follows Apple Human Interface Guidelines

## Installation

### Requirements
- macOS 13.0 (Ventura) or later
- Apple Silicon or Intel Mac

### Download

<p align="center">
  <a href="https://drive.google.com/drive/folders/1-nfPmU6MmDZq6S6IwvQoxhsnN0nfZvh9?usp=sharing">
    <img src="https://img.shields.io/badge/Download-CodeBank-blue?style=for-the-badge&logo=apple" alt="Download CodeBank">
  </a>
</p>

**[⬇️ Download CodeBank](https://drive.google.com/drive/folders/1-nfPmU6MmDZq6S6IwvQoxhsnN0nfZvh9?usp=sharing)** (Google Drive)

1. Download `CodeBank.zip` from the link above
2. Unzip the file
3. Drag `CodeBank.app` to your Applications folder
4. Open CodeBank and create your master password

### Homebrew (Coming Soon)
```bash
brew install --cask codebank
```

## Building from Source

### Prerequisites
- Xcode 15.0 or later
- macOS 13.0 or later

### Steps

1. **Clone the repository**
   ```bash
   git clone https://github.com/digitalenvision/codebank.git
   cd codebank
   ```

2. **Open in Xcode**
   ```bash
   open CodeBank.xcodeproj
   ```

3. **Configure Signing**
   - Select the CodeBank target
   - Go to Signing & Capabilities
   - Select your development team

4. **Build and Run**
   - Press `⌘R` to build and run

### Running Tests
```bash
xcodebuild test -scheme CodeBank -destination 'platform=macOS'
```

## Security

### Encryption Details

| Component | Algorithm | Details |
|-----------|-----------|---------|
| Data Encryption | AES-256-GCM | Authenticated encryption with 256-bit keys |
| Key Derivation | PBKDF2-SHA512 | 600,000 iterations, 16-byte salt |
| Key Storage | macOS Keychain | Hardware-backed secure storage |
| Biometric Auth | LocalAuthentication | Touch ID / Face ID via Secure Enclave |

### Local-Only Guarantee

CodeBank is designed to be **100% offline**. We guarantee:

- ✅ No network connections to external servers
- ✅ No analytics or telemetry
- ✅ No cloud sync or backup to remote servers
- ✅ No account creation or login required
- ✅ All data stored locally in encrypted SQLite database

You can verify this yourself:
1. Check the app's entitlements – no network entitlement
2. Monitor network traffic – the app makes zero connections
3. Review the source code – it's all open source

### Reporting Security Issues

If you discover a security vulnerability, please email [support@codebank.app](mailto:support@codebank.app) instead of creating a public issue. We take security seriously and will respond promptly.

## Project Structure

```
CodeBank/
├── App/                    # App entry point and state management
├── Core/
│   ├── Crypto/            # Encryption and key derivation
│   ├── Models/            # Data models (Item, Project, etc.)
│   └── Services/          # Business logic services
├── Features/
│   ├── About/             # About window
│   ├── Editor/            # Item editor
│   ├── Import/            # ENV file import
│   ├── Main/              # Main window (sidebar, list, detail)
│   ├── MenuBar/           # Menu bar extra
│   ├── Onboarding/        # First-run experience
│   ├── PasswordGenerator/ # Password generator
│   ├── QuickSearch/       # Spotlight-style search
│   ├── Settings/          # Preferences
│   ├── Setup/             # Initial vault setup
│   └── Unlock/            # Lock screen
├── Resources/             # Assets, icons, logos
└── Shared/
    ├── Components/        # Reusable UI components
    ├── Constants/         # App constants
    └── Extensions/        # Swift extensions
```

## Contributing

We welcome contributions! Here's how you can help:

### Ways to Contribute
- 🐛 **Report Bugs** – Open an issue describing the bug
- 💡 **Suggest Features** – Open an issue with your idea
- 📖 **Improve Docs** – Fix typos, add examples, clarify explanations
- 🔧 **Submit PRs** – Fix bugs or implement features

### Development Setup

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes
4. Run tests: `xcodebuild test -scheme CodeBank`
5. Commit your changes: `git commit -m 'Add amazing feature'`
6. Push to the branch: `git push origin feature/amazing-feature`
7. Open a Pull Request

### Code Style
- Follow Swift API Design Guidelines
- Use SwiftLint (configuration included)
- Write tests for new functionality
- Keep commits focused and atomic

## Roadmap

- [ ] iCloud Keychain sync (opt-in)
- [ ] Browser extension for auto-fill
- [ ] SSH agent integration
- [ ] Team sharing (encrypted)
- [ ] Windows & Linux versions
- [ ] CLI tool

## Support

- 📧 Email: [support@codebank.app](mailto:support@codebank.app)
- 🐛 Issues: [GitHub Issues](https://github.com/digitalenvision/codebank/issues)
- 🌐 Website: [codebank.app](https://codebank.app)

## License

CodeBank is open source software licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2026 Digital Envision

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.
```

---

<p align="center">
  Made with ❤️ by <a href="https://digitalenvision.io">Digital Envision</a>
</p>
