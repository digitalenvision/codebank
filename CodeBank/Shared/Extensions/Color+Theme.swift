import SwiftUI

extension Color {
    /// Primary theme accent color - neutral grey for monochrome UI
    static var themeAccent: Color {
        Color(nsColor: .labelColor)
    }
    
    /// Hover/focus highlight color - subtle grey
    static var hoverHighlight: Color {
        Color(nsColor: .separatorColor)
    }
    
    /// Background colors
    static var primaryBackground: Color {
        Color(nsColor: .windowBackgroundColor)
    }
    
    static var secondaryBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }
    
    static var tertiaryBackground: Color {
        Color(nsColor: .textBackgroundColor)
    }
    
    /// Separator color
    static var separator: Color {
        Color(nsColor: .separatorColor)
    }
    
    /// Text colors
    static var primaryText: Color {
        Color(nsColor: .labelColor)
    }
    
    static var secondaryText: Color {
        Color(nsColor: .secondaryLabelColor)
    }
    
    static var tertiaryText: Color {
        Color(nsColor: .tertiaryLabelColor)
    }
    
    /// Item type colors
    static var apiKeyColor: Color { .orange }
    static var databaseColor: Color { .purple }
    static var serverColor: Color { .blue }
    static var sshColor: Color { .green }
    static var commandColor: Color { .red }
    static var secureNoteColor: Color { .gray }
    
    /// Danger/warning colors
    static var danger: Color { .red }
    static var warning: Color { .orange }
    static var success: Color { .green }
}

// MARK: - View Modifiers

extension View {
    /// Applies a card-like background style
    func cardStyle() -> some View {
        self
            .padding()
            .background {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondaryBackground)
            }
    }
    
    /// Applies a subtle hover effect
    func hoverEffect() -> some View {
        self.modifier(HoverEffectModifier())
    }
}

private struct HoverEffectModifier: ViewModifier {
    @State private var isHovered = false
    
    func body(content: Content) -> some View {
        content
            .background {
                if isHovered {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(nsColor: .selectedContentBackgroundColor).opacity(0.5))
                }
            }
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - Gradient Presets

extension LinearGradient {
    /// Vault icon gradient - monochrome
    static var vaultGradient: LinearGradient {
        LinearGradient(
            colors: [Color(nsColor: .labelColor), Color(nsColor: .secondaryLabelColor)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Security shield gradient - monochrome
    static var securityGradient: LinearGradient {
        LinearGradient(
            colors: [Color(nsColor: .labelColor), Color(nsColor: .tertiaryLabelColor)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
