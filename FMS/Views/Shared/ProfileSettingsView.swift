import SwiftUI

struct ProfileSettingsView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        List {
            if let user = appViewModel.currentUser {
                Section {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(user.name)
                                        .font(.title3.weight(.bold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text(user.title)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }

                                Spacer()
                                RoleBadgeView(role: user.role)
                            }

                            infoRow(title: "Email", value: user.email)
                            infoRow(title: "Phone", value: user.phone)
                            infoRow(title: "Organization", value: appViewModel.currentOrganization?.name ?? appViewModel.organizationName)
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                Toggle("Push Notifications", isOn: $appViewModel.profileNotificationsEnabled)
                Toggle("Biometric Unlock", isOn: $appViewModel.biometricUnlockEnabled)
            } header: {
                Text("Preferences")
            }

            Section {
                NavigationLink("View Notifications", destination: NotificationsView())
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Section {
                Button("Log Out", role: .destructive) {
                    appViewModel.logout()
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.clear)
        .navigationTitle("Profile & Settings")
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .foregroundStyle(AppTheme.textPrimary)
        }
        .font(.subheadline)
    }
}

#Preview {
    NavigationStack {
        ProfileSettingsView()
            .environmentObject(AppViewModel())
    }
}
