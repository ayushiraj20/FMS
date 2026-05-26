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
    private var fleetHubCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 19.0760, longitude: 72.8777)
    }

    func allFleetLocations() -> [FleetVehicleLocation] {
        vehicles.enumerated().map { index, vehicle in
            let location = demoLocation(for: vehicle)
            let activeTrip = trips.first { $0.vehicleID == vehicle.id && $0.status == .inProgress }
            let route = demoRoute(for: vehicle, currentCoordinate: location.coordinate, activeTrip: activeTrip)

            return FleetVehicleLocation(
                vehicle: vehicle,
                driver: user(for: vehicle.assignedDriverID),
                activeTrip: activeTrip,
                coordinate: location.coordinate,
                locality: location.locality,
                lastUpdated: .now.addingTimeInterval(-Double(index + 1) * 180),
                route: route
            )
        }
    }

    func nearbyFleetLocations(limit: Int = 3) -> [FleetVehicleLocation] {
        allFleetLocations()
            .sorted { first, second in
                first.coordinate.distance(to: fleetHubCoordinate) < second.coordinate.distance(to: fleetHubCoordinate)
            }
            .prefix(limit)
            .map { $0 }
    }

    private func demoLocation(for vehicle: Vehicle) -> (coordinate: CLLocationCoordinate2D, locality: String) {
        switch vehicle.id.uuidString.uppercased() {
        case "11111111-1111-1111-1111-111111111111":
            return (CLLocationCoordinate2D(latitude: 19.0330, longitude: 73.0297), "Panvel, Navi Mumbai")
        case "22222222-2222-2222-2222-222222222222":
            return (CLLocationCoordinate2D(latitude: 28.7041, longitude: 77.1025), "Delhi NCR")
        case "33333333-3333-3333-3333-333333333333":
            return (CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567), "Pune Workshop")
        case "44444444-4444-4444-4444-444444444444":
            return (CLLocationCoordinate2D(latitude: 19.2183, longitude: 72.9781), "Thane Depot")
        default:
            let seed = stableSeed(for: vehicle.id)
            let latitudeOffset = Double(seed % 9 - 4) * 0.035
            let longitudeOffset = Double(seed / 9 % 9 - 4) * 0.035
            return (
                CLLocationCoordinate2D(
                    latitude: fleetHubCoordinate.latitude + latitudeOffset,
                    longitude: fleetHubCoordinate.longitude + longitudeOffset
                ),
                "Mumbai Service Area"
            )
        }
    }

    private func demoRoute(for vehicle: Vehicle, currentCoordinate: CLLocationCoordinate2D, activeTrip: Trip?) -> FleetVehicleRoute {
        if let activeTrip {
            return FleetVehicleRoute(
                originName: activeTrip.origin,
                destinationName: activeTrip.destination,
                coordinates: [
                    fleetHubCoordinate,
                    currentCoordinate,
                    CLLocationCoordinate2D(latitude: 18.7557, longitude: 73.4091),
                    CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567)
                ],
                progress: 0.42
            )
        }

        switch vehicle.status {
        case .active:
            return FleetVehicleRoute(
                originName: "Mumbai Hub",
                destinationName: "Pune Warehouse",
                coordinates: [
                    fleetHubCoordinate,
                    currentCoordinate,
                    CLLocationCoordinate2D(latitude: 18.7557, longitude: 73.4091),
                    CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567)
                ],
                progress: 0.36
            )
        case .inService:
            return FleetVehicleRoute(
                originName: "Pune Workshop",
                destinationName: "Nashik Depot",
                coordinates: [
                    CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567),
                    currentCoordinate,
                    CLLocationCoordinate2D(latitude: 19.9975, longitude: 73.7898)
                ],
                progress: 0.18
            )
        case .idle:
            return FleetVehicleRoute(
                originName: "Thane Depot",
                destinationName: "Mumbai Hub",
                coordinates: [
                    currentCoordinate,
                    CLLocationCoordinate2D(latitude: 19.1800, longitude: 72.9500),
                    fleetHubCoordinate
                ],
                progress: 0.0
            )
        case .outOfService:
            return FleetVehicleRoute(
                originName: "Service Bay",
                destinationName: "Mumbai Hub",
                coordinates: [
                    currentCoordinate,
                    CLLocationCoordinate2D(latitude: 19.1200, longitude: 72.9200),
                    fleetHubCoordinate
                ],
                progress: 0.0
            )
        }
    }

    private func stableSeed(for vehicleID: UUID) -> Int {
        vehicleID.uuidString.unicodeScalars.reduce(0) { partialResult, scalar in
            (partialResult * 31 + Int(scalar.value)) % 10_000
        }
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
                center: CLLocationCoordinate2D(latitude: 22.5, longitude: 78.9),
                span: MKCoordinateSpan(latitudeDelta: 20.0, longitudeDelta: 20.0)
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
