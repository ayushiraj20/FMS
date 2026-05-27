import SwiftUI

struct LoginView: View {
    enum FocusField: Hashable {
        case email
        case password
    }

    @Environment(AppViewModel.self) private var appViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    @FocusState private var focusedField: FocusField?

    var body: some View {
        NavigationStack {
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
                                Image(systemName: "truck.box.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.white)
                            }
                            .padding(.top, 40)
                            
                            Text("Fleeto")
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        
                        // Login Form
                        VStack(spacing: 24) {
                            // Email Field
                            VStack(alignment: .leading, spacing: 8) {
                                Text("EMAIL ADDRESS")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .kerning(1.2)
                                
                                AuthTextField(
                                    text: $email,
                                    icon: "envelope",
                                    isFocused: focusedField == .email,
                                    autocapitalization: .never
                                )
                                .focused($focusedField, equals: .email)
                            }
                            
                            // Password Field
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("PASSWORD")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .kerning(1.2)
                                    Spacer()
                                   
                                }
                                
                                AuthTextField(
                                    text: $password,
                                    icon: "lock",
                                    isFocused: focusedField == .password,
                                    isSecure: !showPassword,
                                    hasToggle: true,
                                    showPassword: $showPassword
                                )
                                .focused($focusedField, equals: .password)
                                Button("FORGOT?") { }
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(AppTheme.brand)
                            }
                            
                            // Error Message Banner
                            if let error = appViewModel.authErrorMessage {
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
                                Task {
                                    await appViewModel.login(email: email, password: password)
                                }
                            } label: {
                                if appViewModel.isAuthenticating {
                                    ProgressView()
                                        .tint(.white)
                                        .frame(maxWidth: .infinity)
                                } else {
                                    HStack {
                                        Text("Sign In")
//                                        Image(systemName: "arrow.right")
                                    }
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
                        
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
    }

}

// Custom Premium Text Field Component
struct AuthTextField: View {
    @Binding var text: String
    let icon: String
    let isFocused: Bool
    var autocapitalization: TextInputAutocapitalization = .sentences
    var isSecure: Bool = false
    var hasToggle: Bool = false
    var showPassword: Binding<Bool>? = nil

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(isFocused ? AppTheme.brand : AppTheme.textSecondary.opacity(0.7))
                .frame(width: 20)
            
            if isSecure {
                SecureField("", text: $text)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()
                    .foregroundStyle(AppTheme.textPrimary)
            } else {
                TextField("", text: $text)
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()
                    .foregroundStyle(AppTheme.textPrimary)
            }
            
            if hasToggle, let showPassword = showPassword {
                Button {
                    showPassword.wrappedValue.toggle()
                } label: {
                    Image(systemName: showPassword.wrappedValue ? "eye.slash" : "eye")
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 4)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surfaceSecondary)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(isFocused ? AppTheme.brand : Color.clear, lineWidth: 1.5)
                )
        )
    }
}

#Preview {
    LoginView()
        .environment(AppViewModel())
}
