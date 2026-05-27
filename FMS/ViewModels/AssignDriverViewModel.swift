import Foundation
import Observation

@Observable
@MainActor
final class AssignDriverViewModel {
    let service: MockDataService
    
    var selectedVehicle: Vehicle? = nil
    var selectedDriver: User? = nil
    
    // Status states for notifications/feedback
    var assignmentSuccessMessage: String? = nil
    var isShowingSuccessToast: Bool = false
    var isShowingErrorToast: Bool = false
    
    init(service: MockDataService) {
        self.service = service
    }
    
    // Unassigned vehicles (assignedDriverID is nil)
    var unassignedVehicles: [Vehicle] {
        service.vehicles.filter { $0.assignedDriverID == nil }
    }
    
    // Unassigned drivers (role is driver, and not assigned to any vehicle)
    var unassignedDrivers: [User] {
        service.users.filter { user in
            user.role == .driver && !service.vehicles.contains { $0.assignedDriverID == user.id }
        }
    }

    var availableDriversForSelection: [User] {
        guard let selectedVehicle else { return unassignedDrivers }
        return eligibleDrivers(for: selectedVehicle)
    }
    
    func assignPair() {
        guard let vehicle = selectedVehicle, let driver = selectedDriver else { return }

        guard isEligible(driver: driver, for: vehicle) else {
            showToast(
                message: "License mismatch: \(driver.name) cannot drive \(vehicle.displayName).",
                isError: true
            )
            return
        }

        assign(driver: driver, to: vehicle, isAuto: false)
    }
    
    func autoAssignSelectedVehicle() {
        guard let vehicle = selectedVehicle else {
            showToast(message: "Select a vehicle first for Auto Assign.", isError: true)
            return
        }

        let candidates = eligibleDrivers(for: vehicle)
        guard let bestDriver = candidates.first else {
            showToast(
                message: "No available drivers with valid \(vehicle.requiredLicense.rawValue) license.",
                isError: true
            )
            return
        }

        assign(driver: bestDriver, to: vehicle, isAuto: true)
    }

    private func eligibleDrivers(for vehicle: Vehicle) -> [User] {
        unassignedDrivers
            .filter { isEligible(driver: $0, for: vehicle) }
            .sorted { lhs, rhs in
                licenseRank(lhs.licenseType) < licenseRank(rhs.licenseType)
            }
    }

    func isEligible(driver: User, for vehicle: Vehicle) -> Bool {
        guard let licenseType = driver.licenseType else { return false }
        return licenseType.isEligible(for: vehicle.requiredLicense)
    }

    private func licenseRank(_ licenseType: LicenseType?) -> Int {
        switch licenseType {
        case .some(.twoWheeler): return 0
        case .some(.lightVehicle): return 1
        case .some(.heavyVehicle): return 2
        case .none: return 3
        }
    }

    private func assign(driver: User, to vehicle: Vehicle, isAuto: Bool) {
        var updatedVehicle = vehicle
        updatedVehicle.assignedDriverID = driver.id
        service.updateVehicle(updatedVehicle)

        service.addNotification(
            userID: driver.id,
            roleTarget: nil,
            title: isAuto ? "New Vehicle Assigned (Auto)" : "New Vehicle Assigned",
            message: "You have been assigned to \(vehicle.displayName) (\(vehicle.plateNumber)).",
            category: .info
        )

        let firstName = driver.name.components(separatedBy: " ").first ?? driver.name
        let prefix = isAuto ? "Auto-assigned" : "Assigned"
        showToast(message: "\(prefix) \(firstName) to \(vehicle.displayName).", isError: false)

        selectedVehicle = nil
        selectedDriver = nil
    }

    private func showToast(message: String, isError: Bool) {
        assignmentSuccessMessage = message
        isShowingErrorToast = isError
        isShowingSuccessToast = true
        Task {
            try? await Task.sleep(for: .seconds(3))
            isShowingSuccessToast = false
            isShowingErrorToast = false
        }
    }
}
