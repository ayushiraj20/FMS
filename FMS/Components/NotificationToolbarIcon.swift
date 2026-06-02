import SwiftUI

struct NotificationToolbarIcon: View {
  @Environment(AppViewModel.self) private var appViewModel

  var body: some View {
    let unreadCount = appViewModel.unreadNotificationsCount

    ZStack(alignment: .topTrailing) {
      Image(systemName: "bell.fill")

      if unreadCount > 0 {
        Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .padding(.horizontal, unreadCount > 9 ? 4 : 0)
          .frame(minWidth: 16, minHeight: 16)
          .background(Capsule().fill(Color.red))
          .overlay(Capsule().stroke(Color.white, lineWidth: 1.5))
          .offset(x: 8, y: -8)
          .accessibilityHidden(true)
      }
    }
    .padding(10)
    .accessibilityLabel(
      unreadCount > 0
        ? "Notifications, \(unreadCount) unread"
        : "Notifications"
    )
  }
}
