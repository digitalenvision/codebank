import XCTest
@testable import CodeBank

final class CryptoTests: XCTestCase {
    
    // MARK: - Key Derivation Tests
    
    func testKeyDerivation() throws {
        let password = "testPassword123!"
        let salt = KeyDerivation.generateSalt()
        
        let key = try KeyDerivation.deriveKey(from: password, salt: salt)
        
        XCTAssertEqual(key.count, 32, "Key should be 32 bytes (256 bits)")
    }
    
    func testKeyDerivationConsistency() throws {
        let password = "testPassword123!"
        let salt = KeyDerivation.generateSalt()
        
        let key1 = try KeyDerivation.deriveKey(from: password, salt: salt)
        let key2 = try KeyDerivation.deriveKey(from: password, salt: salt)
        
        XCTAssertEqual(key1, key2, "Same password and salt should produce same key")
    }
    
    func testKeyDerivationDifferentSalts() throws {
        let password = "testPassword123!"
        let salt1 = KeyDerivation.generateSalt()
        let salt2 = KeyDerivation.generateSalt()
        
        let key1 = try KeyDerivation.deriveKey(from: password, salt: salt1)
        let key2 = try KeyDerivation.deriveKey(from: password, salt: salt2)
        
        XCTAssertNotEqual(key1, key2, "Different salts should produce different keys")
    }
    
    func testPasswordVerification() throws {
        let password = "testPassword123!"
        let salt = KeyDerivation.generateSalt()
        let key = try KeyDerivation.deriveKey(from: password, salt: salt)
        
        XCTAssertTrue(KeyDerivation.verifyPassword(password, salt: salt, expectedKey: key))
        XCTAssertFalse(KeyDerivation.verifyPassword("wrongPassword", salt: salt, expectedKey: key))
    }
    
    func testSaltGeneration() {
        let salt1 = KeyDerivation.generateSalt()
        let salt2 = KeyDerivation.generateSalt()
        
        XCTAssertEqual(salt1.count, Constants.Security.PBKDF2.saltLength)
        XCTAssertEqual(salt2.count, Constants.Security.PBKDF2.saltLength)
        XCTAssertNotEqual(salt1, salt2, "Generated salts should be unique")
    }
    
    // MARK: - Password Strength Tests
    
    func testPasswordStrengthWeak() {
        XCTAssertEqual(KeyDerivation.evaluatePasswordStrength("abc"), .weak)
        XCTAssertEqual(KeyDerivation.evaluatePasswordStrength("password"), .weak)
    }
    
    func testPasswordStrengthFair() {
        XCTAssertEqual(KeyDerivation.evaluatePasswordStrength("Password1"), .fair)
    }
    
    func testPasswordStrengthGood() {
        let strength = KeyDerivation.evaluatePasswordStrength("Password123")
        XCTAssertTrue(strength >= .fair)
    }
    
    func testPasswordStrengthStrong() {
        let strength = KeyDerivation.evaluatePasswordStrength("Password123!@")
        XCTAssertTrue(strength >= .good)
    }
    
    func testPasswordStrengthVeryStrong() {
        let strength = KeyDerivation.evaluatePasswordStrength("VeryStr0ng!Password#2024")
        XCTAssertTrue(strength >= .strong)
    }
    
    // MARK: - Encryption Tests
    
    func testEncryptDecryptRoundtrip() throws {
        let key = EncryptionEngine.generateKey()
        let plaintext = "Hello, World!".data(using: .utf8)!
        
        let encrypted = try EncryptionEngine.encrypt(plaintext, key: key)
        let decrypted = try EncryptionEngine.decrypt(encrypted, key: key)
        
        XCTAssertEqual(decrypted, plaintext)
    }
    
    func testEncryptDecryptString() throws {
        let key = EncryptionEngine.generateKey()
        let plaintext = "This is a secret message!"
        
        let encrypted = try EncryptionEngine.encrypt(plaintext, key: key)
        let decrypted = try EncryptionEngine.decryptString(encrypted, key: key)
        
        XCTAssertEqual(decrypted, plaintext)
    }
    
    func testEncryptDecryptCodable() throws {
        struct TestStruct: Codable, Equatable {
            let name: String
            let value: Int
        }
        
        let key = EncryptionEngine.generateKey()
        let original = TestStruct(name: "Test", value: 42)
        
        let encrypted = try EncryptionEngine.encrypt(original, key: key)
        let decrypted = try EncryptionEngine.decrypt(encrypted, key: key, as: TestStruct.self)
        
        XCTAssertEqual(decrypted, original)
    }
    
    func testEncryptedDataDiffers() throws {
        let key = EncryptionEngine.generateKey()
        let plaintext = "Same message".data(using: .utf8)!
        
        let encrypted1 = try EncryptionEngine.encrypt(plaintext, key: key)
        let encrypted2 = try EncryptionEngine.encrypt(plaintext, key: key)
        
        XCTAssertNotEqual(encrypted1, encrypted2, "Same plaintext should produce different ciphertext due to random nonce")
    }
    
    func testDecryptWithWrongKey() throws {
        let key1 = EncryptionEngine.generateKey()
        let key2 = EncryptionEngine.generateKey()
        let plaintext = "Secret data".data(using: .utf8)!
        
        let encrypted = try EncryptionEngine.encrypt(plaintext, key: key1)
        
        XCTAssertThrowsError(try EncryptionEngine.decrypt(encrypted, key: key2)) { error in
            XCTAssertTrue(error is EncryptionError)
        }
    }
    
    func testDecryptTamperedData() throws {
        let key = EncryptionEngine.generateKey()
        let plaintext = "Secret data".data(using: .utf8)!
        
        var encrypted = try EncryptionEngine.encrypt(plaintext, key: key)
        
        // Tamper with the data
        if encrypted.count > 20 {
            encrypted[20] ^= 0xFF
        }
        
        XCTAssertThrowsError(try EncryptionEngine.decrypt(encrypted, key: key)) { error in
            if let encError = error as? EncryptionError {
                XCTAssertEqual(encError, .integrityCheckFailed)
            }
        }
    }
    
    func testKeyGeneration() {
        let key1 = EncryptionEngine.generateKey()
        let key2 = EncryptionEngine.generateKey()
        
        XCTAssertEqual(key1.count, 32)
        XCTAssertEqual(key2.count, 32)
        XCTAssertNotEqual(key1, key2, "Generated keys should be unique")
    }
    
    func testInvalidKeySize() {
        let shortKey = Data(repeating: 0, count: 16) // 128 bits instead of 256
        let plaintext = "Test".data(using: .utf8)!
        
        XCTAssertThrowsError(try EncryptionEngine.encrypt(plaintext, key: shortKey)) { error in
            if let encError = error as? EncryptionError {
                XCTAssertEqual(encError, .invalidKey)
            }
        }
    }
    
    // MARK: - Secure Data Tests
    
    func testSecureDataClearsMemory() {
        var data = Data([1, 2, 3, 4, 5])
        let originalCount = data.count
        
        EncryptionEngine.secureZero(&data)
        
        XCTAssertEqual(data.count, originalCount)
        XCTAssertTrue(data.allSatisfy { $0 == 0 }, "Data should be zeroed")
    }
}

// Extension to make EncryptionError Equatable for testing
extension EncryptionError: Equatable {
    public static func == (lhs: EncryptionError, rhs: EncryptionError) -> Bool {
        switch (lhs, rhs) {
        case (.encryptionFailed(let a), .encryptionFailed(let b)): return a == b
        case (.decryptionFailed(let a), .decryptionFailed(let b)): return a == b
        case (.invalidKey, .invalidKey): return true
        case (.invalidData, .invalidData): return true
        case (.integrityCheckFailed, .integrityCheckFailed): return true
        default: return false
        }
    }
}
