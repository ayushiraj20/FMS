import SwiftUI

struct MFAVerificationView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var otpCode = ""
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 32) {

                    // Top Icon & Titles
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.brand.opacity(0.12))
                                .frame(width: 88, height: 88)
                            Circle()
                                .fill(AppTheme.brand.opacity(0.06))
                                .frame(width: 110, height: 110)
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(AppTheme.brand)
                        }
                        .padding(.top, 50)

                        Text("Two-Factor Authentication")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.textPrimary)

                        Text("Enter the 6-digit code from your authenticator app to complete sign in.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 12)
                    }

                    // OTP Input Card
                    VStack(spacing: 24) {

                        // Code input
                        OTPInputField(code: $otpCode, isFocused: _isCodeFocused)

                        // Error Message
                        if let error = appViewModel.mfaErrorMessage {
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

                        // Verify Button
                        Button {
                            isCodeFocused = false
                            Task {
                                await appViewModel.verifyMFA(code: otpCode)
                            }
                        } label: {
                            if appViewModel.isMFAVerifying {
                                ProgressView()
                                    .tint(.white)
                                    .frame(maxWidth: .infinity)
                            } else {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.shield.fill")
                                    Text("Verify & Sign In")
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(.vertical, 16)
                        .background(otpCode.count == 6 ? AppTheme.brand : AppTheme.textSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: AppTheme.brand.opacity(0.3), radius: 8, x: 0, y: 4)
                        .disabled(otpCode.count != 6 || appViewModel.isMFAVerifying)

                        // Cancel / Back
                        Button {
                            appViewModel.cancelMFA()
                        } label: {
                            Text("Back to Sign In")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(AppTheme.brand)
                        }
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
        .animation(.easeInOut(duration: 0.25), value: appViewModel.mfaErrorMessage != nil)
        .onAppear {
            isCodeFocused = true
        }
    }
}

// MARK: - OTP Input Field Component

struct OTPInputField: View {
    @Binding var code: String
    @FocusState var isFocused: Bool

    private let codeLength = 6

    var body: some View {
        VStack(spacing: 12) {
            // Hidden TextField for keyboard input
            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .frame(width: 0, height: 0)
                .opacity(0)
                .onChange(of: code) { _, newValue in
                    // Limit to digits only and max length
                    let filtered = String(newValue.filter { $0.isNumber }.prefix(codeLength))
                    if filtered != newValue {
                        code = filtered
                    }
                }

            // Visual digit boxes
            HStack(spacing: 10) {
                ForEach(0..<codeLength, id: \.self) { index in
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppTheme.surfaceSecondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(
                                        index == code.count && isFocused
                                            ? AppTheme.brand
                                            : (index < code.count ? AppTheme.brand.opacity(0.3) : Color.clear),
                                        lineWidth: 1.5
                                    )
                            )
                            .frame(width: 48, height: 56)

                        if index < code.count {
                            let startIndex = code.startIndex
                            let charIndex = code.index(startIndex, offsetBy: index)
                            Text(String(code[charIndex]))
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(AppTheme.textPrimary)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .animation(.spring(response: 0.2, dampingFraction: 0.7), value: code)
                }
            }
            .onTapGesture {
                isFocused = true
            }
        }
    }
}

#Preview {
    MFAVerificationView()
        .environment(AppViewModel())
}
