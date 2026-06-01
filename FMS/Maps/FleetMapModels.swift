import Foundation
import MapKit
import SwiftUI

struct FleetVehicleLocation: Identifiable {
    let vehicle: Vehicle
    let driver: User?
    let activeTrip: Trip?
    let coordinate: CLLocationCoordinate2D
    let locality: String
    let lastUpdated: Date
    let route: FleetVehicleRoute

    var id: UUID { vehicle.id }

    var routeText: String {
        "\(route.originName) to \(route.destinationName)"
    }

    var driverText: String {
        driver?.name ?? "Unassigned"
    }

    var lastUpdatedText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastUpdated, relativeTo: .now)
    }

    var statusColor: Color {
        switch vehicle.status {
        case .active:
            return AppTheme.success
        case .inService:
            return AppTheme.warning
        case .idle:
            return AppTheme.textSecondary
        case .outOfService:
            return AppTheme.error
        }
    }
}

struct FleetVehicleRoute {
    let originName: String
    let destinationName: String
    let coordinates: [CLLocationCoordinate2D]
    let progress: Double

    var progressText: String {
        "\(Int((progress * 100).rounded()))% complete"
    }
}

extension MockDataService {
    func allFleetLocations() -> [FleetVehicleLocation] {
        vehicles.compactMap { vehicle in
            guard let location = liveLocation(for: vehicle) else { return nil }
            let activeTrip = trips.first { $0.vehicleID == vehicle.id && $0.status == .inProgress }
            let route = routeForVehicle(vehicle, activeTrip: activeTrip, currentCoordinate: location.coordinate)

            return FleetVehicleLocation(
                vehicle: vehicle,
                driver: user(for: vehicle.assignedDriverID),
                activeTrip: activeTrip,
                coordinate: location.coordinate,
                locality: location.locality,
                lastUpdated: .now,
                route: route
            )
        }
    }

    func nearbyFleetLocations(limit: Int = 3) -> [FleetVehicleLocation] {
        Array(allFleetLocations().prefix(limit))
    }

    private func liveLocation(for vehicle: Vehicle) -> (coordinate: CLLocationCoordinate2D, locality: String)? {
        if let trip = trips.first(where: { $0.vehicleID == vehicle.id && $0.status == .inProgress }),
           let originLat = trip.originLat,
           let originLng = trip.originLng,
           let destinationLat = trip.destinationLat,
           let destinationLng = trip.destinationLng {
            let progress = tripProgress(for: trip)
            let latitude = originLat + ((destinationLat - originLat) * progress)
            let longitude = originLng + ((destinationLng - originLng) * progress)
            return (
                CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                trip.destination
            )
        }

        if let scheduledTrip = trips.first(where: {
            $0.vehicleID == vehicle.id && $0.status == .scheduled
        }),
           let originLat = scheduledTrip.originLat,
           let originLng = scheduledTrip.originLng {
            return (
                CLLocationCoordinate2D(latitude: originLat, longitude: originLng),
                scheduledTrip.origin
            )
        }

        return nil
    }

    private func tripProgress(for trip: Trip) -> Double {
        guard let endDate = trip.endDate else { return 0.35 }
        let total = endDate.timeIntervalSince(trip.startDate)
        guard total > 0 else { return 0.35 }
        let elapsed = Date.now.timeIntervalSince(trip.startDate)
        return min(max(elapsed / total, 0.05), 0.95)
    }

    private func routeForVehicle(
        _ vehicle: Vehicle,
        activeTrip: Trip?,
        currentCoordinate: CLLocationCoordinate2D
    ) -> FleetVehicleRoute {
        if let activeTrip {
            return FleetVehicleRoute(
                originName: activeTrip.origin,
                destinationName: activeTrip.destination,
                coordinates: routeCoordinates(for: activeTrip, currentCoordinate: currentCoordinate),
                progress: tripProgress(for: activeTrip)
            )
        }

        return FleetVehicleRoute(
            originName: vehicle.displayName,
            destinationName: "No active route",
            coordinates: [currentCoordinate],
            progress: 0
        )
    }

    private func routeCoordinates(for trip: Trip, currentCoordinate: CLLocationCoordinate2D) -> [CLLocationCoordinate2D] {
        if let plan = tripRoutePlansByTripID[trip.id], !plan.mainRouteCoordinates.isEmpty {
            return plan.mainRouteCoordinates
        }

        guard let origin = trip.originCoordinate, let destination = trip.destinationCoordinate else {
            return [currentCoordinate]
        }

        return [origin, currentCoordinate, destination]
    }
}

extension CLLocationCoordinate2D {
    func distance(to other: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: latitude, longitude: longitude)
            .distance(from: CLLocation(latitude: other.latitude, longitude: other.longitude))
    }
}

enum FleetMapRegion {
    static let india = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 22.9734, longitude: 78.6569),
        span: MKCoordinateSpan(latitudeDelta: 28.0, longitudeDelta: 28.0)
    )

    static func region(for locations: [FleetVehicleLocation]) -> MKCoordinateRegion {
        region(for: locations.map(\.coordinate))
    }

    static func region(for coordinates: [CLLocationCoordinate2D]) -> MKCoordinateRegion {
        guard !coordinates.isEmpty else {
            return MKCoordinateRegion(
                center: MockDataService.primaryFleetHubCoordinate,
                span: MKCoordinateSpan(latitudeDelta: 2.6, longitudeDelta: 2.6)
            )
        }

        let latitudes = coordinates.map(\.latitude)
        let longitudes = coordinates.map(\.longitude)
        let minLatitude = latitudes.min() ?? 22.5
        let maxLatitude = latitudes.max() ?? 22.5
        let minLongitude = longitudes.min() ?? 78.9
        let maxLongitude = longitudes.max() ?? 78.9

        let center = CLLocationCoordinate2D(
            latitude: (minLatitude + maxLatitude) / 2,
            longitude: (minLongitude + maxLongitude) / 2
        )

        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLatitude - minLatitude) * 1.6, 0.08),
            longitudeDelta: max((maxLongitude - minLongitude) * 1.6, 0.08)
        )

        return MKCoordinateRegion(center: center, span: span)
    }
}
