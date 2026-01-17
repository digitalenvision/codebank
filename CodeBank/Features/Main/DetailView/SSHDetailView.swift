import SwiftUI

/// Detail content for SSH Connection items
struct SSHDetailContent: View {
    let data: SSHData
    
    @Environment(AppState.self) private var appState
    @State private var sshCommandHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Basic connection info
            HStack(spacing: 16) {
                CopyableField(label: "Host", value: data.host, isMonospaced: true)
                    .frame(maxWidth: .infinity)
                
                CopyableField(label: "Port", value: String(data.port), isMonospaced: true)
                    .frame(width: 100)
            }
            
            CopyableField(label: "Username", value: data.user, isMonospaced: true)
            
            // Authentication
            if let password = data.password, !password.isEmpty {
                CopyableField(label: "Password", value: password, isSecret: true, isMonospaced: true)
            }
            
            if let keyPath = data.identityKeyPath, !keyPath.isEmpty {
                CopyableField(label: "Identity Key", value: keyPath, isMonospaced: true)
            }
            
            if let passphrase = data.passphrase, !passphrase.isEmpty {
                CopyableField(label: "Key Passphrase", value: passphrase, isSecret: true, isMonospaced: true)
            }
            
            // Jump host (bastion)
            if let jumpHost = data.jumpHost, !jumpHost.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                
                HStack(spacing: 16) {
                    CopyableField(label: "Jump Host", value: jumpHost, isMonospaced: true)
                    if let jumpUser = data.jumpUser, !jumpUser.isEmpty {
                        CopyableField(label: "Jump User", value: jumpUser, isMonospaced: true)
                    }
                }
            }
            
            // Port forwarding
            if (data.localPortForward != nil && !data.localPortForward!.isEmpty) ||
               (data.remotePortForward != nil && !data.remotePortForward!.isEmpty) {
                Divider()
                    .padding(.vertical, 4)
                
                if let local = data.localPortForward, !local.isEmpty {
                    CopyableField(label: "Local Port Forward", value: local, isMonospaced: true)
                }
                
                if let remote = data.remotePortForward, !remote.isEmpty {
                    CopyableField(label: "Remote Port Forward", value: remote, isMonospaced: true)
                }
            }
            
            // Custom fields
            if !data.customFields.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                
                ForEach(data.customFields) { field in
                    CopyableField(
                        label: field.name,
                        value: field.value,
                        isSecret: field.isSecret,
                        isMonospaced: field.isSecret
                    )
                }
            }
            
            // SSH Command preview - clickable to copy
            VStack(alignment: .leading, spacing: 4) {
                Text("SSH Command")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Text(data.sshCommand())
                        .font(.system(.body, design: .monospaced))
                        .lineLimit(2)
                        .truncationMode(.middle)
                    
                    Spacer()
                }
                .padding(10)
                .background {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(sshCommandHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.3) : Color(nsColor: .controlBackgroundColor))
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .strokeBorder(sshCommandHovered ? Color(nsColor: .separatorColor) : Color.clear, lineWidth: 1)
                }
                .contentShape(Rectangle())
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.12)) {
                        sshCommandHovered = hovering
                    }
                }
                .onTapGesture {
                    copySSHCommand()
                }
            }
            .help("Click to copy SSH Command")
            
            // Quick connect button
            Button {
                connect()
            } label: {
                Label("Open SSH Connection", systemImage: "terminal.fill")
            }
            .largeSecondaryButtonStyle()
            
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
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        }
                }
            }
        }
    }
    
    private func connect() {
        Task {
            try? await CommandService.shared.openSSH(
                user: data.user,
                host: data.host,
                port: data.port,
                identityKeyPath: data.identityKeyPath
            )
        }
    }
    
    private func copySSHCommand() {
        ClipboardService.shared.copy(data.sshCommand(), autoClear: false)
        ToastManager.shared.showCopied("SSH Command")
    }
}

#Preview {
    ZStack {
        SSHDetailContent(data: SSHData(
            user: "deploy",
            host: "server.example.com",
            port: 22,
            password: "secretpassword123",
            identityKeyPath: "~/.ssh/id_rsa",
            notes: "Production server access"
        ))
        .environment(AppState.shared)
        .padding()
        .frame(width: 400)
        
        ToastOverlay()
    }
}
