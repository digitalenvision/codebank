import Foundation
import Combine
import AppKit

/// UserDefaults keys for vault state
private enum VaultKeys {
    static let vaultCreated = "vault_created"
    static let biometricsEnabled = "biometrics_enabled"
    static let autoLockTimeout = "auto_lock_timeout"
}

/// Represents the current state of the vault
enum VaultState: Equatable {
    /// No vault has been created yet - show setup wizard
    case needsSetup
    
    /// Vault exists but is locked - show unlock screen
    case locked
    
    /// Vault is unlocked and ready to use
    case unlocked
    
    /// An error occurred
    case error(String)
    
    static func == (lhs: VaultState, rhs: VaultState) -> Bool {
        switch (lhs, rhs) {
        case (.needsSetup, .needsSetup): return true
        case (.locked, .locked): return true
        case (.unlocked, .unlocked): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

/// Errors that can occur during vault operations
enum VaultError: LocalizedError {
    case invalidPassword
    case vaultAlreadyExists
    case vaultNotCreated
    case keychainError(String)
    case storageError(String)
    case biometricNotAvailable
    case biometricNotEnabled
    case biometricFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidPassword:
            return "Invalid master password"
        case .vaultAlreadyExists:
            return "A vault already exists"
        case .vaultNotCreated:
            return "No vault has been created yet"
        case .keychainError(let reason):
            return "Keychain error: \(reason)"
        case .storageError(let reason):
            return "Storage error: \(reason)"
        case .biometricNotAvailable:
            return "Biometric authentication is not available on this device"
        case .biometricNotEnabled:
            return "Biometric authentication is not enabled"
        case .biometricFailed:
            return "Biometric authentication failed"
        }
    }
}

/// Manages the vault lifecycle: creation, locking, unlocking
@MainActor
@Observable
final class VaultService {
    
    // MARK: - Singleton
    
    static let shared = VaultService()
    
    // MARK: - Published State
    
    /// Current vault state
    private(set) var state: VaultState = .needsSetup
    
    /// Whether the vault is currently unlocking
    private(set) var isUnlocking: Bool = false
    
    /// Last error message
    private(set) var lastError: String?
    
    // MARK: - Private Properties
    
    private var encryptionKey: SecureData?
    private var autoLockTimer: Timer?
    private var lastActivityDate: Date = Date()
    
    private let keychainService: KeychainService
    private let biometricService: BiometricService
    private let storageService: StorageService
    
    // MARK: - Initialization
    
    private init() {
        self.keychainService = KeychainService.shared
        self.biometricService = BiometricService.shared
        self.storageService = StorageService.shared
        
        // Check initial state
        checkVaultState()
        
        // Setup activity monitoring for auto-lock
        setupActivityMonitoring()
    }
    
    // MARK: - State Management
    
    /// Checks and updates the vault state
    private func checkVaultState() {
        if storageService.databaseExists && keychainService.hasSalt() {
            state = .locked
        } else {
            state = .needsSetup
        }
    }
    
    // MARK: - Vault Creation
    
    /// Creates a new vault with the given master password
    /// - Parameters:
    ///   - password: The master password to protect the vault
    ///   - enableBiometrics: Whether to enable biometric unlock
    /// - Throws: `VaultError` if creation fails
    func createVault(password: String, enableBiometrics: Bool) async throws {
        guard state == .needsSetup else {
            throw VaultError.vaultAlreadyExists
        }
        
        // Generate salt
        let salt = KeyDerivation.generateSalt()
        
        // Derive encryption key
        let key = try KeyDerivation.deriveKey(from: password, salt: salt)
        
        // Store salt in keychain
        try keychainService.storeSalt(salt)
        
        // Store a verification hash (derived key encrypted with itself)
        let verificationData = try EncryptionEngine.encrypt("CODEBANK_VAULT_V1".data(using: .utf8)!, key: key)
        try keychainService.storeVerificationData(verificationData)
        
        // Open storage with the key
        try storageService.open(with: key)
        
        // Store the encryption key securely
        encryptionKey = SecureData(key)
        
        // Enable biometrics if requested
        if enableBiometrics && biometricService.isAvailable {
            try await enableBiometricUnlock(key: key)
        }
        
        // Mark vault as created
        UserDefaults.standard.set(true, forKey: VaultKeys.vaultCreated)
        
        // Update state
        state = .unlocked
        startAutoLockTimer()
    }
    
    // MARK: - Unlock Operations
    
    /// Unlocks the vault with the master password
    /// - Parameter password: The master password
    /// - Throws: `VaultError` if unlock fails
    func unlock(with password: String) async throws {
        guard state == .locked else { return }
        
        isUnlocking = true
        defer { isUnlocking = false }
        
        // Get salt from keychain
        guard let salt = try keychainService.getSalt() else {
            throw VaultError.keychainError("Salt not found")
        }
        
        // Derive key from password
        let key = try KeyDerivation.deriveKey(from: password, salt: salt)
        
        // Verify the key is correct
        try verifyKey(key)
        
        // Open storage
        try storageService.open(with: key)
        
        // Store the encryption key
        encryptionKey = SecureData(key)
        
        // Update state
        state = .unlocked
        lastError = nil
        lastActivityDate = Date() // Reset activity on unlock
        startAutoLockTimer()
    }
    
    /// Unlocks the vault using biometrics
    /// - Throws: `VaultError` if unlock fails
    func unlockWithBiometrics() async throws {
        guard state == .locked else { return }
        guard biometricService.isAvailable else {
            throw VaultError.biometricNotAvailable
        }
        guard UserDefaults.standard.bool(forKey: VaultKeys.biometricsEnabled) else {
            throw VaultError.biometricNotEnabled
        }
        
        isUnlocking = true
        defer { isUnlocking = false }
        
        // Get key from keychain (biometric auth happens automatically via keychain protection)
        guard let key = try keychainService.getBiometricProtectedKey() else {
            throw VaultError.keychainError("Biometric key not found")
        }
        
        // Verify the key is correct
        try verifyKey(key)
        
        // Open storage
        try storageService.open(with: key)
        
        // Store the encryption key
        encryptionKey = SecureData(key)
        
        // Update state
        state = .unlocked
        lastError = nil
        lastActivityDate = Date() // Reset activity on unlock
        startAutoLockTimer()
    }
    
    /// Verifies that the derived key is correct
    private func verifyKey(_ key: Data) throws {
        guard let verificationData = try keychainService.getVerificationData() else {
            throw VaultError.keychainError("Verification data not found")
        }
        
        do {
            let decrypted = try EncryptionEngine.decrypt(verificationData, key: key)
            let verification = String(data: decrypted, encoding: .utf8)
            
            guard verification == "CODEBANK_VAULT_V1" else {
                throw VaultError.invalidPassword
            }
        } catch {
            throw VaultError.invalidPassword
        }
    }
    
    // MARK: - Lock Operations
    
    /// Locks the vault
    func lock() {
        // Clear the encryption key securely
        encryptionKey = nil
        
        // Clear sensitive data from app state
        clearSensitiveDataFromMemory()
        
        // Close storage
        storageService.close()
        
        // Stop auto-lock timer
        stopAutoLockTimer()
        
        // Update state
        state = .locked
        
        // Post notification for UI to update
        NotificationCenter.default.post(name: .vaultDidLock, object: nil)
    }
    
    /// Clears sensitive data from memory
    private func clearSensitiveDataFromMemory() {
        // Clear items from AppState
        Task { @MainActor in
            AppState.shared.items = []
            AppState.shared.projects = []
            AppState.shared.selectedItemId = nil
            AppState.shared.editingItem = nil
        }
    }
    
    // MARK: - Biometric Management
    
    /// Enables biometric unlock
    private func enableBiometricUnlock(key: Data) async throws {
        guard biometricService.isAvailable else {
            throw VaultError.biometricNotAvailable
        }
        
        // Authenticate first to ensure user consent
        let authenticated = try await biometricService.authenticate(reason: "Enable biometric unlock for CodeBank")
        guard authenticated else {
            throw VaultError.biometricFailed
        }
        
        // Store key with biometric protection
        try keychainService.storeBiometricProtectedKey(key)
        
        // Mark biometrics as enabled
        UserDefaults.standard.set(true, forKey: VaultKeys.biometricsEnabled)
    }
    
    /// Disables biometric unlock
    func disableBiometricUnlock() throws {
        try keychainService.deleteBiometricProtectedKey()
        UserDefaults.standard.set(false, forKey: VaultKeys.biometricsEnabled)
    }
    
    /// Whether biometric unlock is enabled
    var isBiometricEnabled: Bool {
        UserDefaults.standard.bool(forKey: VaultKeys.biometricsEnabled)
    }
    
    /// Whether biometric unlock is available
    var isBiometricAvailable: Bool {
        biometricService.isAvailable
    }
    
    /// The type of biometric available
    var biometricType: BiometricService.BiometricType {
        biometricService.biometricType
    }
    
    // MARK: - Password Change
    
    /// Changes the master password
    /// - Parameters:
    ///   - currentPassword: The current master password
    ///   - newPassword: The new master password
    /// - Throws: `VaultError` if the change fails
    func changePassword(from currentPassword: String, to newPassword: String) async throws {
        guard state == .unlocked else {
            throw VaultError.vaultNotCreated
        }
        
        // Verify current password
        guard let salt = try keychainService.getSalt() else {
            throw VaultError.keychainError("Salt not found")
        }
        
        let currentKey = try KeyDerivation.deriveKey(from: currentPassword, salt: salt)
        try verifyKey(currentKey)
        
        // Generate new salt
        let newSalt = KeyDerivation.generateSalt()
        
        // Derive new key
        let newKey = try KeyDerivation.deriveKey(from: newPassword, salt: newSalt)
        
        // Export all data with current key
        let exportData = try storageService.exportAllData()
        
        // Close current storage
        storageService.close()
        
        // Delete current database
        try storageService.deleteDatabase()
        
        // Store new salt
        try keychainService.storeSalt(newSalt)
        
        // Store new verification data
        let verificationData = try EncryptionEngine.encrypt("CODEBANK_VAULT_V1".data(using: .utf8)!, key: newKey)
        try keychainService.storeVerificationData(verificationData)
        
        // Open new storage with new key
        try storageService.open(with: newKey)
        
        // Re-import all data (will be encrypted with new key)
        try storageService.importData(exportData)
        
        // Update stored key
        encryptionKey = SecureData(newKey)
        
        // Re-enable biometrics if it was enabled
        if isBiometricEnabled {
            try await enableBiometricUnlock(key: newKey)
        }
    }
    
    // MARK: - Auto-Lock
    
    /// Records user activity (call this on user interactions)
    func recordActivity() {
        lastActivityDate = Date()
    }
    
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    
    private func setupActivityMonitoring() {
        // Monitor for system sleep
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.lock()
            }
        }
        
        // Monitor for screen saver
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screensaver.didstart"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.lock()
            }
        }
        
        // Monitor for screen lock
        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.screenIsLocked"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.lock()
            }
        }
        
        // Monitor for settings changes
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                // Restart timer if timeout changed and vault is unlocked
                if self?.state == .unlocked {
                    self?.startAutoLockTimer()
                }
            }
        }
        
        // Monitor local events (mouse clicks, key presses) when app is active
        localEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .leftMouseDown, .rightMouseDown, .scrollWheel]
        ) { [weak self] event in
            Task { @MainActor in
                self?.recordActivity()
            }
            return event
        }
    }
    
    private func startAutoLockTimer() {
        stopAutoLockTimer()
        
        let timeout = UserDefaults.standard.double(forKey: VaultKeys.autoLockTimeout)
        guard timeout > 0 else { return } // 0 = never auto-lock
        
        // Check more frequently for better responsiveness
        let checkInterval = min(timeout / 4, 30.0)
        
        autoLockTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAutoLock()
            }
        }
    }
    
    private func stopAutoLockTimer() {
        autoLockTimer?.invalidate()
        autoLockTimer = nil
    }
    
    private func checkAutoLock() {
        guard state == .unlocked else { return }
        
        let timeout = UserDefaults.standard.double(forKey: VaultKeys.autoLockTimeout)
        guard timeout > 0 else { return }
        
        let elapsed = Date().timeIntervalSince(lastActivityDate)
        if elapsed >= timeout {
            lock()
        }
    }
    
    // MARK: - Vault Deletion
    
    /// Deletes the vault and all data (requires password confirmation)
    /// - Parameter password: The master password for confirmation
    /// - Throws: `VaultError` if deletion fails
    func deleteVault(confirmWith password: String) async throws {
        // Verify password
        guard let salt = try keychainService.getSalt() else {
            throw VaultError.keychainError("Salt not found")
        }
        
        let key = try KeyDerivation.deriveKey(from: password, salt: salt)
        try verifyKey(key)
        
        // Lock and clear
        lock()
        
        // Delete database
        try storageService.deleteDatabase()
        
        // Clear keychain
        try keychainService.deleteAll()
        
        // Clear user defaults
        UserDefaults.standard.removeObject(forKey: VaultKeys.vaultCreated)
        UserDefaults.standard.removeObject(forKey: VaultKeys.biometricsEnabled)
        
        // Update state
        state = .needsSetup
    }
}

// MARK: - Convenience Extensions

extension VaultService {
    /// Whether the vault exists
    var vaultExists: Bool {
        storageService.databaseExists && keychainService.hasSalt()
    }
    
    /// Whether the vault is currently unlocked
    var isUnlocked: Bool {
        state == .unlocked
    }
    
    /// Gets the current encryption key (only available when unlocked)
    var currentKey: Data? {
        encryptionKey?.bytes
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let vaultDidLock = Notification.Name("vaultDidLock")
    static let vaultDidUnlock = Notification.Name("vaultDidUnlock")
}
