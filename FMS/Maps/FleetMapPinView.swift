import SwiftUI

struct FleetMapPinView: View {
    let location: FleetVehicleLocation
    var isCompact = false

    var body: some View {
        Image(systemName: "car.fill")
            .font(.system(size: isCompact ? 22 : 28, weight: .semibold))
            .foregroundStyle(location.statusColor)
            .padding(isCompact ? 7 : 9)
            .background(.background, in: Circle())
            .overlay(
                Circle()
                    .stroke(location.statusColor, lineWidth: 1)
            )
            .accessibilityLabel("\(location.vehicle.displayName), \(location.vehicle.status.rawValue)")
    }
}
