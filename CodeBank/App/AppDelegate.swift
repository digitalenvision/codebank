import AppKit
import Carbon
import SwiftUI

/// Application delegate handling global hotkeys and app lifecycle
final class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Properties
    
    private var globalHotkeyMonitor: Any?
    private var localHotkeyMonitor: Any?
    private var quickSearchWindow: NSWindow?
    private var quickSearchHostingView: NSHostingView<QuickSearchPanel>?
    
    // MARK: - App Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Register global hotkey
        setupGlobalHotkey()
        
        // Configure app behavior
        NSApp.setActivationPolicy(.regular)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Clean up
        if let monitor = globalHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localHotkeyMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Reopen main window if closed
        if !flag {
            for window in NSApp.windows {
                window.makeKeyAndOrderFront(self)
            }
        }
        return true
    }
    
    // MARK: - Global Hotkey Setup
    
    private func setupGlobalHotkey() {
        // Global monitor (when app is in background)
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleGlobalKeyEvent(event)
        }
        
        // Local monitor (when app is in foreground)
        localHotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleGlobalKeyEvent(event) == true {
                return nil // Event consumed
            }
            return event
        }
    }
    
    @discardableResult
    private func handleGlobalKeyEvent(_ event: NSEvent) -> Bool {
        // Check for Cmd+Shift+Space
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let targetModifiers: NSEvent.ModifierFlags = [.command, .shift]
        
        guard modifiers == targetModifiers,
              event.keyCode == Constants.Hotkey.quickSearchKeyCode else {
            return false
        }
        
        // Toggle quick search
        Task { @MainActor in
            self.toggleQuickSearch()
        }
        
        return true
    }
    
    // MARK: - Quick Search Window
    
    @MainActor
    private func toggleQuickSearch() {
        let appState = AppState.shared
        let vaultService = VaultService.shared
        
        // Only show quick search if vault is unlocked
        guard vaultService.state == .unlocked else {
            // Bring main window to front if locked
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        if quickSearchWindow?.isVisible == true {
            hideQuickSearch()
        } else {
            showQuickSearch()
        }
        
        appState.isQuickSearchVisible = quickSearchWindow?.isVisible ?? false
    }
    
    @MainActor
    private func showQuickSearch() {
        // Create window if needed
        if quickSearchWindow == nil {
            createQuickSearchWindow()
        }
        
        guard let window = quickSearchWindow else { return }
        
        // Position window in center of main screen
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowWidth = Constants.UI.quickSearchWidth
            let windowHeight = Constants.UI.quickSearchMaxHeight
            
            let x = screenFrame.midX - windowWidth / 2
            let y = screenFrame.midY - windowHeight / 2 + 100 // Slightly above center
            
            window.setFrame(NSRect(x: x, y: y, width: windowWidth, height: windowHeight), display: true)
        }
        
        // Show and focus
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    @MainActor
    private func hideQuickSearch() {
        quickSearchWindow?.orderOut(nil)
        SearchService.shared.clear()
    }
    
    @MainActor
    private func createQuickSearchWindow() {
        // Create the content view
        let contentView = QuickSearchPanel { [weak self] in
            self?.hideQuickSearch()
        }
        
        // Create hosting view
        let hostingView = NSHostingView(rootView: contentView)
        quickSearchHostingView = hostingView
        
        // Create window
        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: Constants.UI.quickSearchWidth, height: Constants.UI.quickSearchMaxHeight),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.contentView = hostingView
        window.isFloatingPanel = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.hasShadow = true
        
        // Handle escape key to close
        window.hidesOnDeactivate = false
        
        quickSearchWindow = window
    }
}

// MARK: - Menu Commands

extension AppDelegate {
    @IBAction func showQuickSearchCommand(_ sender: Any?) {
        Task { @MainActor in
            toggleQuickSearch()
        }
    }
    
    @IBAction func lockVaultCommand(_ sender: Any?) {
        Task { @MainActor in
            VaultService.shared.lock()
        }
    }
}
