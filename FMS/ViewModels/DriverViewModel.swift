import Foundation
import SwiftUI
import CoreLocation
import Observation

@Observable
@MainActor
final class DriverViewModel {
    var isLoading = true
    var selectedTab = 0
    var showSOSSheet = false
    var showProfileSheet = false
    var showDefectSheet = false
    var showChatSheet = false
    var showFuelReceiptSheet = false
    var showBreakLogSheet = false
    var showInspection = false
    var showDutyToggleAlert = false
    var showAlertDetail: VehicleAlert?

    // SOS
    var sosCountdown: Int = 5
    var sosTriggered = false
    var sosConfirmed = false
    var selectedEmergencyType: String = "Accident"
    var sosDescription: String = ""
    @ObservationIgnored private var sosTimer: Timer?
    @ObservationIgnored private let locationManager = CLLocationManager()
    @ObservationIgnored private var locationDelegate: LocationDelegate?

    // Inspection
    var inspectionItems: [DriverInspectionItem] = DriverViewModel.defaultInspectionItems()
    var inspectionType: InspectionType = .preTrip
    var inspectionSubmitted = false
    var showInspectionCriticalAlert = false

    // Toast
    var toastMessage: String?
    var showToast = false

    // Trip map & live GPS tracking
    var currentSpeed: Double = 0.0
    var speedLimit: Double = 60.0
    var currentLocation: CLLocationCoordinate2D?
    var isTracking = false

    func load() async {
        guard isLoading else { return }
        try? await Task.sleep(for: .seconds(0.35))
        isLoading = false
    }

    // MARK: - SOS

    func startSOSCountdown(service: MockDataService, user: User?) {
        sosCountdown = 5
        sosTriggered = false
        sosConfirmed = false
        showSOSSheet = true

        sosTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }

                if self.sosCountdown > 1 {
                    self.sosCountdown -= 1
                } else {
                    self.sosTimer?.invalidate()
                    self.triggerSOS(service: service, user: user)
                }
            }
        }
    }

    func cancelSOS() {
        sosTimer?.invalidate()
        sosTimer = nil
        showSOSSheet = false
        sosTriggered = false
        sosConfirmed = false
    }

    func triggerSOS(service: MockDataService, user: User?) {
        sosTimer?.invalidate()
        sosTimer = nil
        sosTriggered = true

        guard let user else {
            sosConfirmed = true
            return
        }

        guard let vehicle = service.vehicles.first(where: { $0.assignedDriverID == user.id }) else {
            sosConfirmed = true
            return
        }
        let vehicleID = vehicle.id

        // Request location permissions if not already determined
        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }

        // Get exact coordinates if authorized, otherwise fallback gracefully to Mumbai
        var finalLat = 19.0760
        var finalLng = 72.8777

        if locationManager.authorizationStatus == .authorizedWhenInUse || 
           locationManager.authorizationStatus == .authorizedAlways {
            if let loc = locationManager.location {
                finalLat = loc.coordinate.latitude
                finalLng = loc.coordinate.longitude
                print("CoreLocation: Resolved exact driver location -> (\(finalLat), \(finalLng)) ✅")
            } else {
                print("CoreLocation: Location authorized but coordinates unavailable. Falling back to default. ⚠️")
            }
        } else {
            print("CoreLocation: Location permissions not authorized. Falling back to default. ⚠️")
        }

        service.triggerSOS(
            driverID: user.id,
            vehicleID: vehicleID,
            latitude: finalLat,
            longitude: finalLng,
            emergencyType: selectedEmergencyType,
            description: sosDescription.isEmpty ? nil : sosDescription
        )

        // Show confirmed after brief delay
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            sosConfirmed = true
        }
    }

    // MARK: - Inspection

    static func defaultInspectionItems() -> [DriverInspectionItem] {
        [
            DriverInspectionItem(title: "Tires", iconName: "circle.circle.fill", isCritical: true),
            DriverInspectionItem(title: "Brakes", iconName: "brakesignal", isCritical: true),
            DriverInspectionItem(title: "Lights", iconName: "headlight.high.beam.fill"),
            DriverInspectionItem(title: "Mirrors", iconName: "rectangle.on.rectangle.angled"),
            DriverInspectionItem(title: "Horn", iconName: "speaker.wave.3.fill"),
            DriverInspectionItem(title: "Fluid Levels", iconName: "drop.fill"),
            DriverInspectionItem(title: "Body Damage", iconName: "car.side.fill"),
            DriverInspectionItem(title: "Seat Belts", iconName: "figure.seated.seatbelt"),
            DriverInspectionItem(title: "Wipers", iconName: "windshield.front.and.wiper"),
            DriverInspectionItem(title: "Engine Oil", iconName: "oilcan.fill"),
            DriverInspectionItem(title: "Fuel Level", iconName: "fuelpump.fill"),
            DriverInspectionItem(title: "Fire Extinguisher", iconName: "fire.extinguisher.fill")
        ]
    }

    var inspectionCheckedCount: Int {
        inspectionItems.filter { $0.status != .unchecked }.count
    }

    var inspectionProgress: Double {
        guard !inspectionItems.isEmpty else { return 0 }
        return Double(inspectionCheckedCount) / Double(inspectionItems.count)
    }

    var allItemsChecked: Bool {
        inspectionItems.allSatisfy { $0.status != .unchecked }
    }

    var hasCriticalFailures: Bool {
        inspectionItems.contains { $0.isCritical && $0.status == .failed }
    }

    func toggleInspectionItem(at index: Int) {
        switch inspectionItems[index].status {
        case .unchecked:
            inspectionItems[index].status = .passed
        case .passed:
            inspectionItems[index].status = .failed
        case .failed:
            inspectionItems[index].status = .unchecked
            inspectionItems[index].failureDescription = ""
        }
    }

    func submitInspection(service: MockDataService, user: User?) {
        guard let user else { return }
        
        guard let vehicle = service.vehicles.first(where: { $0.assignedDriverID == user.id }) else { return }
        let vehicleID = vehicle.id

        if hasCriticalFailures {
            showInspectionCriticalAlert = true
        }

        let items = inspectionItems.map {
            InspectionItem(id: UUID(), title: $0.title, isChecked: $0.status != .failed)
        }

        let notes = inspectionItems
            .filter { $0.status == .failed }
            .map { "\($0.title): \($0.failureDescription)" }
            .joined(separator: ". ")

        service.addInspection(
            driverID: user.id,
            vehicleID: vehicleID,
            type: inspectionType,
            notes: notes.isEmpty ? "All items passed." : notes,
            items: items
        )

        inspectionSubmitted = true
        showToastMessage("Inspection submitted")
    }

    func resetInspection() {
        inspectionItems = DriverViewModel.defaultInspectionItems()
        inspectionSubmitted = false
        inspectionType = .preTrip
    }

    // MARK: - Toast

    func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true

        Task {
            try? await Task.sleep(for: .seconds(2.5))
            showToast = false
        }
    }

    // MARK: - Helpers

    func driverFirstName(_ user: User?) -> String {
        user?.name.components(separatedBy: " ").first ?? "Driver"
    }

    func driverInitials(_ user: User?) -> String {
        guard let name = user?.name else { return "?" }
        let parts = name.components(separatedBy: " ")
        let initials = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return initials.isEmpty ? "?" : initials
    }

    // MARK: - Live GPS Tracking

    func startLiveTracking() {
        guard !isTracking else { return }

        if locationManager.authorizationStatus == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
        }

        var lastLocation: CLLocation? = nil
        let delegate = LocationDelegate { [weak self] location in
            MainActor.assumeIsolated {
                guard let self = self else { return }
                self.currentLocation = location.coordinate
                
                var calculatedSpeed = location.speed
                // In iOS Simulator, location.speed is often -1.0 or 0.0 even during motion.
                // We calculate speed dynamically from the distance and time elapsed between updates.
                if calculatedSpeed <= 0 {
                    if let last = lastLocation {
                        let distance = location.distance(from: last) // meters
                        let time = location.timestamp.timeIntervalSince(last.timestamp) // seconds
                        if time > 0 {
                            calculatedSpeed = distance / time
                        }
                    }
                }
                lastLocation = location
                
                let speedKMH = max(0, calculatedSpeed * 3.6)
                if speedKMH > 0 {
                    // Cap at 65 km/h for a realistic simulated heavy commercial vehicle speed,
                    // but allow it to exceed the 60 km/h limit occasionally to demonstrate overspeed alerts!
                    self.currentSpeed = min(speedKMH, 65.0)
                } else {
                    self.currentSpeed = 0.0
                }
            }
        }
        self.locationDelegate = delegate
        locationManager.delegate = delegate
        locationManager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        locationManager.distanceFilter = 10 // Update every 10 meters
        locationManager.allowsBackgroundLocationUpdates = false
        locationManager.startUpdatingLocation()
        isTracking = true
        print("[GPS] Live tracking started ✅")
    }

    func stopLiveTracking() {
        guard isTracking else { return }
        locationManager.stopUpdatingLocation()
        locationManager.delegate = nil
        locationDelegate = nil
        isTracking = false
        currentSpeed = 0.0
        print("[GPS] Live tracking stopped ⛔️")
    }
}

// MARK: - CLLocationManagerDelegate Helper

private class LocationDelegate: NSObject, CLLocationManagerDelegate {
    private let onUpdate: (CLLocation) -> Void

    init(onUpdate: @escaping (CLLocation) -> Void) {
        self.onUpdate = onUpdate
        super.init()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let latest = locations.last else { return }
        onUpdate(latest)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("[GPS] Location error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            print("[GPS] Location authorized ✅")
            manager.startUpdatingLocation()
        case .denied, .restricted:
            print("[GPS] Location denied ⚠️")
        default:
            break
        }
    }
}

