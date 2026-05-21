import SwiftUI

struct NotificationsView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        List {
            ForEach(appViewModel.service.notifications(for: appViewModel.currentUser)) { notification in
                GlassCard {
                    HStack(alignment: .top, spacing: 14) {
                        Circle()
                            .fill(color(for: notification.category))
                            .frame(width: 10, height: 10)
                            .padding(.top, 7)

                        VStack(alignment: .leading, spacing: 6) {
                            Text(notification.title)
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(notification.message)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                            Text(notification.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.footnote)
                                .foregroundStyle(AppTheme.textSecondary.opacity(0.8))
                        }

                        Spacer()

                        if !notification.isRead {
                            Button("Mark Read") {
                                appViewModel.service.markNotificationRead(notification)
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.brand)
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .appListStyle()
        .navigationTitle("Notifications")
    }

    private func color(for category: NotificationCategory) -> Color {
        switch category {
        case .info: AppTheme.brand
        case .warning: AppTheme.warning
        case .critical: AppTheme.error
        case .success: AppTheme.success
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
            .environmentObject(AppViewModel())
    }
}
