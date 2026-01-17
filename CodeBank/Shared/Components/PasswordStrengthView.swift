import SwiftUI

/// Displays password strength indicator
struct PasswordStrengthView: View {
    let strength: KeyDerivation.PasswordStrength
    
    var body: some View {
        HStack(spacing: 12) {
            Text("Strength:")
                .font(.caption)
                .foregroundStyle(.secondary)
            
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(index <= strength.rawValue ? strengthColor : Color(nsColor: .separatorColor))
                        .frame(width: 24, height: 6)
                }
            }
            
            Text(strength.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(strengthColor)
        }
    }
    
    private var strengthColor: Color {
        switch strength {
        case .weak: return .red
        case .fair: return .orange
        case .good: return .yellow
        case .strong: return .green
        case .veryStrong: return .blue
        }
    }
}

/// Password requirements checklist
struct PasswordRequirementsView: View {
    let password: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            RequirementRow(
                text: "At least 8 characters",
                isMet: password.count >= 8
            )
            RequirementRow(
                text: "Contains uppercase letter",
                isMet: password.contains(where: { $0.isUppercase })
            )
            RequirementRow(
                text: "Contains lowercase letter",
                isMet: password.contains(where: { $0.isLowercase })
            )
            RequirementRow(
                text: "Contains number",
                isMet: password.contains(where: { $0.isNumber })
            )
            RequirementRow(
                text: "Contains special character",
                isMet: password.contains(where: { !$0.isLetter && !$0.isNumber })
            )
        }
    }
}

private struct RequirementRow: View {
    let text: String
    let isMet: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: isMet ? "checkmark.circle.fill" : "circle")
                .font(.caption)
                .foregroundStyle(isMet ? .green : .secondary)
            
            Text(text)
                .font(.caption)
                .foregroundStyle(isMet ? .primary : .secondary)
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        PasswordStrengthView(strength: .weak)
        PasswordStrengthView(strength: .fair)
        PasswordStrengthView(strength: .good)
        PasswordStrengthView(strength: .strong)
        PasswordStrengthView(strength: .veryStrong)
        
        Divider()
        
        PasswordRequirementsView(password: "Test123!")
    }
    .padding()
}
