import UIKit

enum HapticFeedback {
    /// Strong feedback when a route geofence breach notification is raised on this device.
    static func routeCorridorBreach() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
    
    static func play(for category: NotificationCategory) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        switch category {
        case .info, .maintenance:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .warning:
            generator.notificationOccurred(.warning)
        case .critical:
            generator.notificationOccurred(.error)
        case .success:
            generator.notificationOccurred(.success)
        }
    }
}
