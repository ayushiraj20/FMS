import SwiftUI

struct AppSettingsView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var cacheCleared = false
    @State private var isSyncing = false
    @State private var selectedSyncInterval = "Every 15 mins"
    
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
                            Toggle(isOn: $viewModel.biometricUnlockEnabled) {
                                HStack(spacing: 12) {
                                    Image(systemName: "faceid")
                                        .foregroundStyle(roleColor)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Biometric Unlock")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Text("Use Face ID or Touch ID to access FleetOS")
                                            .font(.caption)
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                }
                            }
                            .tint(roleColor)
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
                                    .accentColor(roleColor)
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
                        Text("FleetOS v2.4.0 (Build 108)")
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
            return Color(hex: "#FF5A1F")
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
}

#Preview {
    NavigationStack {
        AppSettingsView()
            .environment(AppViewModel())
    }
}
