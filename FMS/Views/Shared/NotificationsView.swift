import SwiftUI

struct NotificationsView: View {

    @Environment(AppViewModel.self)
    private var appViewModel

    var body: some View {
        List {
            ForEach(appViewModel.notifications) { notification in
                HStack(alignment: .top, spacing: 14) {
                    if !notification.isRead {
                        Circle()
                            .fill(Color(.systemBlue))
                            .frame(width: 10, height: 10)
                            .padding(.top, 7)
                    } else {
                        Circle()
                            .fill(Color.clear)
                            .frame(width: 10, height: 10)
                            .padding(.top, 7)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(notification.title)
                            .font(.headline)
                            .foregroundStyle(Color(.label))

                        Text(notification.message)
                            .font(.subheadline)
                            .foregroundStyle(Color(.secondaryLabel))
                            .padding(.bottom, 2)

                        Text(notification.date.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(Color(.tertiaryLabel))
                    }
                }
                .padding(.vertical, 4)
                .listRowBackground(Color(.secondarySystemBackground))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    if !notification.isRead {
                        Button {
                            appViewModel.service.markNotificationRead(notification)
                            appViewModel.notifications = appViewModel.service.notifications(for: appViewModel.currentUser)
                        } label: {
                            Label("Mark Read", systemImage: "checkmark")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .background(Color(.systemBackground))
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
            .environment(
                AppViewModel()
            )
    }
}
