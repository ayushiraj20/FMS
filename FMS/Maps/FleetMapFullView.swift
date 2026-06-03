import MapKit
import SwiftUI

struct FleetMapFullView: View {
    let service: MockDataService
    let manager: User?
    @State private var selectedLocation: FleetVehicleLocation?
    @State private var mapPosition: MapCameraPosition = .region(FleetMapRegion.india)

    var body: some View {
        let locations = service.movingFleetLocations(for: manager)
        let breaches = service.routeGeofenceBreaches(for: manager, locations: locations)
        let monitoredTrips = locations.compactMap(\.activeTrip).count

        ZStack(alignment: .top) {
            Map(position: $mapPosition) {
                ForEach(activeTripPlans(locations: locations), id: \.plan.tripID) { item in
                    TripRoutesMapContent(plan: item.plan, showLabels: false)
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

            VStack(spacing: 8) {
                TripRouteGeofenceStatusBanner(breaches: breaches, monitoredTripCount: monitoredTrips)
                TripRouteLegendView()
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
        .navigationTitle("All Fleet")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    var coordinates = locations.map(\.coordinate)
                    for item in activeTripPlans(locations: locations) {
                        coordinates.append(contentsOf: item.plan.mainRouteCoordinates)
                    }
                    mapPosition = .region(FleetMapRegion.region(for: coordinates))
                } label: {
                    Image(systemName: "location.viewfinder")
                }
                .accessibilityLabel("Show moving vehicles")
            }
        }
        .sheet(item: $selectedLocation) { location in
            FleetVehicleDetailSheet(location: location)
                .presentationDetents([.medium, .large])
        }
        .task {
            await service.prefetchRoutePlansForActiveTrips()
            var coordinates = locations.map(\.coordinate)
            for item in activeTripPlans(locations: locations) {
                coordinates.append(contentsOf: item.plan.mainRouteCoordinates)
            }
            mapPosition = .region(FleetMapRegion.region(for: coordinates))
        }
        .task(id: locations.map(\.id.uuidString).joined()) {
            await service.sendRouteGeofenceMonitoringAlerts(for: manager, locations: locations)
        }
    }

    private func activeTripPlans(locations: [FleetVehicleLocation]) -> [(trip: Trip, plan: TripRoutePlan)] {
        locations.compactMap { location in
            guard let trip = location.activeTrip,
                  let plan = service.tripRoutePlansByTripID[trip.id] else {
                return nil
            }
            return (trip, plan)
        }
    }

    private func isBreaching(_ location: FleetVehicleLocation, breaches: [TripRouteGeofenceBreach]) -> Bool {
        breaches.contains { $0.id == location.id }
    }
}
