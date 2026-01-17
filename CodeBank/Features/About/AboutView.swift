import SwiftUI

/// About window view
struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    private var macOSVersion: String {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
    }
    
    var body: some View {
        VStack(spacing: 20) {
            // App icon and name
            VStack(spacing: 16) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                
                CodeBankLogo(size: .large)
                
                Text("Version \(appVersion) (\(buildNumber))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Divider()
            
            // Description
            VStack(spacing: 8) {
                Text("Secure Developer Vault")
                    .font(.headline)
                
                Text("Keep your API keys, credentials, and secrets safe with military-grade encryption.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Divider()
            
            // Credits
            VStack(spacing: 4) {
                Text("© \(Calendar.current.component(.year, from: Date())) Digital Envision")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack(spacing: 16) {
                    Link("Website", destination: URL(string: "https://codebank.app")!)
                        .font(.caption)
                    
                    Link("Support", destination: URL(string: "mailto:support@codebank.app")!)
                        .font(.caption)
                }
            }
            
            // System info
            HStack {
                Text("macOS \(macOSVersion)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(30)
        .frame(width: 320)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

#Preview {
    AboutView()
}
