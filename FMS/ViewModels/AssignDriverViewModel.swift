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
    
    func assignPair() {
        guard let vehicle = selectedVehicle, let driver = selectedDriver else { return }
        
        var updatedVehicle = vehicle
        updatedVehicle.assignedDriverID = driver.id
        
        // Update vehicle which syncs driver assignment
        service.updateVehicle(updatedVehicle)
        
        // Dispatch personal UUID-based notification to driver
        service.addNotification(
            userID: driver.id,
            roleTarget: nil,
            title: "New Vehicle Assigned",
            message: "You have been assigned to \(vehicle.displayName) (\(vehicle.plateNumber)).",
            category: .info
        )
        
        // Show Toast/Success feedback
        assignmentSuccessMessage = "Assigned \(driver.name.components(separatedBy: " ").first ?? driver.name) to \(vehicle.displayName)"
        isShowingSuccessToast = true
        
        // Clear Selections
        selectedVehicle = nil
        selectedDriver = nil
        
        // Auto-dismiss success toast after 3 seconds
        Task {
            try? await Task.sleep(for: .seconds(3))
            isShowingSuccessToast = false
        }
    }
    
    func smartMatchAll() {
        let drivers = unassignedDrivers
        let vehicles = unassignedVehicles
        
        guard !drivers.isEmpty && !vehicles.isEmpty else { return }
        
        let matchCount = min(drivers.count, vehicles.count)
        
        for i in 0..<matchCount {
            let driver = drivers[i]
            let vehicle = vehicles[i]
            
            var updatedVehicle = vehicle
            updatedVehicle.assignedDriverID = driver.id
            
            service.updateVehicle(updatedVehicle)
            
            // Dispatch personal notification to the driver
            service.addNotification(
                userID: driver.id,
                roleTarget: nil,
                title: "New Vehicle Assigned (Auto)",
                message: "You have been auto-assigned to \(vehicle.displayName) (\(vehicle.plateNumber)).",
                category: .info
            )
        }
        
        // Show Toast/Success feedback
        assignmentSuccessMessage = "Smart Matched \(matchCount) Driver\(matchCount > 1 ? "s" : "") & Vehicle\(matchCount > 1 ? "s" : "")!"
        isShowingSuccessToast = true
        
        // Clear selection just in case
        selectedVehicle = nil
        selectedDriver = nil
        
        Task {
            try? await Task.sleep(for: .seconds(3))
            isShowingSuccessToast = false
        }
    }
}
