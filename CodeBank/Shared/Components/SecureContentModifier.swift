import SwiftUI
import AppKit

/// A view modifier that prevents screenshots of the content
struct SecureContentModifier: ViewModifier {
    @State private var hostingView: NSView?
    
    func body(content: Content) -> some View {
        content
            .background(
                SecureWindowSetter(hostingView: $hostingView)
            )
    }
}

/// Helper view that sets up secure window properties
struct SecureWindowSetter: NSViewRepresentable {
    @Binding var hostingView: NSView?
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            hostingView = view
            configureSecureWindow(for: view)
        }
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureSecureWindow(for: nsView)
        }
    }
    
    private func configureSecureWindow(for view: NSView) {
        guard let window = view.window else { return }
        
        // Set sharing type to none to prevent screenshots
        window.sharingType = .none
    }
}

// MARK: - View Extension

extension View {
    /// Prevents screenshots of this view by setting window sharing type to none
    func preventScreenshots() -> some View {
        modifier(SecureContentModifier())
    }
}

