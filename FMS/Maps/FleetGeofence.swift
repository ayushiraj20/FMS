import Foundation
import MapKit
import SwiftUI

struct FleetGeofence: Identifiable {
    let id: String
    let managerID: UUID?
    let organizationID: UUID?
    let center: CLLocationCoordinate2D
    let centerName: String
    let radiusMeters: CLLocationDistance

    var radiusKilometers: Double {
        radiusMeters / 1_000
    }

    var radiusText: String {
        "\(Int(radiusKilometers.rounded())) km"
    }

    func contains(_ coordinate: CLLocationCoordinate2D) -> Bool {
        center.distance(to: coordinate) <= radiusMeters
    }
}

struct FleetGeofenceBreach: Identifiable {
    let location: FleetVehicleLocation
    let geofence: FleetGeofence
    let distanceMeters: CLLocationDistance

    var id: UUID {
        location.vehicle.id
    }

    var distanceText: String {
        String(format: "%.0f km from hub", distanceMeters / 1_000)
    }
}

extension MockDataService {
    static let standardFleetGeofenceRadiusMeters: CLLocationDistance = 100_000
    static let primaryFleetHubCoordinate = CLLocationCoordinate2D(latitude: 19.0760, longitude: 72.8777)

    func fleetGeofence(for manager: User?) -> FleetGeofence {
        FleetGeofence(
            id: "fleet-geofence-\(manager?.id.uuidString ?? "default")",
            managerID: manager?.id,
            organizationID: manager?.organizationID,
            center: Self.primaryFleetHubCoordinate,
            centerName: "Mumbai Fleet Hub",
            radiusMeters: Self.standardFleetGeofenceRadiusMeters
        )
    }

    func geofenceBreaches(for manager: User?, locations: [FleetVehicleLocation]? = nil) -> [FleetGeofenceBreach] {
        let geofence = fleetGeofence(for: manager)
        let scopedLocations = (locations ?? allFleetLocations()).filter { location in
            guard let organizationID = geofence.organizationID else { return true }
            return location.vehicle.organizationID == organizationID
        }

        return scopedLocations.compactMap { location in
            let distance = geofence.center.distance(to: location.coordinate)
            guard distance > geofence.radiusMeters else { return nil }

            return FleetGeofenceBreach(
                location: location,
                geofence: geofence,
                distanceMeters: distance
            )
        }
        .sorted { $0.distanceMeters > $1.distanceMeters }
    }

    func fleetMapPreviewLocations(for manager: User?, limit: Int = 3) -> [FleetVehicleLocation] {
        let geofence = fleetGeofence(for: manager)
        let allLocations = allFleetLocations()
        let breachedIDs = Set(geofenceBreaches(for: manager, locations: allLocations).map(\.id))
        let breachedLocations = allLocations.filter { breachedIDs.contains($0.id) }
        let nearbyLocations = allLocations
            .filter { !breachedIDs.contains($0.id) }
            .sorted { first, second in
                first.coordinate.distance(to: geofence.center) < second.coordinate.distance(to: geofence.center)
            }

        return Array((breachedLocations + nearbyLocations).prefix(max(limit, breachedLocations.count)))
    }

    func sendGeofenceBreachAlerts(_ breaches: [FleetGeofenceBreach], manager: User?) {
        let managers = users.filter { user in
            guard user.role == .fleetManager else { return false }
            if let organizationID = manager?.organizationID {
                return user.organizationID == organizationID
            }
            return true
        }

        for breach in breaches where !geofenceAlertedVehicleIDs.contains(breach.location.vehicle.id) {
            let managerMessage = managerAlertMessage(for: breach)
            for fleetManager in managers {
                addNotification(
                    userID: fleetManager.id,
                    roleTarget: nil,
                    title: "Geofence Breach Alert",
                    message: managerMessage,
                    category: .critical
                )
            }

            if let driver = breach.location.driver {
                addNotification(
                    userID: driver.id,
                    roleTarget: nil,
                    title: "Geofence Breach Alert",
                    message: driverAlertMessage(for: breach),
                    category: .critical
                )
            }

            geofenceAlertedVehicleIDs.insert(breach.location.vehicle.id)
        }
    }

    private func managerAlertMessage(for breach: FleetGeofenceBreach) -> String {
        let vehicle = breach.location.vehicle
        let driverName = breach.location.driver?.name ?? "Unassigned"
        let driverPhone = breach.location.driver?.phone ?? "No driver phone"

        return "Fleet: \(vehicle.displayName) (\(vehicle.plateNumber)) breached the \(breach.geofence.radiusText) geofence. Driver: \(driverName), \(driverPhone). Location: \(breach.location.locality), \(breach.distanceText)."
    }

    private func driverAlertMessage(for breach: FleetGeofenceBreach) -> String {
        "Your assigned vehicle \(breach.location.vehicle.plateNumber) is outside the \(breach.geofence.radiusText) fleet geofence near \(breach.location.locality). Contact your fleet manager."
    }
}

struct FleetGeofenceStatusBanner: View {
    let geofence: FleetGeofence
    let breaches: [FleetGeofenceBreach]

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: breaches.isEmpty ? "checkmark.shield.fill" : "exclamationmark.octagon.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(breaches.isEmpty ? AppTheme.success : AppTheme.error)

            VStack(alignment: .leading, spacing: 2) {
                Text(breaches.isEmpty ? "Fleet inside geofence" : "\(breaches.count) geofence breach\(breaches.count == 1 ? "" : "es")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(geofence.centerName) · \(geofence.radiusText) radius")
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

extension FleetMapRegion {
    static func region(for geofence: FleetGeofence) -> MKCoordinateRegion {
        let latitudeRadius = geofence.radiusMeters / 111_000
        let longitudeRadius = geofence.radiusMeters / (111_000 * max(cos(geofence.center.latitude * .pi / 180), 0.2))

        return MKCoordinateRegion(
            center: geofence.center,
            span: MKCoordinateSpan(
                latitudeDelta: latitudeRadius * 2.6,
                longitudeDelta: longitudeRadius * 2.6
            )
        )
    }
}
