import SwiftUI

struct NotificationToolbarIcon: View {
  @Environment(AppViewModel.self) private var appViewModel

  var body: some View {
    let unreadCount = appViewModel.unreadNotificationsCount

    ZStack(alignment: .center) {
      // Base frame to prevent clipping of the badge by container bounds
      Color.clear
        .frame(width: 36, height: 36)

      Image(systemName: "bell.fill")
        .font(.system(size: 18, weight: .medium))
        .foregroundStyle(AppTheme.textPrimary)

      if unreadCount > 0 {
        Text(unreadCount > 99 ? "99+" : "\(unreadCount)")
          .font(.system(size: 10, weight: .bold, design: .rounded))
          .foregroundStyle(.white)
          .lineLimit(1)
          .padding(.horizontal, unreadCount > 9 ? 5 : 5)
          .frame(minWidth: 18, minHeight: 18)
          .background(Color.red, in: Capsule())
          .overlay(
            Capsule()
              .stroke(Color(uiColor: .systemBackground), lineWidth: 1.5)
          )
          .offset(x: 9, y: -9)
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

