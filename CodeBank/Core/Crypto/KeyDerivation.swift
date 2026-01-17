import Foundation
import CommonCrypto

/// PBKDF2 parameters
/// Using SHA-512 with 600,000 iterations as recommended by OWASP 2023
private enum PBKDF2Config {
    static let iterations: Int = 600_000
    static let saltLength: Int = 16
    static let keyLength: Int = 32 // 256 bits
}

/// Errors that can occur during key derivation
enum KeyDerivationError: LocalizedError {
    case derivationFailed
    case invalidSalt
    case invalidPassword
    
    var errorDescription: String? {
        switch self {
        case .derivationFailed:
            return "Failed to derive encryption key from password"
        case .invalidSalt:
            return "Invalid salt provided for key derivation"
        case .invalidPassword:
            return "Invalid password provided"
        }
    }
}

/// Handles secure key derivation using PBKDF2-SHA512
/// 
/// PBKDF2 with SHA-512 and high iteration count provides strong protection
/// against brute-force attacks. This implementation uses CommonCrypto which
/// is built into macOS and works on all architectures (Intel and Apple Silicon).
final class KeyDerivation {
    
    /// Derives a 256-bit encryption key from a password and salt using PBKDF2-SHA512
    /// 
    /// - Parameters:
    ///   - password: The user's master password
    ///   - salt: A cryptographically random salt (must be at least 16 bytes)
    /// - Returns: A 32-byte (256-bit) encryption key
    /// - Throws: `KeyDerivationError` if derivation fails
    static func deriveKey(from password: String, salt: Data) throws -> Data {
        guard !password.isEmpty else {
            throw KeyDerivationError.invalidPassword
        }
        
        guard salt.count >= PBKDF2Config.saltLength else {
            throw KeyDerivationError.invalidSalt
        }
        
        guard let passwordData = password.data(using: .utf8) else {
            throw KeyDerivationError.invalidPassword
        }
        
        var derivedKey = Data(count: PBKDF2Config.keyLength)
        
        let result = derivedKey.withUnsafeMutableBytes { derivedKeyBytes in
            salt.withUnsafeBytes { saltBytes in
                passwordData.withUnsafeBytes { passwordBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordBytes.baseAddress?.assumingMemoryBound(to: Int8.self),
                        passwordData.count,
                        saltBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA512),
                        UInt32(PBKDF2Config.iterations),
                        derivedKeyBytes.baseAddress?.assumingMemoryBound(to: UInt8.self),
                        PBKDF2Config.keyLength
                    )
                }
            }
        }
        
        guard result == kCCSuccess else {
            throw KeyDerivationError.derivationFailed
        }
        
        return derivedKey
    }
    
    /// Generates a cryptographically secure random salt
    /// 
    /// - Returns: A random salt of the configured length (default 16 bytes)
    static func generateSalt() -> Data {
        var salt = Data(count: PBKDF2Config.saltLength)
        _ = salt.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, PBKDF2Config.saltLength, bytes.baseAddress!)
        }
        return salt
    }
    
    /// Verifies if a password matches the stored hash
    /// 
    /// - Parameters:
    ///   - password: The password to verify
    ///   - salt: The salt used for the original derivation
    ///   - expectedKey: The expected derived key
    /// - Returns: `true` if the password produces the expected key
    static func verifyPassword(_ password: String, salt: Data, expectedKey: Data) -> Bool {
        guard let derivedKey = try? deriveKey(from: password, salt: salt) else {
            return false
        }
        
        // Constant-time comparison to prevent timing attacks
        return derivedKey.withUnsafeBytes { derived in
            expectedKey.withUnsafeBytes { expected in
                guard derived.count == expected.count else { return false }
                var result: UInt8 = 0
                for i in 0..<derived.count {
                    result |= derived[i] ^ expected[i]
                }
                return result == 0
            }
        }
    }
}

// MARK: - Password Strength Evaluation

extension KeyDerivation {
    
    /// Password strength levels
    enum PasswordStrength: Int, Comparable {
        case weak = 0
        case fair = 1
        case good = 2
        case strong = 3
        case veryStrong = 4
        
        var displayName: String {
            switch self {
            case .weak: return "Weak"
            case .fair: return "Fair"
            case .good: return "Good"
            case .strong: return "Strong"
            case .veryStrong: return "Very Strong"
            }
        }
        
        var color: String {
            switch self {
            case .weak: return "red"
            case .fair: return "orange"
            case .good: return "yellow"
            case .strong: return "green"
            case .veryStrong: return "blue"
            }
        }
        
        static func < (lhs: PasswordStrength, rhs: PasswordStrength) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }
    
    /// Evaluates the strength of a password
    /// 
    /// - Parameter password: The password to evaluate
    /// - Returns: The strength level of the password
    static func evaluatePasswordStrength(_ password: String) -> PasswordStrength {
        var score = 0
        
        // Length checks
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.count >= 16 { score += 1 }
        
        // Character variety checks
        let hasUppercase = password.contains(where: { $0.isUppercase })
        let hasLowercase = password.contains(where: { $0.isLowercase })
        let hasDigit = password.contains(where: { $0.isNumber })
        let hasSpecial = password.contains(where: { !$0.isLetter && !$0.isNumber })
        
        if hasUppercase { score += 1 }
        if hasLowercase { score += 1 }
        if hasDigit { score += 1 }
        if hasSpecial { score += 2 }
        
        // Common patterns penalty
        let lowercased = password.lowercased()
        let commonPatterns = ["password", "123456", "qwerty", "admin", "letmein"]
        for pattern in commonPatterns {
            if lowercased.contains(pattern) {
                score -= 2
            }
        }
        
        // Map score to strength level
        switch score {
        case ..<2: return .weak
        case 2..<4: return .fair
        case 4..<6: return .good
        case 6..<8: return .strong
        default: return .veryStrong
        }
    }
}
