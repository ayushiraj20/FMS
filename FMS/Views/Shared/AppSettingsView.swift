import SwiftUI

struct AppSettingsView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var cacheCleared = false
    @State private var isSyncing = false
    @State private var selectedSyncInterval = "Every 15 mins"

    // MFA state
    @State private var isMFAEnabled = false
    @State private var isCheckingMFA = false
    @State private var isShowingMFASetup = false
    @State private var isShowingMFADisableAlert = false
    @State private var mfaFactorID: String?
    @State private var isDisablingMFA = false
    
    let syncIntervals = ["Real-time", "Every 15 mins", "Every hour", "Manual"]
    
    var body: some View {
        @Bindable var viewModel = appViewModel
        
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // Notification Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notifications")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(roleColor.opacity(0.8))
                            .padding(.leading, 8)
                        
                        GlassCard {
                            VStack(spacing: 16) {
                                Toggle(isOn: $viewModel.profileNotificationsEnabled) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "bell.badge.fill")
                                            .foregroundStyle(roleColor)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Enable Notifications")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(AppTheme.textPrimary)
                                            Text("Get alerts for assigned work orders and safety notifications")
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.textSecondary)
                                        }
                                    }
                                }
                                .tint(roleColor)
                                
                                if viewModel.profileNotificationsEnabled {
                                    Divider().background(AppTheme.border)
                                    
                                    Toggle(isOn: .constant(true)) {
                                        HStack(spacing: 12) {
                                            Image(systemName: "exclamationmark.triangle.fill")
                                                .foregroundStyle(.orange)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text("Critical Alerts")
                                                    .font(.subheadline.weight(.semibold))
                                                    .foregroundStyle(AppTheme.textPrimary)
                                                Text("Always receive sound alerts for critical vehicle defects")
                                                    .font(.caption)
                                                    .foregroundStyle(AppTheme.textSecondary)
                                            }
                                        }
                                    }
                                    .tint(roleColor)
                                    .disabled(true)
                                }
                            }
                        }
                    }
                    
                    // Security Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Security & Access")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(roleColor.opacity(0.8))
                            .padding(.leading, 8)
                        
                        GlassCard {
                            VStack(spacing: 16) {
                                HStack(spacing: 12) {
                                    Image(systemName: "lock.shield.fill")
                                        .foregroundStyle(isMFAEnabled ? AppTheme.success : roleColor)
                                        .frame(width: 20)

                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 6) {
                                            Text("Two-Factor Authentication")
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(AppTheme.textPrimary)

                                            if isMFAEnabled {
                                                Text("ON")
                                                    .font(.system(size: 9, weight: .heavy))
                                                    .foregroundStyle(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(AppTheme.success)
                                                    .clipShape(Capsule())
                                            }
                                        }

                                        Text(isMFAEnabled
                                             ? "Your account is protected with TOTP"
                                             : "Add an extra layer of security to your account")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }

                                    Spacer()

                                    if isCheckingMFA || isDisablingMFA {
                                        ProgressView()
                                            .tint(roleColor)
                                    } else {
                                        Button {
                                            if isMFAEnabled {
                                                isShowingMFADisableAlert = true
                                            } else {
                                                isShowingMFASetup = true
                                            }
                                        } label: {
                                            Text(isMFAEnabled ? "Disable" : "Enable")
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(isMFAEnabled ? AppTheme.error : roleColor)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 7)
                                                .background(
                                                    Capsule()
                                                        .fill((isMFAEnabled ? AppTheme.error : roleColor).opacity(0.12))
                                                )
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // Workshop Database Sync Settings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Database & Offline Sync")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(roleColor.opacity(0.8))
                            .padding(.leading, 8)
                        
                        GlassCard {
                            VStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "arrow.triangle.2.circlepath")
                                        .foregroundStyle(roleColor)
                                    Text("Sync Interval")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                    Picker("Interval", selection: $selectedSyncInterval) {
                                        ForEach(syncIntervals, id: \.self) { interval in
                                            Text(interval)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .tint(roleColor)
                                }
                                
                                Divider().background(AppTheme.border)
                                
                                Button {
                                    runSync()
                                } label: {
                                    HStack {
                                        if isSyncing {
                                            ProgressView()
                                                .tint(roleColor)
                                                .padding(.trailing, 8)
                                        } else {
                                            Image(systemName: "icloud.and.arrow.down.fill")
                                                .foregroundStyle(roleColor)
                                        }
                                        Text(isSyncing ? "Syncing..." : "Sync Database Now")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(roleColor)
                                        Spacer()
                                    }
                                }
                                .disabled(isSyncing)
                                
                                Divider().background(AppTheme.border)
                                
                                Button {
                                    clearAppCache()
                                } label: {
                                    HStack {
                                        Image(systemName: "trash.fill")
                                            .foregroundStyle(AppTheme.error)
                                        Text(cacheCleared ? "Cache Cleared" : "Clear Local Cache")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(cacheCleared ? AppTheme.textSecondary : AppTheme.error)
                                        Spacer()
                                        if !cacheCleared {
                                            Text("14.2 MB")
                                                .font(.caption)
                                                .foregroundStyle(AppTheme.textSecondary)
                                        }
                                    }
                                }
                                .disabled(cacheCleared)
                            }
                        }
                    }
                    
                    // Device Info Section
                    VStack(spacing: 8) {
                        Text("\(AppBranding.name) \(appVersionLabel)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text("Organization: \(viewModel.organizationName)")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text("Role: \(viewModel.currentUser?.role.rawValue ?? "Unknown")")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    .padding(.top, 16)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkMFAStatus()
        }
        .sheet(isPresented: $isShowingMFASetup) {
            MFASetupView()
                .environment(appViewModel)
                .onDisappear {
                    // Refresh MFA status after setup sheet closes
                    checkMFAStatus()
                }
        }
        .alert("Disable Two-Factor Authentication", isPresented: $isShowingMFADisableAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Disable", role: .destructive) {
                disableMFA()
            }
        } message: {
            Text("Are you sure you want to disable two-factor authentication? Your account will be less secure.")
        }
    }
    
    private var appVersionLabel: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version) (\(build))"
    }

    private var roleColor: Color {
        guard let role = appViewModel.currentUser?.role else {
            return AppTheme.brand
        }
        switch role {
        case .fleetManager:
            return AppTheme.brand
        case .driver:
            return Color(hex: "FD5D23")
        case .maintenance:
            return Color(hex: "#FF9500")
        }
    }
    
    private func runSync() {
        isSyncing = true
        Task {
            await appViewModel.service.syncWithDatabase()
            try? await Task.sleep(for: .seconds(1.0))
            isSyncing = false
        }
    }
    
    private func clearAppCache() {
        cacheCleared = true
    }

    // MARK: - MFA Helpers

    private func checkMFAStatus() {
        isCheckingMFA = true
        Task {
            let mockEnabled = UserDefaults.standard.bool(forKey: "mock_mfa_enabled_\(appViewModel.currentUser?.id.uuidString ?? "")")
            
            if SupabaseConfig.isConfigured {
                do {
                    let factors = try await SupabaseService.shared.listVerifiedMFAFactors()
                    isMFAEnabled = !factors.isEmpty || mockEnabled
                    mfaFactorID = factors.first?.id ?? (mockEnabled ? "mock-factor-\(appViewModel.currentUser?.id.uuidString ?? "")" : nil)
                } catch {
                    print("[Settings] Failed to check MFA status: \(error)")
                    isMFAEnabled = mockEnabled
                    mfaFactorID = mockEnabled ? "mock-factor-\(appViewModel.currentUser?.id.uuidString ?? "")" : nil
                }
            } else {
                isMFAEnabled = mockEnabled
                mfaFactorID = mockEnabled ? "mock-factor-\(appViewModel.currentUser?.id.uuidString ?? "")" : nil
            }
            isCheckingMFA = false
        }
    }

    private func disableMFA() {
        guard let factorID = mfaFactorID else { return }
        isDisablingMFA = true
        Task {
            UserDefaults.standard.set(false, forKey: "mock_mfa_enabled_\(appViewModel.currentUser?.id.uuidString ?? "")")
            
            if !factorID.hasPrefix("mock-factor-") && SupabaseConfig.isConfigured {
                do {
                    try await SupabaseService.shared.unenrollMFA(factorID: factorID)
                    print("[Settings] Real Supabase MFA disabled successfully ✅")
                } catch {
                    print("[Settings] Failed to disable real MFA: \(error)")
                }
            }
            
            isMFAEnabled = false
            mfaFactorID = nil
            isDisablingMFA = false
        }
    }
}

#Preview {
    NavigationStack {
        AppSettingsView()
            .environment(AppViewModel())
    }
}
