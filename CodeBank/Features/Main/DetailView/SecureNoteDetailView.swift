import SwiftUI

/// Detail content for Secure Note items
struct SecureNoteDetailContent: View {
    let data: SecureNoteData
    
    @State private var isRevealed = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Secure Content")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Button {
                        isRevealed.toggle()
                    } label: {
                        Label(isRevealed ? "Hide" : "Reveal", systemImage: isRevealed ? "eye.slash.fill" : "eye.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    
                    CopyButton(text: data.content, isSecret: true, showLabel: true)
                }
                
                Group {
                    if isRevealed {
                        Text(data.content)
                            .textSelection(.enabled)
                    } else {
                        Text(String(repeating: "•", count: min(data.content.count, 100)))
                    }
                }
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .textBackgroundColor))
                }
            }
            
            if let notes = data.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(notes)
                        .font(.body)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        }
                }
            }
        }
    }
}

#Preview {
    SecureNoteDetailContent(data: SecureNoteData(
        content: "This is a secure note with sensitive information that should be protected.",
        notes: "Personal encryption keys backup"
    ))
    .padding()
    .frame(width: 400)
}
