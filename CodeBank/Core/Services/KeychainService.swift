import Foundation
import Security
import LocalAuthentication

/// Keychain account identifiers
private enum KeychainKeys {
    static let serviceName = "com.digitalenvision.codebank"
    static let saltAccount = "vault-salt"
    static let biometricKeyAccount = "vault-biometric-key"
}

/// Handles secure storage in the macOS Keychain
final class KeychainService {
    
    // MARK: - Singleton
    
    static let shared = KeychainService()
    
    // MARK: - Properties
    
    private let serviceName = KeychainKeys.serviceName
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Salt Operations
    
    /// Stores the encryption salt
    func storeSalt(_ salt: Data) throws {
        try store(data: salt, account: KeychainKeys.saltAccount)
    }
    
    /// Retrieves the encryption salt
    func getSalt() throws -> Data? {
        try retrieve(account: KeychainKeys.saltAccount)
    }
    
    /// Checks if salt exists
    func hasSalt() -> Bool {
        (try? getSalt()) != nil
    }
    
    // MARK: - Verification Data Operations
    
    /// Stores verification data for password verification
    func storeVerificationData(_ data: Data) throws {
        try store(data: data, account: "verification")
    }
    
    /// Retrieves verification data
    func getVerificationData() throws -> Data? {
        try retrieve(account: "verification")
    }
    
    // MARK: - Biometric Key Operations
    
    /// Stores the encryption key with biometric protection
    func storeBiometricProtectedKey(_ key: Data) throws {
        // First delete any existing key
        try? deleteBiometricProtectedKey()
        
        // Create access control that requires biometry
        var error: Unmanaged<CFError>?
        guard let access = SecAccessControlCreateWithFlags(
            kCFAllocatorDefault,
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .biometryCurrentSet,
            &error
        ) else {
            throw KeychainError.accessControlCreationFailed(error?.takeRetainedValue().localizedDescription ?? "Unknown error")
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: KeychainKeys.biometricKeyAccount,
            kSecValueData as String: key,
            kSecAttrAccessControl as String: access,
            kSecUseAuthenticationContext as String: LAContext()
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    /// Retrieves the encryption key using biometric authentication
    func getBiometricProtectedKey() throws -> Data? {
        let context = LAContext()
        context.localizedReason = "Access your CodeBank vault"
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: KeychainKeys.biometricKeyAccount,
            kSecReturnData as String: true,
            kSecUseAuthenticationContext as String: context
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        case errSecUserCanceled, errSecAuthFailed:
            throw KeychainError.biometricAuthFailed
        default:
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    /// Deletes the biometric-protected key
    func deleteBiometricProtectedKey() throws {
        try delete(account: KeychainKeys.biometricKeyAccount)
    }
    
    // MARK: - Generic Operations
    
    /// Stores data in the keychain
    private func store(data: Data, account: String) throws {
        // First try to delete any existing item
        try? delete(account: account)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    /// Retrieves data from the keychain
    private func retrieve(account: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        switch status {
        case errSecSuccess:
            return result as? Data
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    /// Deletes an item from the keychain
    private func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: account
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
    
    /// Deletes all items for this service
    func deleteAll() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainError.unhandledError(status: status)
        }
    }
}

// MARK: - Keychain Errors

enum KeychainError: LocalizedError {
    case unhandledError(status: OSStatus)
    case accessControlCreationFailed(String)
    case biometricAuthFailed
    
    var errorDescription: String? {
        switch self {
        case .unhandledError(let status):
            if let message = SecCopyErrorMessageString(status, nil) {
                return "Keychain error: \(message)"
            }
            return "Keychain error: \(status)"
        case .accessControlCreationFailed(let reason):
            return "Failed to create access control: \(reason)"
        case .biometricAuthFailed:
            return "Biometric authentication failed"
        }
    }
}
