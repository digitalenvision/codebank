import SwiftUI

/// Initial setup wizard for creating the vault
struct SetupView: View {
    @State private var viewModel = SetupViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerSection
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 32) {
                    welcomeSection
                    passwordSection
                    biometricsSection
                    createButton
                }
                .padding(40)
            }
        }
        .background(Color.primaryBackground)
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        HStack {
            Spacer()
            CodeBankLogo(size: .medium)
            Spacer()
        }
        .padding()
        .background(Color.secondaryBackground)
    }
    
    // MARK: - Welcome Section
    
    private var welcomeSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient.vaultGradient)
                    .frame(width: 80, height: 80)
                
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            
            Text("Welcome to CodeBank")
                .font(.title)
                .fontWeight(.bold)
            
            Text("Create a master password to protect your developer vault.\nThis password will be required to access your stored credentials.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)
        }
    }
    
    // MARK: - Password Section
    
    private var passwordSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Master Password")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                SecureTextField(title: "Enter master password", text: $viewModel.password)
                
                if !viewModel.password.isEmpty {
                    PasswordStrengthView(strength: viewModel.passwordStrength)
                }
                
                SecureTextField(title: "Confirm master password", text: $viewModel.confirmPassword)
                
                if !viewModel.passwordsMatch {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text("Passwords don't match")
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }
            }
            
            PasswordRequirementsView(password: viewModel.password)
                .padding(.top, 8)
        }
        .frame(maxWidth: 400)
    }
    
    // MARK: - Biometrics Section
    
    private var biometricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if viewModel.isBiometricAvailable {
                Toggle(isOn: $viewModel.enableBiometrics) {
                    HStack(spacing: 12) {
                        Image(systemName: viewModel.biometricType.icon)
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .frame(width: 32)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Enable \(viewModel.biometricType.displayName)")
                                .font(.headline)
                            
                            Text("Quickly unlock your vault using biometrics")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .toggleStyle(.switch)
                .padding()
                .background {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.secondaryBackground)
                }
            }
        }
        .frame(maxWidth: 400)
    }
    
    // MARK: - Create Button
    
    private var createButton: some View {
        VStack(spacing: 12) {
            Button {
                Task {
                    await viewModel.createVault()
                }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isCreating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(.circular)
                    }
                    
                    Text(viewModel.isCreating ? "Creating Vault..." : "Create Vault")
                        .fontWeight(.semibold)
                }
            }
            .largePrimaryButtonStyle()
            .disabled(!viewModel.canCreate || viewModel.isCreating)
            
            if let error = viewModel.errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                }
                .font(.caption)
                .foregroundStyle(.red)
            }
            
            Text("Your master password cannot be recovered if lost.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: 400)
    }
}

#Preview {
    SetupView()
        .frame(width: 600, height: 700)
}
