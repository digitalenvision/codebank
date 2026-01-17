import Foundation
import SwiftUI

/// View model for the unlock screen
@MainActor
@Observable
final class UnlockViewModel {
    
    // MARK: - Properties
    
    var password: String = ""
    var isUnlocking: Bool = false
    var errorMessage: String?
    var showBiometricPrompt: Bool = false
    
    private let vaultService: VaultService
    private let biometricService: BiometricService
    
    // MARK: - Computed Properties
    
    var canUnlock: Bool {
        !password.isEmpty && !isUnlocking
    }
    
    var isBiometricEnabled: Bool {
        vaultService.isBiometricEnabled
    }
    
    var isBiometricAvailable: Bool {
        vaultService.isBiometricAvailable
    }
    
    var biometricType: BiometricService.BiometricType {
        vaultService.biometricType
    }
    
    // MARK: - Initialization
    
    init() {
        self.vaultService = VaultService.shared
        self.biometricService = BiometricService.shared
    }
    
    // MARK: - Actions
    
    func unlock() async {
        guard canUnlock else { return }
        
        isUnlocking = true
        errorMessage = nil
        
        do {
            try await vaultService.unlock(with: password)
            password = "" // Clear password from memory
        } catch {
            errorMessage = error.localizedDescription
            password = ""
        }
        
        isUnlocking = false
    }
    
    func unlockWithBiometrics() async {
        guard isBiometricEnabled && isBiometricAvailable else { return }
        
        isUnlocking = true
        errorMessage = nil
        
        do {
            try await vaultService.unlockWithBiometrics()
        } catch VaultError.biometricFailed {
            // User cancelled - don't show error
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isUnlocking = false
    }
    
    func attemptBiometricUnlock() {
        Task {
            await unlockWithBiometrics()
        }
    }
}
