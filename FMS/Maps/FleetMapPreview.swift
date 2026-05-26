import MapKit
import SwiftUI

struct FleetMapPreview: View {
    let locations: [FleetVehicleLocation]
    @State private var selectedLocation: FleetVehicleLocation?

    var body: some View {
        Map(initialPosition: .region(FleetMapRegion.india), interactionModes: []) {
            ForEach(locations) { location in
                Annotation(location.vehicle.displayName, coordinate: location.coordinate) {
                    Button {
                        selectedLocation = location
                    } label: {
                        FleetMapPinView(location: location, isCompact: true)
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
}
