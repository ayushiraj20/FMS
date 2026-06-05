import SwiftUI

struct InAppNotificationBanner: View {
    let notification: AppNotification
    let onDismiss: () -> Void
    let onTap: () -> Void

    var body: some View {
        VStack {
            Button(action: onTap) {
                HStack(alignment: .top, spacing: 12) {
                    // Category Icon
                    Image(systemName: iconName(for: notification.category))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(color(for: notification.category), in: Circle())
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(notification.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.primary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(1)
                        
                        Text(notification.message)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color.secondary)
                            .multilineTextAlignment(.leading)
                            .lineLimit(2)
                    }
                    
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.regularMaterial)
                        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
                )
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16) // Will safely sit below safe area dynamically based on placement
        .transition(.move(edge: .top).combined(with: .opacity))
        // Swipe up to dismiss
        .gesture(
            DragGesture(minimumDistance: 10, coordinateSpace: .local)
                .onEnded { value in
                    if value.translation.height < 0 {
                        onDismiss()
                    }
                }
        )
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
