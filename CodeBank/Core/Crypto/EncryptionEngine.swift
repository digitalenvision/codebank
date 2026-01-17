import Foundation
import Crypto

/// Errors that can occur during encryption/decryption
enum EncryptionError: LocalizedError {
    case encryptionFailed(String)
    case decryptionFailed(String)
    case invalidKey
    case invalidData
    case integrityCheckFailed
    
    var errorDescription: String? {
        switch self {
        case .encryptionFailed(let reason):
            return "Encryption failed: \(reason)"
        case .decryptionFailed(let reason):
            return "Decryption failed: \(reason)"
        case .invalidKey:
            return "Invalid encryption key"
        case .invalidData:
            return "Invalid data for encryption/decryption"
        case .integrityCheckFailed:
            return "Data integrity check failed - data may be corrupted or tampered with"
        }
    }
}

/// Handles AES-256-GCM encryption and decryption
///
/// AES-GCM (Galois/Counter Mode) provides both confidentiality and authenticity,
/// meaning it encrypts data and also verifies that it hasn't been tampered with.
final class EncryptionEngine {
    
    /// The size of the nonce (IV) in bytes - 12 bytes is standard for GCM
    private static let nonceSize = 12
    
    /// Encrypts data using AES-256-GCM
    ///
    /// The output format is: nonce (12 bytes) + ciphertext + authentication tag (16 bytes)
    ///
    /// - Parameters:
    ///   - data: The plaintext data to encrypt
    ///   - key: A 32-byte (256-bit) encryption key
    /// - Returns: The encrypted data with nonce and authentication tag
    /// - Throws: `EncryptionError` if encryption fails
    static func encrypt(_ data: Data, key: Data) throws -> Data {
        guard key.count == 32 else {
            throw EncryptionError.invalidKey
        }
        
        guard !data.isEmpty else {
            throw EncryptionError.invalidData
        }
        
        do {
            let symmetricKey = SymmetricKey(data: key)
            let nonce = AES.GCM.Nonce()
            
            let sealedBox = try AES.GCM.seal(data, using: symmetricKey, nonce: nonce)
            
            // Combine nonce + ciphertext + tag into a single Data object
            guard let combined = sealedBox.combined else {
                throw EncryptionError.encryptionFailed("Failed to combine encrypted components")
            }
            
            return combined
        } catch let error as EncryptionError {
            throw error
        } catch {
            throw EncryptionError.encryptionFailed(error.localizedDescription)
        }
    }
    
    /// Decrypts data using AES-256-GCM
    ///
    /// Expects input format: nonce (12 bytes) + ciphertext + authentication tag (16 bytes)
    ///
    /// - Parameters:
    ///   - encryptedData: The encrypted data with nonce and authentication tag
    ///   - key: The 32-byte (256-bit) encryption key used for encryption
    /// - Returns: The decrypted plaintext data
    /// - Throws: `EncryptionError` if decryption fails or integrity check fails
    static func decrypt(_ encryptedData: Data, key: Data) throws -> Data {
        guard key.count == 32 else {
            throw EncryptionError.invalidKey
        }
        
        // Minimum size: nonce (12) + tag (16) + at least 1 byte of ciphertext
        guard encryptedData.count >= nonceSize + 16 + 1 else {
            throw EncryptionError.invalidData
        }
        
        do {
            let symmetricKey = SymmetricKey(data: key)
            let sealedBox = try AES.GCM.SealedBox(combined: encryptedData)
            let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
            
            return decryptedData
        } catch CryptoKitError.authenticationFailure {
            throw EncryptionError.integrityCheckFailed
        } catch {
            throw EncryptionError.decryptionFailed(error.localizedDescription)
        }
    }
    
    /// Encrypts a string using AES-256-GCM
    ///
    /// - Parameters:
    ///   - string: The plaintext string to encrypt
    ///   - key: A 32-byte (256-bit) encryption key
    /// - Returns: The encrypted data
    /// - Throws: `EncryptionError` if encryption fails
    static func encrypt(_ string: String, key: Data) throws -> Data {
        guard let data = string.data(using: .utf8) else {
            throw EncryptionError.invalidData
        }
        return try encrypt(data, key: key)
    }
    
    /// Decrypts data to a string using AES-256-GCM
    ///
    /// - Parameters:
    ///   - encryptedData: The encrypted data
    ///   - key: The 32-byte (256-bit) encryption key
    /// - Returns: The decrypted string
    /// - Throws: `EncryptionError` if decryption fails
    static func decryptString(_ encryptedData: Data, key: Data) throws -> String {
        let decrypted = try decrypt(encryptedData, key: key)
        guard let string = String(data: decrypted, encoding: .utf8) else {
            throw EncryptionError.decryptionFailed("Failed to decode decrypted data as UTF-8 string")
        }
        return string
    }
    
    /// Encrypts a Codable object using AES-256-GCM
    ///
    /// - Parameters:
    ///   - object: The object to encrypt
    ///   - key: A 32-byte (256-bit) encryption key
    /// - Returns: The encrypted data
    /// - Throws: `EncryptionError` if encryption fails
    static func encrypt<T: Encodable>(_ object: T, key: Data) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(object)
            return try encrypt(data, key: key)
        } catch let error as EncryptionError {
            throw error
        } catch {
            throw EncryptionError.encryptionFailed("Failed to encode object: \(error.localizedDescription)")
        }
    }
    
    /// Decrypts data to a Codable object using AES-256-GCM
    ///
    /// - Parameters:
    ///   - encryptedData: The encrypted data
    ///   - key: The 32-byte (256-bit) encryption key
    ///   - type: The type to decode to
    /// - Returns: The decrypted object
    /// - Throws: `EncryptionError` if decryption fails
    static func decrypt<T: Decodable>(_ encryptedData: Data, key: Data, as type: T.Type) throws -> T {
        let decrypted = try decrypt(encryptedData, key: key)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        do {
            return try decoder.decode(type, from: decrypted)
        } catch {
            throw EncryptionError.decryptionFailed("Failed to decode object: \(error.localizedDescription)")
        }
    }
    
    /// Generates a cryptographically secure random key
    ///
    /// - Returns: A 32-byte random key
    static func generateKey() -> Data {
        var key = Data(count: 32)
        _ = key.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, 32, bytes.baseAddress!)
        }
        return key
    }
    
    /// Securely zeros out sensitive data in memory
    ///
    /// - Parameter data: The data to clear
    static func secureZero(_ data: inout Data) {
        _ = data.withUnsafeMutableBytes { bytes in
            memset(bytes.baseAddress!, 0, bytes.count)
        }
    }
}

// MARK: - Secure Data Wrapper

/// A wrapper for sensitive data that automatically zeros memory when deallocated
final class SecureData {
    private var data: Data
    
    init(_ data: Data) {
        self.data = data
    }
    
    var bytes: Data {
        data
    }
    
    deinit {
        EncryptionEngine.secureZero(&data)
    }
}
