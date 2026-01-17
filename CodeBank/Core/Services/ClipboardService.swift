import Foundation
import AppKit

/// User defaults keys for clipboard settings
private enum ClipboardKeys {
    static let timeout = "clipboard_timeout"
}

/// Default clipboard timeout in seconds
private let defaultClipboardTimeout: TimeInterval = 30

/// Available clipboard timeout options
private let clipboardTimeoutOptions: [TimeInterval] = [10, 30, 60, 120, 0]

/// Handles clipboard operations with automatic clearing for security
@MainActor
final class ClipboardService {
    
    // MARK: - Singleton
    
    static let shared = ClipboardService()
    
    // MARK: - Properties
    
    private var clearTimer: Timer?
    private var lastCopiedChangeCount: Int = 0
    
    /// The current clipboard timeout setting
    var timeout: TimeInterval {
        get {
            let stored = UserDefaults.standard.double(forKey: ClipboardKeys.timeout)
            return stored > 0 ? stored : defaultClipboardTimeout
        }
        set {
            UserDefaults.standard.set(newValue, forKey: ClipboardKeys.timeout)
        }
    }
    
    // MARK: - Initialization
    
    private init() {
        // Set default timeout if not set
        if UserDefaults.standard.object(forKey: ClipboardKeys.timeout) == nil {
            UserDefaults.standard.set(defaultClipboardTimeout, forKey: ClipboardKeys.timeout)
        }
    }
    
    // MARK: - Copy Operations
    
    /// Copies a string to the clipboard with optional auto-clear
    /// - Parameters:
    ///   - string: The string to copy
    ///   - autoClear: Whether to automatically clear after the timeout (default: true)
    func copy(_ string: String, autoClear: Bool = true) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
        
        // Store the change count to verify later
        lastCopiedChangeCount = pasteboard.changeCount
        
        // Schedule auto-clear if enabled
        if autoClear && timeout > 0 {
            scheduleClear()
        }
    }
    
    /// Copies data to the clipboard as a specific type
    /// - Parameters:
    ///   - data: The data to copy
    ///   - type: The pasteboard type
    ///   - autoClear: Whether to automatically clear after the timeout
    func copy(_ data: Data, as type: NSPasteboard.PasteboardType, autoClear: Bool = true) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setData(data, forType: type)
        
        lastCopiedChangeCount = pasteboard.changeCount
        
        if autoClear && timeout > 0 {
            scheduleClear()
        }
    }
    
    // MARK: - Concealed Copy (for passwords/secrets)
    
    /// Copies a secret to the clipboard with concealed type
    /// This marks the content as sensitive, which some apps respect
    /// - Parameters:
    ///   - secret: The secret string to copy
    ///   - autoClear: Whether to automatically clear (default: true)
    func copySecret(_ secret: String, autoClear: Bool = true) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        // Set as both regular string and concealed
        pasteboard.setString(secret, forType: .string)
        
        // Mark as concealed/sensitive if available
        // Note: This type is not widely supported but provides an extra layer
        let concealedType = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
        pasteboard.setString("true", forType: concealedType)
        
        lastCopiedChangeCount = pasteboard.changeCount
        
        if autoClear && timeout > 0 {
            scheduleClear()
        }
    }
    
    // MARK: - Clear Operations
    
    /// Schedules the clipboard to be cleared after the timeout
    private func scheduleClear() {
        // Cancel any existing timer
        clearTimer?.invalidate()
        
        // Schedule new timer
        clearTimer = Timer.scheduledTimer(withTimeInterval: timeout, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.clearIfUnchanged()
            }
        }
    }
    
    /// Clears the clipboard if it hasn't been modified since our copy
    private func clearIfUnchanged() {
        let pasteboard = NSPasteboard.general
        
        // Only clear if the clipboard hasn't been modified by another app
        if pasteboard.changeCount == lastCopiedChangeCount {
            clear()
        }
        
        clearTimer = nil
    }
    
    /// Clears the clipboard immediately
    func clear() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        clearTimer?.invalidate()
        clearTimer = nil
    }
    
    /// Cancels any scheduled clipboard clear
    func cancelScheduledClear() {
        clearTimer?.invalidate()
        clearTimer = nil
    }
    
    // MARK: - Status
    
    /// Whether there's a scheduled clear pending
    var hasPendingClear: Bool {
        clearTimer?.isValid ?? false
    }
    
    /// Time remaining until clipboard is cleared (nil if no clear is scheduled)
    var timeUntilClear: TimeInterval? {
        guard let timer = clearTimer, timer.isValid else { return nil }
        return timer.fireDate.timeIntervalSinceNow
    }
}

// MARK: - Convenience Extensions

extension ClipboardService {
    /// Formats the timeout for display
    static func formatTimeout(_ timeout: TimeInterval) -> String {
        if timeout == 0 {
            return "Never"
        } else if timeout < 60 {
            return "\(Int(timeout)) seconds"
        } else {
            let minutes = Int(timeout / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }
    
    /// Available timeout options with display names
    static var timeoutOptions: [(TimeInterval, String)] {
        clipboardTimeoutOptions.map { timeout in
            (timeout, formatTimeout(timeout))
        }
    }
}
