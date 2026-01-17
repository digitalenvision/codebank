import SwiftUI

/// Unlock screen for locked vault
struct UnlockView: View {
    @State private var viewModel = UnlockViewModel()
    @FocusState private var isPasswordFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Divider()
            
            // Content
            VStack(spacing: 32) {
                Spacer()
                
                lockIcon
                unlockForm
                
                Spacer()
            }
            .padding(40)
        }
        .background(Color.primaryBackground)
        .onAppear {
            // Just focus password field - don't auto-prompt for biometrics
            // User should explicitly click the biometric button to unlock
            isPasswordFocused = true
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            Spacer()
            
            CodeBankLogo(size: .medium)
            
            Spacer()
        }
        .overlay(alignment: .trailing) {
            Text("Locked")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background {
                    Capsule()
                        .fill(Color.secondaryBackground)
                }
        }
        .padding()
        .background(Color.secondaryBackground)
    }
    
    // MARK: - Lock Icon
    
    private var lockIcon: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.secondaryBackground)
                    .frame(width: 100, height: 100)
                
                Image(systemName: "lock.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
            }
            
            Text("Vault Locked")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Enter your master password to unlock")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Unlock Form
    
    private var unlockForm: some View {
        VStack(spacing: 16) {
            SecureTextField(title: "Master Password", text: $viewModel.password)
                .focused($isPasswordFocused)
                .onSubmit {
                    Task {
                        await viewModel.unlock()
                    }
                }
            
            if let error = viewModel.errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.circle.fill")
                    Text(error)
                }
                .font(.caption)
                .foregroundStyle(.red)
            }
            
            Button {
                Task {
                    await viewModel.unlock()
                }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isUnlocking {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(.circular)
                    }
                    
                    Text(viewModel.isUnlocking ? "Unlocking..." : "Unlock")
                        .fontWeight(.semibold)
                }
            }
            .largePrimaryButtonStyle()
            .disabled(!viewModel.canUnlock)
            
            // Biometric button
            if viewModel.isBiometricEnabled && viewModel.isBiometricAvailable {
                Button {
                    viewModel.attemptBiometricUnlock()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: viewModel.biometricType.icon)
                        Text("Unlock with \(viewModel.biometricType.displayName)")
                    }
                }
                .ghostButtonStyle()
                .disabled(viewModel.isUnlocking)
            }
        }
        .frame(maxWidth: 320)
    }
}

#Preview {
    UnlockView()
        .frame(width: 600, height: 500)
}
