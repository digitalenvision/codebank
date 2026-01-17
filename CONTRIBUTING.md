# Contributing to CodeBank

First off, thank you for considering contributing to CodeBank! It's people like you that make CodeBank such a great tool for developers.

## Code of Conduct

By participating in this project, you agree to abide by our Code of Conduct. Please be respectful and constructive in all interactions.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check existing issues to avoid duplicates. When you create a bug report, include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Describe the behavior you observed and what you expected**
- **Include your macOS version and CodeBank version**
- **Include screenshots if applicable**

### Suggesting Features

Feature suggestions are welcome! Please:

- **Use a clear and descriptive title**
- **Provide a detailed description of the suggested feature**
- **Explain why this feature would be useful**
- **List any alternatives you've considered**

### Pull Requests

1. **Fork the repo** and create your branch from `main`
2. **Follow the coding style** of the project
3. **Write tests** for any new functionality
4. **Ensure tests pass** before submitting
5. **Write a clear PR description** explaining the changes

## Development Setup

### Prerequisites

- macOS 13.0 or later
- Xcode 15.0 or later
- Git

### Getting Started

```bash
# Clone your fork
git clone https://github.com/YOUR_USERNAME/codebank.git
cd codebank

# Open in Xcode
open CodeBank.xcodeproj

# Build and run
# Press ⌘R in Xcode
```

### Project Structure

```
CodeBank/
├── App/                    # App entry point and state
├── Core/                   # Core business logic
│   ├── Crypto/            # Encryption services
│   ├── Models/            # Data models
│   └── Services/          # Business services
├── Features/              # Feature modules (MVVM)
├── Resources/             # Assets and resources
└── Shared/                # Shared components
```

### Coding Guidelines

#### Swift Style

- Follow [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- Use meaningful variable and function names
- Keep functions focused and small
- Use `// MARK:` comments to organize code sections

#### SwiftUI Best Practices

- Extract reusable views into components
- Use `@State` for view-local state
- Use `@Observable` for shared state
- Prefer composition over inheritance

#### Security Guidelines

- Never log sensitive data
- Use `SecureField` for password inputs
- Clear sensitive data from memory when done
- Follow the principle of least privilege

### Running Tests

```bash
# Run all tests
xcodebuild test -scheme CodeBank -destination 'platform=macOS'

# Run specific test class
xcodebuild test -scheme CodeBank -destination 'platform=macOS' -only-testing:CodeBankTests/CryptoTests
```

### Commit Messages

Use clear, descriptive commit messages:

```
feat: Add password strength indicator
fix: Resolve Touch ID double-prompt issue
docs: Update README with build instructions
refactor: Extract CopyableField component
test: Add encryption round-trip tests
```

Prefixes:
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `refactor:` Code refactoring
- `test:` Adding or updating tests
- `chore:` Maintenance tasks

## Review Process

1. All PRs require at least one review
2. CI must pass before merging
3. Keep PRs focused and reasonably sized
4. Respond to feedback promptly

## Security

If you discover a security vulnerability, please do NOT open a public issue. Instead, email [support@codebank.app](mailto:support@codebank.app) with details.

## Questions?

Feel free to open an issue for any questions about contributing!

---

Thank you for contributing! 🎉
