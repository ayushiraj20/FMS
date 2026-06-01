import MapKit
import SwiftUI

struct FleetMapPreview: View {
    let locations: [FleetVehicleLocation]
    let service: MockDataService
    var initialRegion = FleetMapRegion.india
    var routeBreaches: [TripRouteGeofenceBreach] = []
    @State private var selectedLocation: FleetVehicleLocation?

    var body: some View {
        Map(initialPosition: .region(initialRegion), interactionModes: []) {
            ForEach(activeTripPlans, id: \.plan.tripID) { item in
                TripRoutesMapContent(plan: item.plan, showLabels: false)
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

    private var activeTripPlans: [(trip: Trip, plan: TripRoutePlan)] {
        locations.compactMap { location in
            guard let trip = location.activeTrip,
                  let plan = service.tripRoutePlansByTripID[trip.id] else {
                return nil
            }
            return (trip, plan)
        }
    }

    private func isBreaching(_ location: FleetVehicleLocation) -> Bool {
        routeBreaches.contains { $0.id == location.id }
    }
}
