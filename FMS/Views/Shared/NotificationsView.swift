import SwiftUI

struct NotificationsView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var selectedFilter: NotificationFilter = .all

    enum NotificationFilter: String, CaseIterable {
        case all = "All"
        case unread = "Unread"
    }

    var filteredNotifications: [AppNotification] {
        switch selectedFilter {
        case .all:
            return appViewModel.notifications
        case .unread:
            return appViewModel.notifications.filter { !$0.isRead }
        }
    }

    var body: some View {
        ZStack {
            DriverScreenBackground()
            
            VStack(spacing: 0) {
                // iOS-style Segmented Control & Action Header
                VStack(spacing: 12) {
                    HStack {
                        Picker("Filter", selection: $selectedFilter.animation(.spring(response: 0.25, dampingFraction: 0.8))) {
                            ForEach(NotificationFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 160)
                        
                        Spacer()
                        
                        if appViewModel.unreadNotificationsCount > 0 {
                            Button {
                                Task {
                                    for notification in appViewModel.notifications.filter({ !$0.isRead }) {
                                        await appViewModel.markNotificationAsRead(id: notification.id)
                                    }
                                }
                            } label: {
                                Text("Mark All Read")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(DriverTheme.accent)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    Divider()
                }
                .background(Color.clear)

                if filteredNotifications.isEmpty {
                    // Clean Native Empty State
                    ContentUnavailableView {
                        Label(
                            selectedFilter == .all ? "No Notifications" : "No Unread Notifications",
                            systemImage: selectedFilter == .all ? "bell.slash.fill" : "bell.badge.slash.fill"
                        )
                    } description: {
                        Text("You're completely up to date. New duty alerts will appear here.")
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    // Native List with clean swipe and tap behaviors
                    List {
                        ForEach(filteredNotifications) { notification in
                            Button {
                                if !notification.isRead {
                                    Task {
                                        await appViewModel.markNotificationAsRead(id: notification.id)
                                    }
                                }
                            } label: {
                                HStack(alignment: .top, spacing: 12) {
                                    // Unread Dot Indicator
                                    Circle()
                                        .fill(notification.isRead ? Color.clear : DriverTheme.accent)
                                        .frame(width: 8, height: 8)
                                        .padding(.top, 8)
                                    
                                    // Category Icon
                                    Image(systemName: iconName(for: notification.category))
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 28, height: 28)
                                        .background(color(for: notification.category), in: Circle())
                                        .padding(.top, 2)

                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(alignment: .top) {
                                            Text(notification.title)
                                                .font(.system(size: 16, weight: notification.isRead ? .semibold : .bold))
                                                .foregroundStyle(DriverTheme.textPrimary)
                                                .lineLimit(1)
                                            
                                            Spacer()
                                            
                                            Text(notification.date.formatted(.dateTime.hour().minute()))
                                                .font(.system(size: 12, weight: .regular))
                                                .foregroundStyle(DriverTheme.textSecondary.opacity(0.8))
                                        }
                                        
                                        Text(notification.message)
                                            .font(.system(size: 14))
                                            .foregroundStyle(DriverTheme.textSecondary)
                                            .lineLimit(3)
                                            .multilineTextAlignment(.leading)
                                    }
                                }
                                .padding(.vertical, 4)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(DriverTheme.accent.opacity(0.15))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await appViewModel.loadNotifications()
        }
    }

    private func color(for category: NotificationCategory) -> Color {
        switch category {
        case .info:
            return DriverTheme.accent
        case .warning:
            return DriverTheme.warningAmber
        case .critical:
            return DriverTheme.criticalRed
        case .success:
            return DriverTheme.successGreen
        case .maintenance:
            return DriverTheme.accent
        }
    }

    private func iconName(for category: NotificationCategory) -> String {
        switch category {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .critical:
            return "exclamationmark.octagon.fill"
        case .success:
            return "checkmark.circle.fill"
        case .maintenance:
            return "wrench.and.screwdriver.fill"
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
            .environment(AppViewModel())
    }
}
