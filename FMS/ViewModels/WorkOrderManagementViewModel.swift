import Foundation
import SwiftUI
import Combine
import Observation

@Observable
@MainActor
final class WorkOrderManagementViewModel {
    private let service: MockDataService
    private let currentOrgID: UUID?

    // List State
    var searchText = ""
    var selectedWorkOrder: WorkOrder? = nil
    var isPresentingCreateSheet = false

    // Create Form Fields
    var createVehicleID: UUID? = nil
    var createMaintenanceID: UUID? = nil
    var createTitle = ""
    var createDetails = ""
    var createPriority: WorkOrderPriority = .medium
    var createScheduledDate = Date.now

    // Detail/Edit Form Fields
    var editStatus: WorkOrderStatus = .open
    var editRepairSummary = ""
    var editCompletedDate = Date.now

    init(service: MockDataService, currentOrgID: UUID?) {
        self.service = service
        self.currentOrgID = currentOrgID
    }

    var filteredOrders: [WorkOrder] {
        service.workOrders.filter {
            searchText.isEmpty ||
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.details.localizedCaseInsensitiveContains(searchText)
        }
    }

    var vehicles: [Vehicle] {
        service.vehicles
    }

    var technicians: [User] {
        service.users(for: .maintenance)
    }

    func vehicle(for vehicleID: UUID) -> Vehicle? {
        service.vehicle(for: vehicleID)
    }

    func prepareCreateOrder() {
        createVehicleID = service.vehicles.first?.id
        createMaintenanceID = nil
        createTitle = ""
        createDetails = ""
        createPriority = .medium
        createScheduledDate = Date.now
        isPresentingCreateSheet = true
    }

    func createWorkOrder() {
        guard let vehicleID = createVehicleID else { return }
        service.addWorkOrder(
            vehicleID: vehicleID,
            assignedMaintenanceID: createMaintenanceID,
            title: createTitle,
            details: createDetails,
            priority: createPriority,
            scheduledDate: createScheduledDate
        )
        isPresentingCreateSheet = false
    }

    func prepareEditOrder(_ order: WorkOrder) {
        selectedWorkOrder = order
        editStatus = order.status
        editRepairSummary = order.repairSummary
        editCompletedDate = order.completedDate ?? Date.now
    }

    func saveWorkOrder() {
        guard var order = selectedWorkOrder else { return }
        order.status = editStatus
        order.repairSummary = editRepairSummary
        if editStatus == .completed {
            order.completedDate = editCompletedDate
        } else {
            order.completedDate = nil
        }
        service.updateWorkOrder(order)
        selectedWorkOrder = nil
    }
}
