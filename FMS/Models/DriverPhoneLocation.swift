import CoreLocation
import Foundation

/// Live GPS fix from the driver's phone while the app is tracking location.
struct DriverPhoneLocation {
    let coordinate: CLLocationCoordinate2D
    let timestamp: Date
    let speedMetersPerSecond: Double
    let horizontalAccuracy: CLLocationAccuracy

    var isFresh: Bool {
        Date.now.timeIntervalSince(timestamp) <= 300
    }

    var hasUsableAccuracy: Bool {
        horizontalAccuracy >= 0 && horizontalAccuracy <= 120
    }

    /// Roughly 3 km/h — stationary drivers should not trigger corridor breaches.
    var isMoving: Bool {
        speedMetersPerSecond > 0.85
    }
}
