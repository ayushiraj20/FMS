import Foundation
import Observation

@Observable
@MainActor
final class DriverAssignmentViewModel {
    let service: MockDataService
    
    var isPresentingAssignSheet: Bool = false
    var selectedDriver: User? = nil
    var selectedVehicle: Vehicle? = nil
    
    // Status states for notifications/feedback
    var successMessage: String? = nil
    var isShowingToast: Bool = false
    
    init(service: MockDataService) {
        self.service = service
    }
    
    // All drivers in the organization
    var drivers: [User] {
        service.users.filter { $0.role == .driver }
    }
    
    // Available (unassigned) vehicles
    var availableVehicles: [Vehicle] {
        service.vehicles.filter { $0.assignedDriverID == nil }
    }
    
    // MARK: - Metrics Calculations
    
    var totalDriversCount: Int {
        drivers.count
    }
    
    var availableDriversCount: Int {
        drivers.filter { driver in
            !service.vehicles.contains { $0.assignedDriverID == driver.id }
        }.count
    }
    
    var assignedDriversCount: Int {
        drivers.filter { driver in
            service.vehicles.contains { $0.assignedDriverID == driver.id }
        }.count
    }
    
    var activeVehiclesCount: Int {
        service.vehicles.filter { $0.status == .active || $0.status == .inService }.count
    }
    
    var unassignedVehiclesCount: Int {
        service.vehicles.filter { $0.assignedDriverID == nil }.count
    }
    
    // MARK: - Assignment Actions
    
    func assign(vehicle: Vehicle, to driver: User) {
        // First unassign any vehicle currently assigned to this driver
        unassign(driver: driver)
        
        // Then perform the new assignment
        var updatedVehicle = vehicle
        updatedVehicle.assignedDriverID = driver.id
        
        // Update vehicle (which syncs driver profile and saves both to Supabase/MockData)
        service.updateVehicle(updatedVehicle)
        
        // Dispatch personal UUID-based notification to driver
        service.addNotification(
            userID: driver.id,
            roleTarget: nil,
            title: "New Vehicle Assigned",
            message: "You have been assigned to \(vehicle.displayName) (\(vehicle.plateNumber)).",
            category: .info
        )
        
        showSuccessToast("Assigned \(vehicle.displayName) to \(driver.name)")
    }
    
    func unassign(driver: User) {
        // Find any vehicle currently assigned to this driver and clear it
        if let vehicle = service.vehicles.first(where: { $0.assignedDriverID == driver.id }) {
            var updatedVehicle = vehicle
            updatedVehicle.assignedDriverID = nil
            service.updateVehicle(updatedVehicle)
        }
        
        // Clear driver profile assignment directly and sync to database
        var updatedDriver = driver
        updatedDriver.assignedVehicleID = nil
        service.updateUser(updatedDriver)
    }
    
    // MARK: - Helpers
    
    private func showSuccessToast(_ message: String) {
        successMessage = message
        isShowingToast = true
        
        Task {
            try? await Task.sleep(for: .seconds(3))
            isShowingToast = false
        }
    }
}
