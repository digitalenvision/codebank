import SwiftUI

/// Onboarding/Welcome screen shown on first launch
struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var hasCompletedOnboarding: Bool
    
    @State private var currentPage = 0
    
    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "lock.shield.fill",
            iconColor: .green,
            title: "Your Secure Vault",
            description: "CodeBank keeps your API keys, credentials, and secrets encrypted and protected with your master password."
        ),
        OnboardingPage(
            icon: "faceid",
            iconColor: .blue,
            title: "Biometric Unlock",
            description: "Quickly access your vault with Touch ID or Face ID. Your data stays encrypted and secure."
        ),
        OnboardingPage(
            icon: "folder.fill",
            iconColor: .orange,
            title: "Organize by Project",
            description: "Group your credentials by project. Keep production and development keys separate and organized."
        ),
        OnboardingPage(
            icon: "magnifyingglass",
            iconColor: .purple,
            title: "Quick Search",
            description: "Press ⌘⇧Space anywhere to instantly search and access your credentials."
        ),
        OnboardingPage(
            icon: "terminal.fill",
            iconColor: .gray,
            title: "Run Commands & SSH",
            description: "Store terminal commands and SSH connections. Execute them with a single click."
        )
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                ForEach(pages.indices, id: \.self) { index in
                    pageView(pages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(.automatic)
            
            // Page indicators and buttons
            VStack(spacing: 20) {
                // Page dots
                HStack(spacing: 8) {
                    ForEach(pages.indices, id: \.self) { index in
                        Circle()
                            .fill(index == currentPage ? Color.primary : Color.secondary.opacity(0.3))
                            .frame(width: 8, height: 8)
                    }
                }
                
                // Navigation buttons
                HStack(spacing: 16) {
                    if currentPage > 0 {
                        Button("Back") {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Spacer()
                    
                    if currentPage < pages.count - 1 {
                        Button("Next") {
                            withAnimation {
                                currentPage += 1
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(nsColor: .controlAccentColor))
                    } else {
                        Button("Get Started") {
                            completeOnboarding()
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(nsColor: .controlAccentColor))
                    }
                }
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 40)
        }
        .frame(width: 500, height: 450)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(page.iconColor.opacity(0.15))
                    .frame(width: 100, height: 100)
                
                Image(systemName: page.icon)
                    .font(.system(size: 44))
                    .foregroundStyle(page.iconColor)
            }
            
            // Title
            Text(page.title)
                .font(.title)
                .fontWeight(.bold)
            
            // Description
            Text(page.description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
        .padding()
    }
    
    private func completeOnboarding() {
        hasCompletedOnboarding = true
        dismiss()
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let icon: String
    let iconColor: Color
    let title: String
    let description: String
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
