import SwiftUI

/// A secure text field with toggle to show/hide password
struct SecureTextField: View {
    let title: String
    @Binding var text: String
    var showToggle: Bool = true
    
    @State private var isSecure: Bool = true
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 8) {
            Group {
                if isSecure {
                    SecureField(title, text: $text)
                } else {
                    TextField(title, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .focused($isFocused)
            .font(.system(.body, design: .monospaced))
            
            if showToggle {
                Button {
                    isSecure.toggle()
                } label: {
                    Image(systemName: isSecure ? "eye.slash.fill" : "eye.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 20, height: 20)
                }
                .buttonStyle(.plain)
                .help(isSecure ? "Show password" : "Hide password")
            }
        }
        .padding(10)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(isFocused ? Color(nsColor: .labelColor) : Color(nsColor: .separatorColor), lineWidth: 1)
                }
        }
    }
}

/// A styled text field for non-sensitive input
struct StyledTextField: View {
    let title: String
    @Binding var text: String
    var isMonospaced: Bool = false
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        TextField(title, text: $text)
            .textFieldStyle(.plain)
            .focused($isFocused)
            .font(isMonospaced ? .system(.body, design: .monospaced) : .body)
            .padding(10)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isFocused ? Color(nsColor: .labelColor) : Color(nsColor: .separatorColor), lineWidth: 1)
                    }
            }
    }
}

/// A styled text editor for multiline input
struct StyledTextEditor: View {
    let title: String
    @Binding var text: String
    var isMonospaced: Bool = true
    var minHeight: CGFloat = 100
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !title.isEmpty {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            TextEditor(text: $text)
                .font(isMonospaced ? .system(.body, design: .monospaced) : .body)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .frame(minHeight: minHeight)
                .padding(8)
                .background {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(nsColor: .controlBackgroundColor))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(isFocused ? Color(nsColor: .labelColor) : Color(nsColor: .separatorColor), lineWidth: 1)
                        }
                }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SecureTextField(title: "Password", text: .constant(""))
        StyledTextField(title: "Username", text: .constant(""))
        StyledTextEditor(title: "Notes", text: .constant("Some notes here"))
    }
    .padding()
    .frame(width: 400)
}
