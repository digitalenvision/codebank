import SwiftUI

/// Detail content for Database items
struct DatabaseDetailContent: View {
    let data: DatabaseData
    
    @State private var connectionStringHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Connection info
            HStack(spacing: 16) {
                CopyableField(label: "Host", value: data.host, isMonospaced: true)
                    .frame(maxWidth: .infinity)
                
                CopyableField(label: "Port", value: String(data.port), isMonospaced: true)
                    .frame(width: 100)
            }
            
            CopyableField(label: "Database Name", value: data.databaseName, isMonospaced: true)
            
            HStack(spacing: 16) {
                CopyableField(label: "Username", value: data.username, isMonospaced: true)
                CopyableField(label: "Password", value: data.password, isSecret: true, isMonospaced: true)
            }
            
            if let connectionString = data.connectionString, !connectionString.isEmpty {
                CopyableField(label: "Connection String", value: connectionString, isSecret: true, isMonospaced: true)
            } else {
                // Show generated connection string - clickable to copy
                VStack(alignment: .leading, spacing: 4) {
                    Text("Connection String (Generated)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Text(data.generateConnectionString().masked())
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                    }
                    .padding(10)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(connectionStringHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.3) : Color(nsColor: .controlBackgroundColor))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(connectionStringHovered ? Color(nsColor: .separatorColor) : Color.clear, lineWidth: 1)
                    }
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.12)) {
                            connectionStringHovered = hovering
                        }
                    }
                    .onTapGesture {
                        copyConnectionString()
                    }
                }
                .help("Click to copy Connection String")
            }
            
            // Database type and SSL if specified
            if data.databaseType != nil || data.sslMode != nil {
                HStack(spacing: 16) {
                    if let dbType = data.databaseType, !dbType.isEmpty {
                        CopyableField(label: "Type", value: dbType)
                    }
                    if let ssl = data.sslMode, !ssl.isEmpty {
                        CopyableField(label: "SSL Mode", value: ssl)
                    }
                }
            }
            
            // Custom fields (read replica, admin creds, etc.)
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
    
    private func copyConnectionString() {
        ClipboardService.shared.copySecret(data.generateConnectionString())
        ToastManager.shared.showCopied("Connection String")
    }
}

#Preview {
    ZStack {
        DatabaseDetailContent(data: DatabaseData(
            host: "db.example.com",
            port: 5432,
            username: "app_user",
            password: "secret_password",
            databaseName: "production_db",
            notes: "Main production database"
        ))
        .padding()
        .frame(width: 500)
        
        ToastOverlay()
    }
}
