import Foundation
import SwiftUI

/// View model for the setup wizard
@MainActor
@Observable
final class SetupViewModel {
    
    // MARK: - Properties
    
    var password: String = ""
    var confirmPassword: String = ""
    var enableBiometrics: Bool = true
    var isCreating: Bool = false
    var errorMessage: String?
    
    private let vaultService: VaultService
    private let biometricService: BiometricService
    
    // MARK: - Computed Properties
    
    var passwordStrength: KeyDerivation.PasswordStrength {
        KeyDerivation.evaluatePasswordStrength(password)
    }
    
    var canCreate: Bool {
        password.count >= Constants.Security.minimumPasswordLength &&
        password == confirmPassword &&
        passwordStrength >= .fair
    }
    
    var passwordsMatch: Bool {
        confirmPassword.isEmpty || password == confirmPassword
    }
    
    var isBiometricAvailable: Bool {
        biometricService.isAvailable
    }
    
    var biometricType: BiometricService.BiometricType {
        biometricService.biometricType
    }
    
    // MARK: - Initialization
    
    init() {
        self.vaultService = VaultService.shared
        self.biometricService = BiometricService.shared
    }
    
    // MARK: - Actions
    
    func createVault() async {
        guard canCreate else { return }
        
        isCreating = true
        errorMessage = nil
        
        do {
            try await vaultService.createVault(
                password: password,
                enableBiometrics: enableBiometrics && isBiometricAvailable
            )
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isCreating = false
    }
}
