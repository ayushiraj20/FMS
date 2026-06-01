import SwiftUI

struct FleetMapPinView: View {
    let location: FleetVehicleLocation
    var isCompact = false
    var isBreaching = false

    private var pinTint: Color {
        isBreaching ? AppTheme.error : location.statusColor
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VehicleMapMarker(
                symbolName: location.vehicle.fleetMapSymbolName,
                tint: pinTint,
                isMoving: location.isMoving,
                size: isCompact ? 22 : 28
            )

            if isBreaching {
                Image(systemName: "exclamationmark")
                    .font(.system(size: isCompact ? 8 : 10, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: isCompact ? 14 : 16, height: isCompact ? 14 : 16)
                    .background(AppTheme.error, in: Circle())
                    .offset(x: 3, y: -3)
            }
        }
        .accessibilityLabel("\(location.vehicle.displayName), \(location.vehicle.vehicleType), \(location.vehicle.status.rawValue)\(isBreaching ? ", route breach" : "")")
    }
}
