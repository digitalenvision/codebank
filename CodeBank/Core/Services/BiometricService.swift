import Foundation
import LocalAuthentication
import AppKit

/// Handles biometric authentication (Touch ID / Face ID)
final class BiometricService {
    
    // MARK: - Types
    
    enum BiometricType {
        case none
        case touchID
        case faceID
        
        var displayName: String {
            switch self {
            case .none: return "None"
            case .touchID: return "Touch ID"
            case .faceID: return "Face ID"
            }
        }
        
        var icon: String {
            switch self {
            case .none: return "lock.fill"
            case .touchID: return "touchid"
            case .faceID: return "faceid"
            }
        }
    }
    
    // MARK: - Singleton
    
    static let shared = BiometricService()
    
    // MARK: - Properties
    
    private let context = LAContext()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Availability
    
    /// Checks if biometric authentication is available
    var isAvailable: Bool {
        var error: NSError?
        let available = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        return available
    }
    
    /// Returns the type of biometric available
    var biometricType: BiometricType {
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return .none
        }
        
        switch context.biometryType {
        case .touchID:
            return .touchID
        case .faceID:
            return .faceID
        case .opticID:
            // Apple Vision Pro - treat as Face ID equivalent
            return .faceID
        case .none:
            return .none
        @unknown default:
            return .none
        }
    }
    
    /// Returns the reason why biometrics might not be available
    var unavailabilityReason: String? {
        var error: NSError?
        guard !context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return nil
        }
        
        guard let error = error else {
            return "Biometric authentication is not available"
        }
        
        switch LAError.Code(rawValue: error.code) {
        case .biometryNotAvailable:
            return "This device does not support biometric authentication"
        case .biometryNotEnrolled:
            return "No biometric data is enrolled. Please set up Touch ID or Face ID in System Settings."
        case .biometryLockout:
            return "Biometric authentication is locked due to too many failed attempts. Please use your device passcode to unlock."
        case .passcodeNotSet:
            return "A device passcode must be set to use biometric authentication"
        default:
            return error.localizedDescription
        }
    }
    
    // MARK: - Authentication
    
    /// Authenticates the user using biometrics
    /// - Parameter reason: The reason displayed to the user for why authentication is needed
    /// - Returns: `true` if authentication succeeded
    func authenticate(reason: String) async throws -> Bool {
        // Bring app to foreground so biometric dialog appears on top
        await MainActor.run {
            NSApp.activate(ignoringOtherApps: true)
        }
        
        let newContext = LAContext()
        newContext.localizedFallbackTitle = "Use Password"
        
        do {
            let success = try await newContext.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            return success
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel:
                return false
            case .userFallback:
                // User wants to use password instead
                return false
            case .biometryLockout:
                throw BiometricError.lockout
            case .biometryNotAvailable:
                throw BiometricError.notAvailable
            case .biometryNotEnrolled:
                throw BiometricError.notEnrolled
            default:
                throw BiometricError.failed(error.localizedDescription)
            }
        }
    }
    
    /// Authenticates the user with biometrics or device passcode fallback
    /// - Parameter reason: The reason displayed to the user
    /// - Returns: `true` if authentication succeeded
    func authenticateWithFallback(reason: String) async throws -> Bool {
        // Bring app to foreground so biometric dialog appears on top
        await MainActor.run {
            NSApp.activate(ignoringOtherApps: true)
        }
        
        let newContext = LAContext()
        
        do {
            let success = try await newContext.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: reason
            )
            return success
        } catch let error as LAError {
            switch error.code {
            case .userCancel, .appCancel:
                return false
            default:
                throw BiometricError.failed(error.localizedDescription)
            }
        }
    }
}

// MARK: - Biometric Errors

enum BiometricError: LocalizedError {
    case notAvailable
    case notEnrolled
    case lockout
    case failed(String)
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Biometric authentication is not available on this device"
        case .notEnrolled:
            return "No biometric data is enrolled. Please set up Touch ID or Face ID in System Settings."
        case .lockout:
            return "Biometric authentication is locked due to too many failed attempts"
        case .failed(let reason):
            return "Biometric authentication failed: \(reason)"
        }
    }
}
