import SwiftUI

/// A row in the quick search results
struct QuickSearchResultRow: View {
    let result: SearchResult
    let isSelected: Bool
    var onSelect: () -> Void
    var onExecute: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 12) {
                // Icon
                Image(systemName: result.item.icon)
                    .font(.title3)
                    .foregroundStyle(result.item.color)
                    .frame(width: 28)
                
                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(result.item.name)
                        .font(.body)
                        .fontWeight(isSelected ? .medium : .regular)
                        .lineLimit(1)
                    
                    HStack(spacing: 6) {
                        // Item type badge
                        Text(result.item.type.displayName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        // Project name (if assigned)
                        if let project = result.project {
                            Text("in")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            
                            HStack(spacing: 3) {
                                Image(systemName: project.icon)
                                    .font(.system(size: 9))
                                Text(project.name)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                
                Spacer()
                
                // Actions (shown on hover or selection)
                if isSelected || isHovered {
                    HStack(spacing: 4) {
                        if result.item.isExecutable {
                            actionButton(
                                icon: result.item.type == .ssh ? "terminal" : "play.fill",
                                label: result.item.type == .ssh ? "Connect" : "Run",
                                shortcut: "⌘⏎",
                                action: onExecute
                            )
                        }
                        
                        // Show Enter hint for opening
                        Text("↵ Open")
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color(nsColor: .separatorColor).opacity(0.5) : (isHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.3) : Color.clear))
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
    }
    
    @ViewBuilder
    private func actionButton(icon: String, label: String, shortcut: String, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.caption2)
                
                Text(shortcut)
                    .font(.system(size: 9))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background {
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(nsColor: .separatorColor).opacity(0.3))
            }
        }
        .buttonStyle(.plain)
        .help(label)
    }
}

#Preview {
    VStack(spacing: 4) {
        QuickSearchResultRow(
            result: SearchResult(item: Item.sampleAPIKey, project: Project.sample),
            isSelected: true,
            onSelect: {},
            onExecute: {}
        )
        
        QuickSearchResultRow(
            result: SearchResult(item: Item.sampleSSH, project: nil),
            isSelected: false,
            onSelect: {},
            onExecute: {}
        )
    }
    .padding()
    .frame(width: 500)
}
