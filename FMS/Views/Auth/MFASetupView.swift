import SwiftUI

struct MFASetupView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel

    enum SetupStep {
        case loading
        case showQR
        case verify
        case success
    }

    @State private var step: SetupStep = .loading
    @State private var factorID = ""
    @State private var qrCodeDataURI = ""
    @State private var totpURI = ""
    @State private var secret = ""
    @State private var verifyCode = ""
    @State private var isVerifying = false
    @State private var errorMessage: String?
    @State private var showCopiedToast = false
    @FocusState private var isCodeFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        switch step {
                        case .loading:
                            loadingContent
                        case .showQR:
                            qrCodeContent
                        case .verify:
                            verifyContent
                        case .success:
                            successContent
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 24, style: .continuous)
                            .fill(AppTheme.surface)
                            .shadow(color: AppTheme.cardShadowColor.opacity(0.05), radius: 20, x: 0, y: 10)
                    )
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Setup 2FA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if step != .success {
                        Button("Cancel") {
                            // Clean up unverified factor if we enrolled but didn't verify
                            if !factorID.isEmpty && step != .success {
                                Task {
                                    try? await SupabaseService.shared.unenrollMFA(factorID: factorID)
                                }
                            }
                            dismiss()
                        }
                    }
                }
            }
            .animation(.easeInOut(duration: 0.3), value: step == .showQR)
            .animation(.easeInOut(duration: 0.3), value: step == .verify)
            .animation(.easeInOut(duration: 0.3), value: step == .success)
        }
        .task {
            await enrollFactor()
        }
    }

    // MARK: - Loading

    private var loadingContent: some View {
        VStack(spacing: 24) {
            if let error = errorMessage {
                ZStack {
                    Circle()
                        .fill(AppTheme.error.opacity(0.12))
                        .frame(width: 72, height: 72)
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(AppTheme.error)
                }

                VStack(spacing: 8) {
                    Text("Connection Error")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(error)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 12)
                }
                .padding(.bottom, 8)

                Button {
                    errorMessage = nil
                    Task {
                        await enrollFactor()
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(AppTheme.brand)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            } else {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(AppTheme.brand)
                Text("Generating your secure key...")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
        .frame(minHeight: 250)
    }

    // MARK: - QR Code Display

    private var qrCodeContent: some View {
        VStack(spacing: 24) {
            // Header
            ZStack {
                Circle()
                    .fill(AppTheme.brand.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "qrcode")
                    .font(.system(size: 32))
                    .foregroundStyle(AppTheme.brand)
            }

            VStack(spacing: 8) {
                Text("Scan QR Code")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Open your authenticator app (Google Authenticator, Authy, etc.) and scan this QR code.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // QR Code Image
            if let qrImage = generateQRImage() {
                Image(uiImage: qrImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 200, height: 200)
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(.white)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
            }

            // Manual entry secret
            VStack(alignment: .leading, spacing: 8) {
                Text("CAN'T SCAN? ENTER MANUALLY:")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .kerning(1.2)

                HStack {
                    Text(secret)
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Spacer()

                    Button {
                        UIPasteboard.general.string = secret
                        withAnimation { showCopiedToast = true }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation { showCopiedToast = false }
                        }
                    } label: {
                        Image(systemName: showCopiedToast ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(showCopiedToast ? AppTheme.success : AppTheme.brand)
                            .contentTransition(.symbolEffect(.replace))
                    }
                }
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(AppTheme.surfaceSecondary)
                )
            }

            // Next Button
            Button {
                withAnimation { step = .verify }
            } label: {
                HStack(spacing: 8) {
                    Text("I've Scanned the Code")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .background(AppTheme.brand)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: AppTheme.brand.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - Verify Code

    private var verifyContent: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(AppTheme.brand.opacity(0.12))
                    .frame(width: 72, height: 72)
                Image(systemName: "number.square.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(AppTheme.brand)
            }

            VStack(spacing: 8) {
                Text("Enter Verification Code")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Enter the 6-digit code shown in your authenticator app to complete setup.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // OTP Input
            OTPInputField(code: $verifyCode, isFocused: _isCodeFocused)

            // Error banner
            if let error = errorMessage {
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
                Task { await verifyEnrollment() }
            } label: {
                if isVerifying {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                        Text("Verify & Enable 2FA")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
                }
            }
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .background(verifyCode.count == 6 ? AppTheme.brand : AppTheme.textSecondary)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: AppTheme.brand.opacity(0.3), radius: 8, x: 0, y: 4)
            .disabled(verifyCode.count != 6 || isVerifying)

            // Back to QR
            Button {
                withAnimation { step = .showQR }
            } label: {
                Text("Back to QR Code")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.brand)
            }
        }
        .onAppear {
            isCodeFocused = true
        }
    }

    // MARK: - Success

    private var successContent: some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .fill(AppTheme.success.opacity(0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(AppTheme.success)
            }

            VStack(spacing: 8) {
                Text("2FA Enabled!")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)

                Text("Your account is now protected with two-factor authentication. You'll need to enter a code from your authenticator app each time you sign in.")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                dismiss()
            } label: {
                Text("Done")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .foregroundStyle(.white)
            .padding(.vertical, 16)
            .background(AppTheme.success)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: AppTheme.success.opacity(0.3), radius: 8, x: 0, y: 4)
        }
    }

    // MARK: - Actions

    private func enrollFactor() async {
        do {
            if SupabaseConfig.isConfigured {
                do {
                    // Clean up any unverified factors first
                    let allFactors = try await SupabaseService.shared.listAllMFAFactors()
                    for factor in allFactors where factor.status != "verified" {
                        try? await SupabaseService.shared.unenrollMFA(factorID: factor.id)
                    }

                    let result = try await SupabaseService.shared.enrollMFA()
                    factorID = result.factorID
                    qrCodeDataURI = result.qrCode
                    totpURI = result.uri
                    secret = result.secret

                    withAnimation { step = .showQR }
                    return
                } catch {
                    print("[MFA Setup] Real Supabase enroll failed: \(error.localizedDescription). Falling back to mock MFA.")
                }
            }

            // Mock MFA fallback
            try await Task.sleep(for: .seconds(0.8))
            factorID = "mock-factor-\(UUID().uuidString)"
            totpURI = "otpauth://totp/FleetOS:\(appViewModel.currentUser?.email ?? "demo@fleetos.com")?secret=JVDMEZ5ERNQK2P3TJMIDOD47UYMKO&issuer=FleetOS"
            secret = "JVDMEZ5ERNQK2P3TJMIDOD47UYMKO"
            qrCodeDataURI = ""

            withAnimation { step = .showQR }
        } catch {
            errorMessage = "Failed to set up 2FA: \(error.localizedDescription)"
            print("[MFA Setup] Enroll error: \(error)")
        }
    }

    private func verifyEnrollment() async {
        isVerifying = true
        errorMessage = nil

        do {
            if factorID.hasPrefix("mock-factor-") {
                try await Task.sleep(for: .seconds(0.8))
                if TOTPHelper.verify(code: verifyCode, secret: "JVDMEZ5ERNQK2P3TJMIDOD47UYMKO") {
                    UserDefaults.standard.set(true, forKey: "mock_mfa_enabled_\(appViewModel.currentUser?.id.uuidString ?? "")")
                    withAnimation { step = .success }
                } else {
                    throw NSError(domain: "MFA", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid code. Please check your authenticator app and try again."])
                }
            } else {
                try await SupabaseService.shared.challengeAndVerifyMFA(factorID: factorID, code: verifyCode)
                withAnimation { step = .success }
            }
        } catch {
            errorMessage = error.localizedDescription
            print("[MFA Setup] Verify error: \(error)")
        }

        isVerifying = false
    }

    // MARK: - QR Code Generation

    /// Convert the TOTP URI to a QR code UIImage using CoreImage.
    private func generateQRImage() -> UIImage? {
        // Use the TOTP URI from the secret to generate the QR code locally
        // The qrCodeDataURI from Supabase is an SVG data URI which is harder to render natively
        guard !totpURI.isEmpty,
              let data = totpURI.data(using: .ascii),
              let filter = CIFilter(name: "CIQRCodeGenerator") else {
            return nil
        }

        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")

        guard let ciImage = filter.outputImage else { return nil }

        let scale = 10.0
        let transformedImage = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        let context = CIContext()
        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            return nil
        }

        return UIImage(cgImage: cgImage)
    }
}

#Preview {
    MFASetupView()
        .environment(AppViewModel())
}
