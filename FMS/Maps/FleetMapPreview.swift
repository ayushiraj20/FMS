import MapKit
import SwiftUI

struct FleetMapPreview: View {
    let locations: [FleetVehicleLocation]
    var initialRegion = FleetMapRegion.india
    var geofence: FleetGeofence?
    var geofenceBreaches: [FleetGeofenceBreach] = []
    @State private var selectedLocation: FleetVehicleLocation?

    var body: some View {
        Map(initialPosition: .region(initialRegion), interactionModes: []) {
            if let geofence {
                MapCircle(center: geofence.center, radius: geofence.radiusMeters)
                    .foregroundStyle(Color.orange.opacity(0.3))

                MapCircle(center: geofence.center, radius: geofence.radiusMeters)
                    .stroke(Color.accentColor.opacity(0.85), lineWidth: 2)

                Annotation(geofence.centerName, coordinate: geofence.center) {
                    Image(systemName: "building.2.crop.circle.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(6)
                        .background(.background, in: Circle())
                }
            }

            ForEach(locations) { location in
                Annotation(location.vehicle.displayName, coordinate: location.coordinate) {
                    Button {
                        selectedLocation = location
                    } label: {
                        FleetMapPinView(location: location, isCompact: true, isBreaching: isBreaching(location))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .sheet(item: $selectedLocation) { location in
            FleetVehicleDetailSheet(location: location)
                .presentationDetents([.medium, .large])
        }
    }

    private func isBreaching(_ location: FleetVehicleLocation) -> Bool {
        geofenceBreaches.contains { $0.id == location.id }
    }
}
