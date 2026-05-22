import SwiftUI

struct ProfileSettingsView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                let user = appViewModel.currentUser
                let name = user?.name ?? "Ayushi Raj"
                let email = user?.email ?? "ayushi.raj@fleetos.com"
                let phone = user?.phone ?? "+91-98765-43210"
                let title = user?.title ?? "Fleet Manager"
                
                VStack(spacing: 32) {
                    
                    // Avatar Section
                    VStack(spacing: 16) {
                        ZStack(alignment: .bottomTrailing) {
                            Circle()
                                .fill(AppTheme.brand.opacity(0.15))
                                .frame(width: 96, height: 96)
                            
                            Image(systemName: "person.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(AppTheme.brand)
                                .offset(y: -4)
                            
                            // Checkmark shield
                            ZStack {
                                Circle()
                                    .fill(AppTheme.background)
                                    .frame(width: 28, height: 28)
                                Image(systemName: "checkmark.shield.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(AppTheme.brand)
                            }
                            .offset(x: 2, y: 2)
                        }
                        
                        VStack(spacing: 8) {
                            Text(name)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            
                            Text(title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(AppTheme.brand)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 6)
                                .background(Capsule().fill(AppTheme.brand.opacity(0.15)))
                        }
                    }
                    .padding(.top, 24)
                    
                    // Info Card
                    GlassCard {
                        VStack(spacing: 16) {
                            infoRow(icon: "envelope.fill", title: "Email", value: email)
                            Divider().background(AppTheme.border).padding(.leading, 40)
                            infoRow(icon: "phone.fill", title: "Phone", value: phone)
                            Divider().background(AppTheme.border).padding(.leading, 40)
                            infoRow(icon: "checkmark.seal.fill", title: "Status", value: "Active", valueColor: AppTheme.success)
                            Divider().background(AppTheme.border).padding(.leading, 40)
                            infoRow(icon: "calendar", title: "Joined", value: "22 Jan 2026")
                        }
                    }
                    
                    // Links Card
                    GlassCard {
                        VStack(spacing: 16) {
                            linkRow(icon: "gearshape.fill", title: "Settings")
                            Divider().background(AppTheme.border).padding(.leading, 40)
                            linkRow(icon: "questionmark.circle.fill", title: "Help & Support")
                        }
                    }
                    
                    // Logout Button
                    Button {
                        appViewModel.logout()
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Logout")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(AppTheme.error)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(AppTheme.surfaceSecondary)
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(AppTheme.surfaceSecondary))
            }
        }
    }
    
    private func infoRow(icon: String, title: String, value: String, valueColor: Color = AppTheme.textPrimary) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundStyle(valueColor)
        }
    }
    
    private func linkRow(icon: String, title: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textPrimary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
}

#Preview {
    NavigationStack {
        ProfileSettingsView()
            .environment(AppViewModel())
    }
}
