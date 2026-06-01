import SwiftUI

struct NotificationToolbarIcon: View {
  @Environment(AppViewModel.self) private var appViewModel

  var body: some View {
    ZStack(alignment: .topTrailing) {
      Image(systemName: appViewModel.unreadNotificationsCount > 0 ? "bell.badge.fill" : "bell.fill")

      if appViewModel.unreadNotificationsCount > 0 {
        Circle()
          .fill(Color.red)
          .frame(width: 9, height: 9)
          .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
          .offset(x: 4, y: -4)
          .accessibilityHidden(true)
      }
    }
    .accessibilityLabel(
      appViewModel.unreadNotificationsCount > 0
        ? "Notifications, \(appViewModel.unreadNotificationsCount) unread"
        : "Notifications"
    )
  }
}
