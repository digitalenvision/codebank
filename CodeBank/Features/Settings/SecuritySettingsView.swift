import SwiftUI

/// Security settings view
struct SecuritySettingsView: View {
    @Environment(VaultService.self) private var vaultService
    
    @AppStorage(Constants.UserDefaults.clipboardTimeout) private var clipboardTimeout = Constants.Security.defaultClipboardTimeout
    @AppStorage(Constants.UserDefaults.autoLockTimeout) private var autoLockTimeout = Constants.Security.defaultAutoLockTimeout
    @AppStorage(Constants.UserDefaults.biometricsEnabled) private var biometricsEnabled = false
    
    @State private var showChangePasswordSheet = false
    @State private var showDeleteVaultAlert = false
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var deletePassword = ""
    @State private var isChangingPassword = false
    @State private var errorMessage: String?
    
    var body: some View {
        Form {
            // Biometric Settings
            Section("Biometric Authentication") {
                if vaultService.isBiometricAvailable {
                    Toggle(isOn: $biometricsEnabled) {
                        HStack(spacing: 12) {
                            Image(systemName: vaultService.biometricType.icon)
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Enable \(vaultService.biometricType.displayName)")
                                Text("Quickly unlock your vault using biometrics")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onChange(of: biometricsEnabled) { _, newValue in
                        handleBiometricToggle(newValue)
                    }
                } else {
                    HStack {
                        Image(systemName: "touchid")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Biometric Authentication")
                            Text("Not available on this device")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .foregroundStyle(.secondary)
                }
            }
            
            // Auto-lock Settings
            Section("Auto-Lock") {
                Picker("Lock vault after", selection: $autoLockTimeout) {
                    ForEach(Constants.Security.autoLockTimeoutOptions, id: \.self) { timeout in
                        Text(formatTimeout(timeout)).tag(timeout)
                    }
                }
                
                Text("The vault will automatically lock after this period of inactivity, or when your Mac sleeps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Clipboard Settings
            Section("Clipboard") {
                Picker("Clear clipboard after", selection: $clipboardTimeout) {
                    ForEach(Constants.Security.clipboardTimeoutOptions, id: \.self) { timeout in
                        Text(ClipboardService.formatTimeout(timeout)).tag(timeout)
                    }
                }
                
                Text("Copied secrets will be automatically cleared from the clipboard after this time.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            // Password Settings
            Section("Master Password") {
                Button {
                    showChangePasswordSheet = true
                } label: {
                    Label("Change Master Password", systemImage: "key")
                }
                .disabled(vaultService.state != .unlocked)
            }
            
            // Danger Zone
            Section {
                Button(role: .destructive) {
                    showDeleteVaultAlert = true
                } label: {
                    Label("Delete Vault", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Danger Zone")
            } footer: {
                Text("Deleting your vault will permanently remove all stored items. This cannot be undone.")
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .sheet(isPresented: $showChangePasswordSheet) {
            changePasswordSheet
        }
        .alert("Delete Vault?", isPresented: $showDeleteVaultAlert) {
            SecureField("Enter master password", text: $deletePassword)
            Button("Cancel", role: .cancel) {
                deletePassword = ""
            }
            Button("Delete Vault", role: .destructive) {
                deleteVault()
            }
            .disabled(deletePassword.isEmpty)
        } message: {
            Text("This will permanently delete your vault and all stored items. Enter your master password to confirm.")
        }
    }
    
    // MARK: - Change Password Sheet
    
    private var changePasswordSheet: some View {
        VStack(spacing: 20) {
            Text("Change Master Password")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 12) {
                SecureTextField(title: "Current Password", text: $currentPassword)
                
                Divider()
                
                SecureTextField(title: "New Password", text: $newPassword)
                
                if !newPassword.isEmpty {
                    PasswordStrengthView(strength: KeyDerivation.evaluatePasswordStrength(newPassword))
                }
                
                SecureTextField(title: "Confirm New Password", text: $confirmPassword)
                
                if !confirmPassword.isEmpty && newPassword != confirmPassword {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle.fill")
                        Text("Passwords don't match")
                    }
                    .font(.caption)
                    .foregroundStyle(.red)
                }
            }
            
            if let error = errorMessage {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                }
                .font(.caption)
                .foregroundStyle(.red)
            }
            
            HStack {
                Button("Cancel") {
                    resetPasswordForm()
                    showChangePasswordSheet = false
                }
                .keyboardShortcut(.escape)
                
                Spacer()
                
                Button("Change Password") {
                    changePassword()
                }
                .keyboardShortcut(.return)
                .disabled(!canChangePassword || isChangingPassword)
            }
        }
        .padding()
        .frame(width: 400)
    }
    
    private var canChangePassword: Bool {
        !currentPassword.isEmpty &&
        newPassword.count >= Constants.Security.minimumPasswordLength &&
        newPassword == confirmPassword &&
        KeyDerivation.evaluatePasswordStrength(newPassword) >= .fair
    }
    
    // MARK: - Actions
    
    private func handleBiometricToggle(_ enabled: Bool) {
        Task {
            if enabled {
                // Will prompt for biometric authentication
                // The actual enabling happens in VaultService
            } else {
                try? vaultService.disableBiometricUnlock()
            }
        }
    }
    
    private func changePassword() {
        isChangingPassword = true
        errorMessage = nil
        
        Task {
            do {
                try await vaultService.changePassword(from: currentPassword, to: newPassword)
                resetPasswordForm()
                showChangePasswordSheet = false
            } catch {
                errorMessage = error.localizedDescription
            }
            isChangingPassword = false
        }
    }
    
    private func resetPasswordForm() {
        currentPassword = ""
        newPassword = ""
        confirmPassword = ""
        errorMessage = nil
    }
    
    private func deleteVault() {
        Task {
            do {
                try await vaultService.deleteVault(confirmWith: deletePassword)
            } catch {
                // Show error
            }
            deletePassword = ""
        }
    }
    
    private func formatTimeout(_ timeout: TimeInterval) -> String {
        if timeout == 0 {
            return "Never"
        } else if timeout < 60 {
            return "\(Int(timeout)) seconds"
        } else {
            let minutes = Int(timeout / 60)
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }
}

#Preview {
    SecuritySettingsView()
        .environment(VaultService.shared)
}
