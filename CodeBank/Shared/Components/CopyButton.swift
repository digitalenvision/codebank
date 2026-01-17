import SwiftUI

/// A button that copies text to clipboard with visual feedback
struct CopyButton: View {
    let text: String
    var label: String = "Copy"
    var isSecret: Bool = false
    var showLabel: Bool = true
    var fieldLabel: String? = nil // For toast notification
    
    var body: some View {
        Button {
            copyToClipboard()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "doc.on.doc")
                    .font(.caption)
                
                if showLabel {
                    Text(label)
                        .font(.caption)
                }
            }
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Copy to clipboard")
    }
    
    private func copyToClipboard() {
        if isSecret {
            ClipboardService.shared.copySecret(text)
        } else {
            ClipboardService.shared.copy(text, autoClear: isSecret)
        }
        
        ToastManager.shared.showCopied(fieldLabel)
    }
}

/// A field row with label, value, and copy button - entire row is clickable to copy
struct CopyableField: View {
    let label: String
    let value: String
    var isSecret: Bool = false
    var isMonospaced: Bool = false
    var isURL: Bool? = nil  // nil = auto-detect
    
    @State private var isRevealed: Bool = false
    @State private var isHovered: Bool = false
    @State private var isAuthenticating: Bool = false
    
    /// Detects if a string is a valid URL
    private var detectedIsURL: Bool {
        if let explicit = isURL { return explicit }
        guard !isSecret else { return false }
        
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.hasPrefix("http://") || 
               trimmed.hasPrefix("https://") ||
               trimmed.hasPrefix("ftp://") ||
               trimmed.hasPrefix("sftp://")
    }
    
    private var url: URL? {
        guard detectedIsURL else { return nil }
        return URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 8) {
                Group {
                    if isSecret && !isRevealed {
                        Text(String(repeating: "•", count: min(value.count, 24)))
                            .foregroundStyle(.primary)
                    } else if detectedIsURL, let url = url {
                        // Clickable URL link
                        Link(destination: url) {
                            HStack(spacing: 4) {
                                Text(value)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Image(systemName: "arrow.up.right")
                                    .font(.caption2)
                            }
                            .foregroundStyle(.primary)
                        }
                        .onHover { hovering in
                            if hovering {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                    } else {
                        Text(value)
                            .foregroundStyle(.primary)
                    }
                }
                .font(isMonospaced ? .system(.body, design: .monospaced) : .body)
                .lineLimit(1)
                .truncationMode(.middle)
                
                Spacer()
                
                // Open URL button (only for URLs)
                if detectedIsURL && !isSecret, let url = url {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Image(systemName: "safari")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Open in browser")
                }
                
                if isSecret {
                    Button {
                        toggleReveal()
                    } label: {
                        if isAuthenticating {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 14, height: 14)
                        } else {
                            Image(systemName: isRevealed ? "eye.slash.fill" : "eye.fill")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .help(isRevealed ? "Hide" : "Reveal (requires authentication)")
                    .disabled(isAuthenticating)
                }
            }
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.3) : Color(nsColor: .controlBackgroundColor))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(isHovered ? Color(nsColor: .separatorColor) : Color.clear, lineWidth: 1)
            }
            .contentShape(Rectangle())
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.12)) {
                    isHovered = hovering
                }
            }
            .onTapGesture {
                copyToClipboard()
            }
        }
        .help(detectedIsURL ? "Click to copy, or click the link to open" : "Click to copy \(label)")
    }
    
    private func copyToClipboard() {
        if isSecret {
            ClipboardService.shared.copySecret(value)
        } else {
            ClipboardService.shared.copy(value, autoClear: isSecret)
        }
        
        ToastManager.shared.showCopied(label)
    }
    
    private func toggleReveal() {
        if isRevealed {
            // Hiding doesn't require authentication
            isRevealed = false
        } else {
            // Revealing requires biometric authentication
            isAuthenticating = true
            
            Task {
                do {
                    let authenticated = try await BiometricService.shared.authenticate(
                        reason: "Authenticate to reveal \(label)"
                    )
                    
                    await MainActor.run {
                        isAuthenticating = false
                        if authenticated {
                            isRevealed = true
                            
                            // Auto-hide after 30 seconds for security
                            Task {
                                try? await Task.sleep(for: .seconds(30))
                                await MainActor.run {
                                    isRevealed = false
                                }
                            }
                        }
                    }
                } catch {
                    await MainActor.run {
                        isAuthenticating = false
                    }
                }
            }
        }
    }
}

/// A compact inline copy button
struct InlineCopyButton: View {
    let text: String
    var isSecret: Bool = false
    var fieldLabel: String? = nil
    
    var body: some View {
        Button {
            if isSecret {
                ClipboardService.shared.copySecret(text)
            } else {
                ClipboardService.shared.copy(text, autoClear: isSecret)
            }
            ToastManager.shared.showCopied(fieldLabel)
        } label: {
            Image(systemName: "doc.on.doc")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .help("Copy to clipboard")
    }
}

#Preview {
    ZStack {
        VStack(spacing: 20) {
            CopyButton(text: "Hello World")
            CopyButton(text: "Secret", isSecret: true)
            
            Divider()
            
            CopyableField(label: "API Key", value: "your_api_key_here", isSecret: true, isMonospaced: true)
            CopyableField(label: "Host", value: "db.example.com", isMonospaced: true)
            CopyableField(label: "Base URL", value: "https://api.stripe.com/v1")
            CopyableField(label: "Webhook URL", value: "https://example.com/webhooks/stripe")
            CopyableField(label: "Dashboard", value: "https://dashboard.stripe.com")
        }
        .padding()
        .frame(width: 400)
        
        ToastOverlay()
    }
}
