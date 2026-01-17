import SwiftUI

/// Detail content for Command items
struct CommandDetailContent: View {
    let data: CommandData
    let item: Item
    
    @Environment(AppState.self) private var appState
    @State private var showingConfirmation = false
    @State private var commandHovered = false
    @State private var fullCommandHovered = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Command with syntax highlighting - clickable to copy
            VStack(alignment: .leading, spacing: 4) {
                Text("Command")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                SyntaxHighlightedText(code: data.command, language: "bash")
                    .padding(12)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(commandHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.3) : Color(nsColor: .textBackgroundColor))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(commandHovered ? Color(nsColor: .separatorColor) : Color.clear, lineWidth: 1)
                    }
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.12)) {
                            commandHovered = hovering
                        }
                    }
                    .onTapGesture {
                        copyCommand()
                    }
            }
            .help("Click to copy Command")
            
            // Shell and working directory
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shell")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Text(ShellType(rawValue: data.shell)?.displayName ?? data.shell)
                        .font(.system(.body, design: .monospaced))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        }
                }
                
                if let workDir = data.workingDirectory, !workDir.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Working Directory")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(workDir)
                            .font(.system(.body, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(nsColor: .controlBackgroundColor))
                            }
                    }
                }
            }
            
            // Environment variables
            if !data.environmentVariables.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Environment Variables")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    ForEach(data.environmentVariables) { envVar in
                        CopyableField(
                            label: envVar.name,
                            value: envVar.value,
                            isSecret: envVar.isSecret,
                            isMonospaced: true
                        )
                    }
                }
            }
            
            // Custom fields (related commands, scripts, etc.)
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
            
            // Flags
            HStack(spacing: 16) {
                if data.isDangerous {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text("Dangerous Command")
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.orange.opacity(0.15))
                    }
                }
                
                if data.requiresConfirmation {
                    HStack(spacing: 6) {
                        Image(systemName: "hand.raised.fill")
                            .foregroundStyle(.secondary)
                        Text("Requires Confirmation")
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .separatorColor).opacity(0.5))
                    }
                }
            }
            
            // Execute button
            Button {
                if data.requiresConfirmation || data.isDangerous {
                    showingConfirmation = true
                } else {
                    execute()
                }
            } label: {
                Label("Run Command", systemImage: "play.fill")
            }
            .largeSecondaryButtonStyle()
            .confirmationDialog(
                "Run Command?",
                isPresented: $showingConfirmation,
                titleVisibility: .visible
            ) {
                Button("Run", role: data.isDangerous ? .destructive : nil) {
                    execute()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if data.isDangerous {
                    Text("This command is marked as dangerous. Are you sure you want to run it?")
                } else {
                    Text("Do you want to run this command in Terminal?")
                }
            }
            
            // Preview full command - clickable to copy
            if let workDir = data.workingDirectory, !workDir.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Full Command (with cd)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        Text(data.fullCommand())
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                        
                        Spacer()
                    }
                    .padding(10)
                    .background {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(fullCommandHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.3) : Color(nsColor: .controlBackgroundColor))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(fullCommandHovered ? Color(nsColor: .separatorColor) : Color.clear, lineWidth: 1)
                    }
                    .contentShape(Rectangle())
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.12)) {
                            fullCommandHovered = hovering
                        }
                    }
                    .onTapGesture {
                        copyFullCommand()
                    }
                }
                .help("Click to copy Full Command")
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
    
    private func execute() {
        Task {
            try? await appState.executeItem(item)
        }
    }
    
    private func copyCommand() {
        ClipboardService.shared.copy(data.command, autoClear: false)
        ToastManager.shared.showCopied("Command")
    }
    
    private func copyFullCommand() {
        ClipboardService.shared.copy(data.fullCommand(), autoClear: false)
        ToastManager.shared.showCopied("Full Command")
    }
}

#Preview {
    ZStack {
        CommandDetailContent(
            data: CommandData(
                command: "git pull origin main && docker-compose up -d --build",
                shell: ShellType.zsh.rawValue,
                workingDirectory: "~/projects/backend",
                requiresConfirmation: true,
                isDangerous: true,
                notes: "Deploys the latest code to production"
            ),
            item: Item.sampleCommand
        )
        .environment(AppState.shared)
        .padding()
        .frame(width: 500)
        
        ToastOverlay()
    }
}
