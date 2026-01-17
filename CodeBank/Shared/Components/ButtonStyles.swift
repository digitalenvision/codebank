import SwiftUI

// MARK: - App-wide Button Styles

/// Primary action button - filled background with proper contrast
struct PrimaryButtonStyle: ButtonStyle {
    var isDestructive: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(isDestructive ? .white : (colorScheme == .dark ? .black : .white))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isDestructive ? Color.orange : (colorScheme == .dark ? Color.white : Color.black))
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            }
    }
}

/// Secondary action button - bordered grey
struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color(nsColor: .labelColor))
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .opacity(configuration.isPressed ? 0.7 : 1.0)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            }
    }
}

/// Large primary button - for main actions with proper contrast
struct LargePrimaryButtonStyle: ButtonStyle {
    var isDestructive: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isDestructive ? .white : (colorScheme == .dark ? .black : .white))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isDestructive ? Color.orange : (colorScheme == .dark ? Color.white : Color.black))
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            }
    }
}

/// Large secondary button - grey bordered, full width
struct LargeSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Color(nsColor: .labelColor))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .opacity(configuration.isPressed ? 0.7 : 1.0)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1)
            }
    }
}

/// Ghost button - minimal styling, for inline actions
struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color(nsColor: .labelColor))
            .opacity(configuration.isPressed ? 0.6 : 1.0)
    }
}

/// Icon button - for toolbar-style buttons
struct IconButtonStyle: ButtonStyle {
    @State private var isHovered = false
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13))
            .foregroundStyle(Color(nsColor: .labelColor))
            .padding(6)
            .background {
                RoundedRectangle(cornerRadius: 6)
                    .fill(isHovered || configuration.isPressed ? Color(nsColor: .separatorColor).opacity(0.5) : Color.clear)
            }
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

// MARK: - View Extensions

extension View {
    func primaryButtonStyle(isDestructive: Bool = false) -> some View {
        self.buttonStyle(PrimaryButtonStyle(isDestructive: isDestructive))
    }
    
    func secondaryButtonStyle() -> some View {
        self.buttonStyle(SecondaryButtonStyle())
    }
    
    func largePrimaryButtonStyle(isDestructive: Bool = false) -> some View {
        self.buttonStyle(LargePrimaryButtonStyle(isDestructive: isDestructive))
    }
    
    func largeSecondaryButtonStyle() -> some View {
        self.buttonStyle(LargeSecondaryButtonStyle())
    }
    
    func ghostButtonStyle() -> some View {
        self.buttonStyle(GhostButtonStyle())
    }
    
    func iconButtonStyle() -> some View {
        self.buttonStyle(IconButtonStyle())
    }
}

#Preview {
    VStack(spacing: 16) {
        Button("Primary Button") {}
            .primaryButtonStyle()
        
        Button("Destructive") {}
            .primaryButtonStyle(isDestructive: true)
        
        Button("Secondary Button") {}
            .secondaryButtonStyle()
        
        Button {
        } label: {
            Label("Large Primary", systemImage: "play.fill")
        }
        .largePrimaryButtonStyle()
        
        Button("Ghost Button") {}
            .ghostButtonStyle()
        
        Button {
        } label: {
            Image(systemName: "gear")
        }
        .iconButtonStyle()
    }
    .padding()
    .frame(width: 300)
}
