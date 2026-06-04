import UIKit

enum HapticFeedback {
    /// Strong feedback when a route geofence breach notification is raised on this device.
    static func routeCorridorBreach() {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(.error)
    }
}
