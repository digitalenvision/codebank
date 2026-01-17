import SwiftUI

/// Detail content for Server items
struct ServerDetailContent: View {
    let data: ServerData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Hostname and IP
            if let ip = data.ipAddress, !ip.isEmpty {
                HStack(spacing: 16) {
                    CopyableField(label: "Hostname", value: data.hostname, isMonospaced: true)
                    CopyableField(label: "IP Address", value: ip, isMonospaced: true)
                }
            } else {
                CopyableField(label: "Hostname / IP", value: data.hostname, isMonospaced: true)
            }
            
            // Ports
            HStack(spacing: 16) {
                CopyableField(label: "SSH Port", value: String(data.port), isMonospaced: true)
                    .frame(width: 100)
                
                if let httpPort = data.httpPort {
                    CopyableField(label: "HTTP Port", value: String(httpPort), isMonospaced: true)
                        .frame(width: 100)
                }
                
                if let httpsPort = data.httpsPort {
                    CopyableField(label: "HTTPS Port", value: String(httpsPort), isMonospaced: true)
                        .frame(width: 100)
                }
                
                Spacer()
            }
            
            // Credentials
            if !data.username.isEmpty {
                CopyableField(label: "Username", value: data.username, isMonospaced: true)
            }
            
            if let password = data.password, !password.isEmpty {
                CopyableField(label: "Password", value: password, isSecret: true, isMonospaced: true)
            }
            
            if let rootPassword = data.rootPassword, !rootPassword.isEmpty {
                CopyableField(label: "Root Password", value: rootPassword, isSecret: true, isMonospaced: true)
            }
            
            // Admin URL
            if let adminUrl = data.adminUrl, !adminUrl.isEmpty {
                CopyableField(label: "Admin URL", value: adminUrl, isMonospaced: true)
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
            
            // Notes
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
    ServerDetailContent(data: ServerData(
        hostname: "server.example.com",
        ipAddress: "192.168.1.100",
        port: 22,
        httpPort: 80,
        httpsPort: 443,
        username: "admin",
        password: "secret123",
        adminUrl: "https://server.example.com/admin",
        customFields: [
            CredentialField(name: "API Key", value: "your_api_key_here", isSecret: true),
            CredentialField(name: "Monitoring URL", value: "https://monitor.example.com", isSecret: false)
        ],
        notes: "Production web server"
    ))
    .padding()
    .frame(width: 500)
}
