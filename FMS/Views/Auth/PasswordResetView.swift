import SwiftUI

struct PasswordResetView: View {
    enum FocusField: Hashable {
        case newPassword
        case confirmPassword
    }

    @Environment(AppViewModel.self) private var appViewModel
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var showPassword = false
    @State private var showConfirmPassword = false
    @State private var errorMessage: String? = nil
    @FocusState private var focusedField: FocusField?

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {
                    
                    // Top Logo & Titles
                    VStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(AppTheme.brand)
                                .frame(width: 72, height: 72)
                            Image(systemName: "lock.rotation")
                                .font(.system(size: 32))
                                .foregroundStyle(.white)
                        }
                        .padding(.top, 40)
                        
                        Text("Reset Password")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        Text("For security, you must change your default password before proceeding.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    
                    // Reset Form
                    VStack(spacing: 24) {
                        // New Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("NEW PASSWORD")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .kerning(1.2)
                            
                            AuthTextField(
                                text: $password,
                                icon: "lock",
                                isFocused: focusedField == .newPassword,
                                isSecure: !showPassword,
                                hasToggle: true,
                                showPassword: $showPassword
                            )
                            .focused($focusedField, equals: .newPassword)
                        }
                        
                        // Confirm Password Field
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CONFIRM NEW PASSWORD")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .kerning(1.2)
                            
                            AuthTextField(
                                text: $confirmPassword,
                                icon: "lock.shield",
                                isFocused: focusedField == .confirmPassword,
                                isSecure: !showConfirmPassword,
                                hasToggle: true,
                                showPassword: $showConfirmPassword
                            )
                            .focused($focusedField, equals: .confirmPassword)
                        }
                        
                        // Error Message Banner
                        if let error = errorMessage ?? appViewModel.authErrorMessage {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(AppTheme.error)
                                Text(error)
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.error)
                            }
                            .padding(12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(AppTheme.error.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .transition(.opacity)
                        }
                        
                        // Submit Action Button
                        Button {
                            focusedField = nil
                            validateAndSubmit()
                        } label: {
                            if appViewModel.isAuthenticating {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Update & Sign In")
                                    .font(.system(size: 16, weight: .semibold))
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 16)
                        .background(AppTheme.brand)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: AppTheme.brand.opacity(0.3), radius: 8, x: 0, y: 4)
                        .disabled(appViewModel.isAuthenticating)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(AppTheme.surface)
                            .shadow(color: AppTheme.cardShadowColor.opacity(0.05), radius: 20, x: 0, y: 10)
                    )
                    
                    // Cancel / Log Out Button
                    Button {
                        appViewModel.logout()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.left.circle")
                            Text("Back to Login")
                        }
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.top, 8)
                    .disabled(appViewModel.isAuthenticating)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    private func validateAndSubmit() {
        errorMessage = nil
        
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedConfirm = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedPassword.isEmpty {
            errorMessage = "Please enter a new password."
            return
        }
        
        if trimmedPassword.count < 6 {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        
        if trimmedPassword == "demo123" {
            errorMessage = "Please choose a password other than the default."
            return
        }
        
        if trimmedPassword != trimmedConfirm {
            errorMessage = "Passwords do not match."
            return
        }
        
        Task {
            do {
                try await appViewModel.updatePasswordAndCompleteReset(newPassword: trimmedPassword)
            } catch {
                // error is already handled by AppViewModel or printed
            }
        }
    }
}

#Preview {
    PasswordResetView()
        .environment(AppViewModel())
}
