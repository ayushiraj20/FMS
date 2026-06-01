import SwiftUI

struct DemoRoleSelectionView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                Text(AppBranding.name)
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundStyle(AppTheme.textPrimary)
                    .padding(.top, 24)

                Text("Sign in with a role-specific account from your organization to access \(AppBranding.name).")
                    .foregroundStyle(AppTheme.textSecondary)

                if let err = appViewModel.authErrorMessage {
                    Text(err)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                        .padding(.top, 8)
                }

                if appViewModel.isAuthenticating {
                    Spacer()
                    HStack {
                        Spacer()
                        VStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.large)
                            Text("Connecting to Supabase...")
                                .font(.headline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                    }
                    Spacer()
                } else {
                    ForEach(UserRole.allCases) { role in
                        Button {
                            appViewModel.loginAsDemo(role: role)
                        } label: {
                            GlassCard {
                                HStack(spacing: 16) {
                                    Image(systemName: role.iconName)
                                        .font(.title2)
                                        .foregroundStyle(AppTheme.brand)
                                        .frame(width: 46, height: 46)
                                        .background(AppTheme.brand.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                                    VStack(alignment: .leading, spacing: 6) {
                                        Text(role.rawValue)
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Text(role == .fleetManager ? "Manage users, vehicles, documents, and work orders." : role == .driver ? "Run inspections, view documents, and manage trips." : "Handle maintenance schedules and repair execution.")
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: "arrow.right")
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }

                Button("Back to Login") {
                    appViewModel.flowState = .login
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 24)
        }
    }
}

#Preview {
    DemoRoleSelectionView()
        .environment(AppViewModel())
}
