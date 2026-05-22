import SwiftUI

struct LoginView: View {
    enum FocusField: Hashable {
        case email
        case password
    }

    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var email = ""
    @State private var password = ""

    @State private var showPassword = false
    @FocusState private var focusedField: FocusField?

    var body: some View {
        NavigationStack {
            AppScaffold {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        
                        // Header Section
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Welcome back")
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary)
                            
                            Text("Access your fleet workspace with a streamlined enterprise sign in experience.")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineSpacing(4)
                        }
                        .padding(.top, 40)
                        
                        // Main Authentication Form
                        GlassCard {
                            VStack(spacing: 20) {
                                // Email Field
                                AuthTextField(
                                    title: "Email Address",
                                    text: $email,
                                    icon: "envelope",
                                    isFocused: focusedField == .email,
                                    autocapitalization: .never
                                )
                                .focused($focusedField, equals: .email)
                                
                                // Password Field
                                AuthTextField(
                                    title: "Password",
                                    text: $password,
                                    icon: "lock",
                                    isFocused: focusedField == .password,
                                    isSecure: !showPassword,
                                    hasToggle: true,
                                    showPassword: $showPassword
                                )
                                .focused($focusedField, equals: .password)
                                
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
                                        Text("Sign In to Workspace")
                                    }
                                }
                                .buttonStyle(PrimaryButtonStyle())
                                .disabled(appViewModel.isAuthenticating)
                                .padding(.top, 8)

                                Button {
                                    appViewModel.showDemoRoles()
                                } label: {
                                    Text("Explore Demo Roles")
                                }
                                .buttonStyle(SecondaryButtonStyle())
                                .padding(.top, 8)
                            }
                        }
                    }
                    .padding(24)
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// Custom Premium Text Field Component
struct AuthTextField: View {
    let title: String
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
                .foregroundStyle(isFocused ? AppTheme.brand : AppTheme.textSecondary)
                .frame(width: 24)
            
            if isSecure {
                SecureField("", text: $text, prompt: Text(title).foregroundStyle(AppTheme.textSecondary))
                    .textInputAutocapitalization(autocapitalization)
                    .autocorrectionDisabled()
                    .foregroundStyle(AppTheme.textPrimary)
            } else {
                TextField("", text: $text, prompt: Text(title).foregroundStyle(AppTheme.textSecondary))
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
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surface.opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(isFocused ? AppTheme.brand : Color.clear, lineWidth: 1.5)
                        .shadow(color: isFocused ? AppTheme.brand.opacity(0.3) : Color.clear, radius: 4)
                )
        )
    }
}

#Preview {
    LoginView()
        .environmentObject(AppViewModel())
}
