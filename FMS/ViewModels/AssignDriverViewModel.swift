import Foundation
import Observation

@Observable
@MainActor
final class AssignDriverViewModel {
    let service: MockDataService
    var organizationID: UUID?

    var selectedVehicle: Vehicle? = nil
    var selectedDriver: User? = nil

    var assignmentSuccessMessage: String? = nil
    var isShowingSuccessToast: Bool = false

    init(service: MockDataService, organizationID: UUID? = nil) {
        self.service = service
        self.organizationID = organizationID
    }

    var unassignedVehicles: [Vehicle] {
        service.vehicles.filter { vehicle in
            if let organizationID, vehicle.organizationID != organizationID {
                return false
            }
            return vehicle.assignedDriverID == nil
        }
    }

    /// On-duty drivers with no scheduled or in-progress trip (from live profile + trip data).
    var availableDriversForDispatch: [User] {
        service.availableDriversForDispatch(organizationID: organizationID)
    }

    var compatibleDriversForSelectedVehicle: [User] {
        guard let selectedVehicle else { return [] }
        return availableDriversForDispatch.filter { service.isDriver($0, compatibleWith: selectedVehicle) }
    }

    var smartMatchCount: Int {
        guard let vehicle = selectedVehicle else { return 0 }
        return compatibleDriversForSelectedVehicle.filter { service.canAssignVehicle(vehicle, to: $0) }.count
    }

    func canSelect(driver: User, for vehicle: Vehicle) -> Bool {
        service.canAssignVehicle(vehicle, to: driver)
    }

    func assignPair() {
        guard let vehicle = selectedVehicle, let driver = selectedDriver else { return }
        guard service.isDriver(driver, compatibleWith: vehicle) else {
            assignmentSuccessMessage = "\(driver.name) is not licensed for \(vehicle.vehicleType)."
            isShowingSuccessToast = true
            dismissToastLater()
            return
        }
        guard service.canAssignVehicle(vehicle, to: driver) else {
            let assignedName = service.assignedVehicle(for: driver.id)?.displayName ?? "another vehicle"
            assignmentSuccessMessage = "\(driver.name) is already assigned to \(assignedName). Unassign first or choose another driver."
            isShowingSuccessToast = true
            dismissToastLater()
            return
        }

        var updatedVehicle = vehicle
        updatedVehicle.assignedDriverID = driver.id
        service.updateVehicle(updatedVehicle)

        service.addNotification(
            userID: driver.id,
            roleTarget: nil,
            title: "New Vehicle Assigned",
            message: "You have been assigned to \(vehicle.displayName) (\(vehicle.plateNumber)).",
            category: .info
        )

        assignmentSuccessMessage = "Assigned \(driver.name.components(separatedBy: " ").first ?? driver.name) to \(vehicle.displayName)"
        isShowingSuccessToast = true
        selectedVehicle = nil
        selectedDriver = nil
        dismissToastLater()
    }

    func smartMatchAll() {
        guard let vehicle = selectedVehicle else { return }
        guard let driver = compatibleDriversForSelectedVehicle.first(where: { canSelect(driver: $0, for: vehicle) }) else {
            assignmentSuccessMessage = compatibleDriversForSelectedVehicle.isEmpty
                ? "No on-duty drivers without trips are available for this vehicle type."
                : "Eligible drivers are on duty but already paired with another vehicle."
            isShowingSuccessToast = true
            dismissToastLater()
            return
        }

        selectedDriver = driver
        assignPair()
    }

    private func dismissToastLater() {
        Task {
            try? await Task.sleep(for: .seconds(3))
            isShowingSuccessToast = false
        }
    }
}
