import Foundation
import SwiftUI

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
        createMaintenanceID = service.users(for: .maintenance).first?.id
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
            // Immediately sync with Supabase so the new work order appears remotely
            if SupabaseConfig.isConfigured {
                Task { await service.syncWithDatabase() }
            }

        // Local notification
        if let vehicle = service.vehicle(for: vehicleID) {

            NotificationScheduler.scheduleMaintenanceReminder(
                workOrderTitle: createTitle,
                vehicleDetail: vehicle.displayName,
                scheduledDate: createScheduledDate
            )
        }

        // Notify the assigned technician directly by their UUID
        if let technicianID = createMaintenanceID {
            service.addNotification(
                userID: technicianID,         // stored in notifications.user_id → profiles.id
                roleTarget: nil,              // no role broadcast — personal notification only
                title: "New Work Order Assigned",
                message: "\(createTitle) has been assigned to you. Scheduled: \(createScheduledDate.formatted(date: .abbreviated, time: .omitted)).",
                category: .maintenance
            )
        }

        // Notify all fleet managers via role broadcast
        service.addNotification(
            userID: nil,
            roleTarget: .fleetManager,
            title: "Work Order Created",
            message: "\(createTitle) has been scheduled. Review and monitor progress.",
            category: .info
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
        // Force a remote sync so the change is reflected in Supabase immediately
        if SupabaseConfig.isConfigured {
            Task { await service.syncWithDatabase() }
        }
        selectedWorkOrder = nil
    }
}
