import SwiftUI

/// Password generator sheet view
struct PasswordGeneratorView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var password = ""
    @State private var length: Double = 20
    @State private var includeUppercase = true
    @State private var includeLowercase = true
    @State private var includeNumbers = true
    @State private var includeSymbols = true
    @State private var excludeAmbiguous = true
    @State private var copied = false
    
    private let minLength: Double = 8
    private let maxLength: Double = 64
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Password Generator")
                    .font(.headline)
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            
            Divider()
            
            ScrollView {
                VStack(spacing: 20) {
                    // Generated password display
                    passwordDisplay
                    
                    Divider()
                    
                    // Options
                    optionsSection
                }
                .padding()
            }
            
            Divider()
            
            // Actions
            HStack {
                Button("Close") {
                    dismiss()
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button {
                    copyPassword()
                } label: {
                    Label(copied ? "Copied!" : "Copy Password", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .keyboardShortcut("c", modifiers: [.command])
                .disabled(password.isEmpty)
            }
            .padding()
        }
        .frame(width: 400, height: 500)
        .onAppear {
            generatePassword()
        }
    }
    
    // MARK: - Password Display
    
    private var passwordDisplay: some View {
        VStack(spacing: 12) {
            // Password text with monospace font
            Text(password)
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .textSelection(.enabled)
                .padding()
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
                )
            
            // Password strength indicator
            PasswordStrengthIndicator(password: password)
            
            // Regenerate button
            Button {
                generatePassword()
            } label: {
                Label("Generate New", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - Options Section
    
    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Length slider
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Length")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(length)) characters")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                Slider(value: $length, in: minLength...maxLength, step: 1) {
                    Text("Length")
                } onEditingChanged: { _ in
                    generatePassword()
                }
            }
            
            Divider()
            
            // Character options
            VStack(alignment: .leading, spacing: 12) {
                Text("Characters")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Toggle("Uppercase (A-Z)", isOn: $includeUppercase)
                    .onChange(of: includeUppercase) { _, _ in generatePassword() }
                
                Toggle("Lowercase (a-z)", isOn: $includeLowercase)
                    .onChange(of: includeLowercase) { _, _ in generatePassword() }
                
                Toggle("Numbers (0-9)", isOn: $includeNumbers)
                    .onChange(of: includeNumbers) { _, _ in generatePassword() }
                
                Toggle("Symbols (!@#$%)", isOn: $includeSymbols)
                    .onChange(of: includeSymbols) { _, _ in generatePassword() }
            }
            
            Divider()
            
            // Additional options
            VStack(alignment: .leading, spacing: 12) {
                Text("Options")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                
                Toggle("Exclude ambiguous characters (0, O, l, 1)", isOn: $excludeAmbiguous)
                    .onChange(of: excludeAmbiguous) { _, _ in generatePassword() }
            }
        }
    }
    
    // MARK: - Password Generation
    
    private func generatePassword() {
        var charset = ""
        
        if includeUppercase {
            charset += excludeAmbiguous ? "ABCDEFGHJKLMNPQRSTUVWXYZ" : "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        }
        if includeLowercase {
            charset += excludeAmbiguous ? "abcdefghjkmnpqrstuvwxyz" : "abcdefghijklmnopqrstuvwxyz"
        }
        if includeNumbers {
            charset += excludeAmbiguous ? "23456789" : "0123456789"
        }
        if includeSymbols {
            charset += "!@#$%^&*()-_=+[]{}|;:,.<>?"
        }
        
        guard !charset.isEmpty else {
            password = ""
            return
        }
        
        let charsetArray = Array(charset)
        var newPassword = ""
        
        for _ in 0..<Int(length) {
            let randomIndex = Int.random(in: 0..<charsetArray.count)
            newPassword.append(charsetArray[randomIndex])
        }
        
        password = newPassword
        copied = false
    }
    
    private func copyPassword() {
        ClipboardService.shared.copySecret(password)
        copied = true
        ToastManager.shared.showCopied("Password")
        
        // Reset copied state after 2 seconds
        Task {
            try? await Task.sleep(for: .seconds(2))
            copied = false
        }
    }
}

// MARK: - Password Strength Indicator

struct PasswordStrengthIndicator: View {
    let password: String
    
    private var strength: PasswordStrength {
        calculateStrength()
    }
    
    var body: some View {
        HStack(spacing: 8) {
            // Strength bars
            ForEach(0..<4, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(index < strength.level ? strength.color : Color(nsColor: .separatorColor))
                    .frame(height: 4)
            }
            
            Text(strength.label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
    
    private func calculateStrength() -> PasswordStrength {
        guard !password.isEmpty else { return .weak }
        
        var score = 0
        
        // Length score
        if password.count >= 12 { score += 1 }
        if password.count >= 16 { score += 1 }
        if password.count >= 20 { score += 1 }
        
        // Character variety
        let hasUpper = password.contains(where: { $0.isUppercase })
        let hasLower = password.contains(where: { $0.isLowercase })
        let hasNumber = password.contains(where: { $0.isNumber })
        let hasSymbol = password.contains(where: { !$0.isLetter && !$0.isNumber })
        
        let varietyCount = [hasUpper, hasLower, hasNumber, hasSymbol].filter { $0 }.count
        score += varietyCount - 1
        
        switch score {
        case 0...1: return .weak
        case 2...3: return .fair
        case 4...5: return .strong
        default: return .veryStrong
        }
    }
    
    enum PasswordStrength {
        case weak, fair, strong, veryStrong
        
        var level: Int {
            switch self {
            case .weak: return 1
            case .fair: return 2
            case .strong: return 3
            case .veryStrong: return 4
            }
        }
        
        var label: String {
            switch self {
            case .weak: return "Weak"
            case .fair: return "Fair"
            case .strong: return "Strong"
            case .veryStrong: return "Very Strong"
            }
        }
        
        var color: Color {
            switch self {
            case .weak: return .red
            case .fair: return .orange
            case .strong: return .yellow
            case .veryStrong: return .green
            }
        }
    }
}

#Preview {
    PasswordGeneratorView()
}
