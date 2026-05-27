import SwiftUI

struct FleetMapPinView: View {
    let location: FleetVehicleLocation
    var isCompact = false
    var isBreaching = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "car.fill")
                .font(.system(size: isCompact ? 22 : 28, weight: .semibold))
                .foregroundStyle(isBreaching ? AppTheme.error : location.statusColor)
                .padding(isCompact ? 7 : 9)
                .background(.background, in: Circle())
                .overlay(
                    Circle()
                        .stroke(isBreaching ? AppTheme.error : location.statusColor, lineWidth: isBreaching ? 2 : 1)
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
        .accessibilityLabel("\(location.vehicle.displayName), \(location.vehicle.status.rawValue)\(isBreaching ? ", geofence breach" : "")")
    }
}
