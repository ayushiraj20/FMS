import MapKit
import SwiftUI

struct FleetMapFullView: View {
    let service: MockDataService
    @State private var selectedLocation: FleetVehicleLocation?
    @State private var mapPosition: MapCameraPosition

    init(service: MockDataService) {
        self.service = service
        _mapPosition = State(initialValue: .region(FleetMapRegion.india))
    }

    var body: some View {
        let locations = service.allFleetLocations()

        Map(position: $mapPosition) {
            ForEach(locations) { location in
                Annotation(location.vehicle.displayName, coordinate: location.coordinate) {
                    Button {
                        selectedLocation = location
                    } label: {
                        FleetMapPinView(location: location)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic, emphasis: .automatic, pointsOfInterest: .all, showsTraffic: true))
        .mapControls {
            MapCompass()
            MapScaleView()
        }
        .navigationTitle("All Fleet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    mapPosition = .region(FleetMapRegion.region(for: locations))
                } label: {
                    Image(systemName: "location.viewfinder")
                }
                .accessibilityLabel("Show all vehicles")
            }
        }
        .sheet(item: $selectedLocation) { location in
            FleetVehicleDetailSheet(location: location)
                .presentationDetents([.medium, .large])
        }
    }
}
