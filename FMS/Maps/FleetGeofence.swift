import Foundation
import MapKit
import SwiftUI

struct TripRouteGeofenceBreach: Identifiable {
    let location: FleetVehicleLocation
    let trip: Trip
    let plan: TripRoutePlan
    let status: TripRouteCorridorStatus
    let distanceBeyondCorridorMeters: CLLocationDistance

    var id: UUID { location.vehicle.id }

    var distanceText: String {
        String(format: "%.0f m off approved routes", distanceBeyondCorridorMeters)
    }
}

struct RouteGeofenceAlertState {
    var lastStatus: TripRouteCorridorStatus?
    var lastAlternativeAlertAt: Date?
    var lastBreachAlertAt: Date?
}

extension MockDataService {
    static let primaryFleetHubCoordinate = CLLocationCoordinate2D(latitude: 17.3850, longitude: 78.4867)
    static let routeCorridorToleranceMeters = TripRoutePlan.corridorToleranceMeters

    func tripRoutePlan(for trip: Trip) async -> TripRoutePlan? {
        if let cached = tripRoutePlansByTripID[trip.id] {
            return cached
        }
        if let persisted = decodeRoutePlan(from: trip.routeDetails), persisted.tripID == trip.id {
            tripRoutePlansByTripID[trip.id] = persisted
            return persisted
        }
        guard trip.hasRoutableEndpoints else { return nil }
        guard let plan = await TripRoutePlanningService.planRoutes(for: trip) else { return nil }
        tripRoutePlansByTripID[trip.id] = plan
        persistRoutePlan(plan, for: trip.id)
        return plan
    }

    func prefetchRoutePlansForActiveTrips() async {
        let activeTrips = trips.filter { $0.status == .inProgress && $0.hasRoutableEndpoints }
        for trip in activeTrips {
            _ = await tripRoutePlan(for: trip)
        }
    }

    func reloadTripRoutePlansFromStoredTrips() {
        for trip in trips {
            if let persisted = decodeRoutePlan(from: trip.routeDetails) {
                tripRoutePlansByTripID[trip.id] = persisted
            }
        }
    }

    func tripWithRoutePlanAttached(_ trip: Trip) async -> Trip {
        guard trip.hasRoutableEndpoints else { return trip }
        if let cached = tripRoutePlansByTripID[trip.id] {
            return tripWithEncodedRoutePlan(trip, plan: cached)
        }
        if let persisted = decodeRoutePlan(from: trip.routeDetails) {
            tripRoutePlansByTripID[trip.id] = persisted
            return trip
        }
        guard let plan = await TripRoutePlanningService.planRoutes(for: trip) else { return trip }
        tripRoutePlansByTripID[trip.id] = plan
        return tripWithEncodedRoutePlan(trip, plan: plan)
    }

    private func tripWithEncodedRoutePlan(_ trip: Trip, plan: TripRoutePlan) -> Trip {
        var updated = trip
        if let data = try? JSONEncoder().encode(plan),
           let json = String(data: data, encoding: .utf8) {
            updated.routeDetails = "route-plan:\(json)"
        }
        return updated
    }

    func routeGeofenceBreaches(
        for manager: User?,
        locations: [FleetVehicleLocation]? = nil
    ) -> [TripRouteGeofenceBreach] {
        let scopedLocations = (locations ?? allFleetLocations()).filter { location in
            guard let organizationID = manager?.organizationID else { return true }
            return location.vehicle.organizationID == organizationID
        }

        return scopedLocations.compactMap { location in
            guard let trip = location.activeTrip,
                  let plan = tripRoutePlansByTripID[trip.id] else {
                return nil
            }

            let status = TripRouteGeofenceEvaluator.corridorStatus(for: location.coordinate, plan: plan)
            guard case .outsideCorridor(let distance) = status else { return nil }

            return TripRouteGeofenceBreach(
                location: location,
                trip: trip,
                plan: plan,
                status: status,
                distanceBeyondCorridorMeters: max(0, distance - Self.routeCorridorToleranceMeters)
            )
        }
    }

    func fleetMapPreviewLocations(for manager: User?, limit: Int = 3) -> [FleetVehicleLocation] {
        let allLocations = allFleetLocations()
        let breachedIDs = Set(routeGeofenceBreaches(for: manager, locations: allLocations).map(\.id))
        let breachedLocations = allLocations.filter { breachedIDs.contains($0.id) }
        let activeTripLocations = allLocations
            .filter { !breachedIDs.contains($0.id) && $0.activeTrip != nil }

        return Array((breachedLocations + activeTripLocations + allLocations).prefix(max(limit, breachedLocations.count)))
    }

    func processRouteGeofenceUpdate(
        trip: Trip,
        vehicle: Vehicle,
        driver: User?,
        coordinate: CLLocationCoordinate2D,
        locality: String,
        manager: User?
    ) async {
        guard trip.status == .inProgress else { return }
        guard let plan = await tripRoutePlan(for: trip) else { return }

        let location = FleetVehicleLocation(
            vehicle: vehicle,
            driver: driver,
            activeTrip: trip,
            coordinate: coordinate,
            locality: locality,
            lastUpdated: .now,
            route: FleetVehicleRoute(
                originName: trip.origin,
                destinationName: trip.destination,
                coordinates: plan.mainRouteCoordinates,
                progress: 0
            )
        )

        let status = TripRouteGeofenceEvaluator.corridorStatus(for: coordinate, plan: plan)
        let state = routeGeofenceAlertStates[vehicle.id] ?? RouteGeofenceAlertState()
        let now = Date.now

        switch status {
        case .onAlternativeRoute(let index):
            let shouldAlert = state.lastStatus != status
                || state.lastAlternativeAlertAt.map { now.timeIntervalSince($0) >= 30 } != false
            if shouldAlert {
                sendAlternativeRouteAlert(
                    location: location,
                    trip: trip,
                    alternativeIndex: index,
                    manager: manager
                )
                routeGeofenceAlertStates[vehicle.id] = RouteGeofenceAlertState(
                    lastStatus: status,
                    lastAlternativeAlertAt: now,
                    lastBreachAlertAt: state.lastBreachAlertAt
                )
            }

        case .outsideCorridor:
            let shouldAlert = state.lastStatus != status
                || state.lastBreachAlertAt.map { now.timeIntervalSince($0) >= 30 } != false
            if shouldAlert {
                let breach = TripRouteGeofenceBreach(
                    location: location,
                    trip: trip,
                    plan: plan,
                    status: status,
                    distanceBeyondCorridorMeters: corridorOverflowDistance(for: coordinate, plan: plan)
                )
                sendRouteCorridorBreachAlerts([breach], manager: manager)
                routeGeofenceAlertStates[vehicle.id] = RouteGeofenceAlertState(
                    lastStatus: status,
                    lastAlternativeAlertAt: state.lastAlternativeAlertAt,
                    lastBreachAlertAt: now
                )
            }

        case .onMainRoute, .unavailable:
            if state.lastStatus != status {
                routeGeofenceAlertStates[vehicle.id] = RouteGeofenceAlertState(
                    lastStatus: status,
                    lastAlternativeAlertAt: state.lastAlternativeAlertAt,
                    lastBreachAlertAt: state.lastBreachAlertAt
                )
            }
        }

        if routeGeofenceAlertStates[vehicle.id] == nil {
            routeGeofenceAlertStates[vehicle.id] = RouteGeofenceAlertState(lastStatus: status)
        }
    }

    func sendRouteGeofenceMonitoringAlerts(for manager: User?, locations: [FleetVehicleLocation]? = nil) async {
        let scoped = locations ?? allFleetLocations()
        for location in scoped {
            guard let trip = location.activeTrip else { continue }
            await processRouteGeofenceUpdate(
                trip: trip,
                vehicle: location.vehicle,
                driver: location.driver,
                coordinate: location.coordinate,
                locality: location.locality,
                manager: manager
            )
        }

        _ = routeGeofenceBreaches(for: manager, locations: scoped)
    }

    func sendRouteCorridorBreachAlerts(_ breaches: [TripRouteGeofenceBreach], manager: User?) {
        let managers = fleetManagers(for: manager)

        for breach in breaches {
            let managerMessage = routeBreachManagerMessage(for: breach)
            for fleetManager in managers {
                addNotification(
                    userID: fleetManager.id,
                    roleTarget: nil,
                    title: "Route Corridor Breach",
                    message: managerMessage,
                    category: .critical
                )
            }

            if let driver = breach.location.driver {
                addNotification(
                    userID: driver.id,
                    roleTarget: nil,
                    title: "Route Corridor Breach",
                    message: routeBreachDriverMessage(for: breach),
                    category: .critical
                )
            }
        }
    }

    private func sendAlternativeRouteAlert(
        location: FleetVehicleLocation,
        trip: Trip,
        alternativeIndex: Int,
        manager: User?
    ) {
        let managers = fleetManagers(for: manager)
        let routeLabel = "Alternative route \(alternativeIndex + 1)"
        let vehicle = location.vehicle
        let driverName = location.driver?.name ?? "Unassigned"

        let message = "\(vehicle.displayName) (\(vehicle.plateNumber)) left the ideal route for \(trip.origin) → \(trip.destination) and is on \(routeLabel). Driver: \(driverName). Location: \(location.locality)."

        for fleetManager in managers {
            addNotification(
                userID: fleetManager.id,
                roleTarget: nil,
                title: "Non-Ideal Route Alert",
                message: message,
                category: .warning
            )
        }
    }

    private func fleetManagers(for manager: User?) -> [User] {
        users.filter { user in
            guard user.role == .fleetManager else { return false }
            if let organizationID = manager?.organizationID {
                return user.organizationID == organizationID
            }
            return true
        }
    }

    private func routeBreachManagerMessage(for breach: TripRouteGeofenceBreach) -> String {
        let vehicle = breach.location.vehicle
        let driverName = breach.location.driver?.name ?? "Unassigned"
        let driverPhone = breach.location.driver?.phone ?? "No driver phone"
        return "Fleet: \(vehicle.displayName) (\(vehicle.plateNumber)) is outside all approved route corridors (±\(Int(Self.routeCorridorToleranceMeters)) m) for \(breach.trip.origin) → \(breach.trip.destination). Driver: \(driverName), \(driverPhone). \(breach.distanceText) near \(breach.location.locality)."
    }

    private func routeBreachDriverMessage(for breach: TripRouteGeofenceBreach) -> String {
        "You are outside the approved route corridor (±\(Int(Self.routeCorridorToleranceMeters)) m from main or alternative routes) near \(breach.location.locality). Return to an approved route or contact your fleet manager."
    }

    private func corridorOverflowDistance(
        for coordinate: CLLocationCoordinate2D,
        plan: TripRoutePlan
    ) -> CLLocationDistance {
        let distances = plan.allRoutes.map {
            RouteGeometry.distance(from: coordinate, toPolyline: $0)
        }
        let nearest = distances.min() ?? 0
        return max(0, nearest - Self.routeCorridorToleranceMeters)
    }

    private func persistRoutePlan(_ plan: TripRoutePlan, for tripID: UUID) {
        guard let index = trips.firstIndex(where: { $0.id == tripID }) else { return }
        if let data = try? JSONEncoder().encode(plan),
           let json = String(data: data, encoding: .utf8) {
            trips[index].routeDetails = "route-plan:\(json)"
        }
    }

    private func decodeRoutePlan(from routeDetails: String?) -> TripRoutePlan? {
        guard let routeDetails,
              routeDetails.hasPrefix("route-plan:"),
              let data = routeDetails.dropFirst("route-plan:".count).data(using: .utf8) else {
            return nil
        }
        return try? JSONDecoder().decode(TripRoutePlan.self, from: data)
    }
}

struct TripRouteGeofenceStatusBanner: View {
    let breaches: [TripRouteGeofenceBreach]
    let monitoredTripCount: Int

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: breaches.isEmpty ? "checkmark.shield.fill" : "exclamationmark.octagon.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(breaches.isEmpty ? AppTheme.success : AppTheme.error)

            VStack(alignment: .leading, spacing: 2) {
                Text(breaches.isEmpty ? "Vehicles on approved routes" : "\(breaches.count) route corridor breach\(breaches.count == 1 ? "" : "es")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("Main + 2 alternate routes · ±\(Int(TripRoutePlan.corridorToleranceMeters)) m corridor · \(monitoredTripCount) active trip\(monitoredTripCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer(minLength: 12)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(breaches.isEmpty ? AppTheme.success.opacity(0.35) : AppTheme.error.opacity(0.35), lineWidth: 1)
        )
    }
}

// Backward-compatible typealiases for older references during migration.
typealias FleetGeofenceBreach = TripRouteGeofenceBreach
