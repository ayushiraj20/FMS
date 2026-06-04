import SwiftUI

struct NotificationToolbarIcon: View {
  @Environment(AppViewModel.self) private var appViewModel

  var body: some View {
    let unreadCount = appViewModel.unreadNotificationsCount

    Image(systemName: "bell.fill")
      .imageScale(.large)
      .frame(width: 32, height: 32)
      .overlay(alignment: .topTrailing) {
        if unreadCount > 0 {
          Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, unreadCount > 9 ? 4 : 3)
            .frame(minWidth: 14, minHeight: 14)
            .background(Capsule().fill(Color.red))
            .overlay(Capsule().stroke(Color.white, lineWidth: 1.0))
            .offset(x: -2, y: 2)
            .accessibilityHidden(true)
        }
      }
      .accessibilityLabel(
        unreadCount > 0
          ? "Notifications, \(unreadCount) unread"
          : "Notifications"
      )
  }
}
