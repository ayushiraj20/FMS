import SwiftUI

struct NotificationsView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        let unreadNotifications = appViewModel.notifications.filter { !$0.isRead }
        
        List {
            if unreadNotifications.isEmpty {
                EmptyStateView(
                    icon: "bell.slash",
                    title: "All Caught Up!",
                    message: "You have no unread notifications at the moment."
                )
                .listRowSeparator(.hidden)
                .listRowBackground(Color.clear)
            } else {
                ForEach(unreadNotifications) { notification in
                    HStack(alignment: .top, spacing: 14) {
                        Circle()
                            .fill(AppTheme.brand)
                            .frame(width: 8, height: 8)
                            .padding(.top, 7)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(notification.title)
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)

                            Text(notification.message)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                                .padding(.bottom, 2)

                            Text(notification.date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary.opacity(0.8))
                        }
                    }
                    .padding(.vertical, 6)
                    .listRowBackground(AppTheme.cardBackground)
                    .listRowSeparatorTint(AppTheme.border)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                            appViewModel.service.markNotificationRead(notification)
                            appViewModel.notifications = appViewModel.service.notifications(for: appViewModel.currentUser)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(AppTheme.background)
        .scrollContentBackground(.hidden)
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .task {
            await appViewModel.loadNotifications()
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
            .environment(AppViewModel())
    }
}
