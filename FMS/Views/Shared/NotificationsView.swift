import SwiftUI

struct NotificationsView: View {

    @Environment(AppViewModel.self)
    private var appViewModel

    var body: some View {

        List {

            ForEach(
                appViewModel.notifications
            ) { notification in

                GlassCard {

                    HStack(
                        alignment: .top,
                        spacing: 14
                    ) {

                        if !notification.isRead {
                            Circle()
                                .fill(
                                    color(
                                        for: notification.category
                                    )
                                )
                                .frame(
                                    width: 10,
                                    height: 10
                                )
                                .padding(.top, 7)
                        } else {
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 10, height: 10)
                                .padding(.top, 7)
                        }

                        VStack(
                            alignment: .leading,
                            spacing: 6
                        ) {

                            Text(
                                notification.title
                            )
                            .font(.headline)
                            .foregroundStyle(
                                AppTheme.textPrimary
                            )

                            Text(
                                notification.message
                            )
                            .font(.subheadline)
                            .foregroundStyle(
                                AppTheme.textSecondary
                            )

                            Text(
                                notification.date.formatted(
                                    date: .abbreviated,
                                    time: .shortened
                                )
                            )
                            .font(.footnote)
                            .foregroundStyle(
                                AppTheme.textSecondary
                                    .opacity(0.8)
                            )
                        }

                        Spacer()

                        if !notification.isRead {

                            Button(
                                "Mark Read"
                            ) {

                                appViewModel.service.markNotificationRead(notification)
                                appViewModel.notifications = appViewModel.service.notifications(for: appViewModel.currentUser)
                            }
                            .font(
                                .caption.weight(
                                    .semibold
                                )
                            )
                            .foregroundStyle(
                                AppTheme.brand
                            )
                        }
                    }
                }
                .listRowBackground(
                    Color.clear
                )
                .listRowSeparator(
                    .hidden
                )
            }
        }
        .appListStyle()
        .navigationTitle(
            "Notifications"
        )
        .toolbar(
            .visible,
            for: .navigationBar
        )

        .task {
            // Always reload notifications for the current logged-in user when this screen opens
            await appViewModel.loadNotifications()
        }

    }

    private func color(
        for category: NotificationCategory
    ) -> Color {

        switch category {

        case .info:
            return AppTheme.brand

        case .warning:
            return AppTheme.warning

        case .critical:
            return AppTheme.error

        case .success:
            return AppTheme.success

        case .maintenance:
            return Color.orange
        }
    }
}

#Preview {

    NavigationStack {

        NotificationsView()
            .environment(
                AppViewModel()
            )
    }
}
