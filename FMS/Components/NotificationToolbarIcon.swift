import SwiftUI

struct NotificationToolbarIcon: View {
  @Environment(AppViewModel.self) private var appViewModel
  var color: Color = .primary

  var body: some View {
    let unreadCount = appViewModel.unreadNotificationsCount

    ZStack(alignment: .center) {
      Image(systemName: "bell.fill")
        .foregroundStyle(color)
        .font(.system(size: 18))

      if unreadCount > 0 {
        Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
          .font(.system(size: 8, weight: .bold))
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
          .padding(.horizontal, unreadCount > 9 ? 3 : 0)
          .frame(minWidth: 14, minHeight: 14)
          .background(Capsule().fill(Color.red))
          .overlay(Capsule().stroke(Color.white, lineWidth: 1.2))
          .offset(x: 8, y: -8)
          .accessibilityHidden(true)
      }
    }
    .frame(width: 44, height: 44)
    .accessibilityLabel(
      unreadCount > 0
        ? "Notifications, \(unreadCount) unread"
        : "Notifications"
    )
  }
}
