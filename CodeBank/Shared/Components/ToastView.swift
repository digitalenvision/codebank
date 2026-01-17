import SwiftUI

/// Toast notification manager - singleton for app-wide notifications
@Observable
final class ToastManager {
    static let shared = ToastManager()
    
    var currentToast: Toast?
    
    private init() {}
    
    func show(_ message: String, icon: String = "checkmark.circle.fill") {
        withAnimation(.easeOut(duration: 0.2)) {
            currentToast = Toast(message: message, icon: icon)
        }
        
        // Auto-dismiss after 2 seconds
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeIn(duration: 0.2)) {
                currentToast = nil
            }
        }
    }
    
    func showCopied(_ label: String? = nil) {
        if let label = label {
            show("\(label) copied", icon: "doc.on.doc.fill")
        } else {
            show("Copied to clipboard", icon: "doc.on.doc.fill")
        }
    }
}

struct Toast: Identifiable, Equatable {
    let id = UUID()
    let message: String
    let icon: String
}

/// Toast overlay view - add to the root of your app
struct ToastOverlay: View {
    @State private var toastManager = ToastManager.shared
    
    var body: some View {
        VStack {
            Spacer()
            
            if let toast = toastManager.currentToast {
                ToastView(toast: toast)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 24)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: toastManager.currentToast)
    }
}

/// Individual toast view
struct ToastView: View {
    let toast: Toast
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: toast.icon)
                .font(.system(size: 14, weight: .medium))
            
            Text(toast.message)
                .font(.system(size: 13, weight: .medium))
        }
        .foregroundStyle(colorScheme == .dark ? .black : .white)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background {
            Capsule()
                .fill(colorScheme == .dark ? Color.white : Color.black)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
    }
}

#Preview {
    ZStack {
        Color(nsColor: .windowBackgroundColor)
        
        VStack {
            Button("Show Toast") {
                ToastManager.shared.showCopied("API Key")
            }
        }
        
        ToastOverlay()
    }
    .frame(width: 400, height: 300)
}
