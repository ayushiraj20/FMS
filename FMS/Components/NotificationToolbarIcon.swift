import SwiftUI

struct NotificationToolbarIcon: View {
  @Environment(AppViewModel.self) private var appViewModel

  var body: some View {
    let unreadCount = appViewModel.unreadNotificationsCount

    ZStack(alignment: .center) {
      Image(systemName: "bell.fill")

      if unreadCount > 0 {
        Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
          .font(.system(size: 11, weight: .semibold, design: .rounded))
          .foregroundStyle(.white)
          .padding(.horizontal, 4)
          .frame(minWidth: 16, minHeight: 16)
          .background(Color(uiColor: .systemRed), in: Capsule())
          .overlay(Capsule().stroke(Color.white, lineWidth: 1.5))
          .offset(x: 10, y: -10)
          .accessibilityHidden(true)
      }
    }
    .frame(width: 24, height: 24)
    .padding(10)
    .accessibilityLabel(
      unreadCount > 0
        ? "Notifications, \(unreadCount) unread"
        : "Notifications"
    )
  }
}
