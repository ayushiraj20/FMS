import SwiftUI

struct NotificationToolbarIcon: View {
  @Environment(AppViewModel.self) private var appViewModel

  var body: some View {
    let unreadCount = appViewModel.unreadNotificationsCount

    ZStack(alignment: .topTrailing) {
      Image(systemName: "bell.fill")
        .padding(.top, 8)
        .padding(.trailing, 4)

      if unreadCount > 0 {
        Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
          .font(.system(size: 9, weight: .bold))
          .foregroundStyle(.white)
          .lineLimit(1)
          .minimumScaleFactor(0.8)
          .padding(.horizontal, unreadCount > 9 ? 5 : 4)
          .frame(minWidth: 12, minHeight: 14)
          .background(Capsule().fill(Color.red))
          .overlay(Capsule().stroke(Color.white, lineWidth: 1.2))
          .offset(x: 2, y: 2)
          .accessibilityHidden(true)
      }
    }
    .padding(2)
    .accessibilityLabel(
      unreadCount > 0
        ? "Notifications, \(unreadCount) unread"
        : "Notifications"
    )
  }
}
