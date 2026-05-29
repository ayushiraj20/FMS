import MapKit
import SwiftUI

struct FleetMapFullView: View {
    let service: MockDataService
    let manager: User?
    @State private var selectedLocation: FleetVehicleLocation?
    @State private var mapPosition: MapCameraPosition

    init(service: MockDataService, manager: User? = nil) {
        self.service = service
        self.manager = manager
        _mapPosition = State(initialValue: .region(FleetMapRegion.region(for: service.fleetGeofence(for: manager))))
    }

    var body: some View {
        let locations = service.allFleetLocations()
        let geofence = service.fleetGeofence(for: manager)
        let breaches = service.geofenceBreaches(for: manager, locations: locations)

        ZStack(alignment: .top) {
            Map(position: $mapPosition) {
                MapCircle(center: geofence.center, radius: geofence.radiusMeters)
                    .foregroundStyle(Color.orange.opacity(0.22))

                MapCircle(center: geofence.center, radius: geofence.radiusMeters)
                    .stroke(Color.orange.opacity(0.8), lineWidth: 2)

                Annotation(geofence.centerName, coordinate: geofence.center) {
                    Image(systemName: "building.2.crop.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(Color.orange)
                        .padding(7)
                        .background(.background, in: Circle())
                }

                ForEach(locations) { location in
                    Annotation(location.vehicle.displayName, coordinate: location.coordinate) {
                        Button {
                            selectedLocation = location
                        } label: {
                            FleetMapPinView(location: location, isBreaching: isBreaching(location, breaches: breaches))
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

            FleetGeofenceStatusBanner(geofence: geofence, breaches: breaches)
                .padding(.horizontal, 16)
                .padding(.top, 12)
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
        .task(id: breaches.map(\.id).map(\.uuidString).joined(separator: ",")) {
            service.sendGeofenceBreachAlerts(breaches, manager: manager)
        }
    }

    private func isBreaching(_ location: FleetVehicleLocation, breaches: [FleetGeofenceBreach]) -> Bool {
        breaches.contains { $0.id == location.id }
    }
}
