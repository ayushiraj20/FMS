//
//  OverdueWorkOrderMonitor.swift
//  FMS
//
//  Created by Ayush Ahuja on 22/05/26.
//

import Foundation
@Observable @MainActor
final class OverdueWorkOrderMonitor {
    private let service: MockDataService
    private var timer: Timer?

    init(service: MockDataService) {
        self.service = service
    }

    func start() {
        // Fire immediately, then repeat every 60s
        checkAndFireAlerts()
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.checkAndFireAlerts()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func checkAndFireAlerts() {
        let now = Date.now
        for index in service.workOrders.indices {
            let order = service.workOrders[index]
            guard
                order.priority == .critical,
                order.status != .completed,
                order.scheduledDate < now,          // past due
                !order.overdueAlertFired            // not already alerted
            else { continue }

            let vehicle = service.vehicle(for: order.vehicleID)
            let overdueMinutes = Int(now.timeIntervalSince(order.scheduledDate) / 60)
            let overdueText = overdueMinutes >= 60
                ? "\(overdueMinutes / 60)h \(overdueMinutes % 60)m overdue"
                : "\(overdueMinutes)m overdue"

            let vehicleDetail = [
                vehicle?.displayName,
                vehicle?.model,
                vehicle?.plateNumber
            ]
            .compactMap { $0 }
            .joined(separator: " · ")

            let message = "\(order.title) — \(vehicleDetail) — \(overdueText)"

            // AC1: Notify the assigned technician
            if let techID = order.assignedMaintenanceID {
                service.addNotification(
                    userID: techID,
                    roleTarget: nil,
                    title: "⚠️ Critical Work Order Overdue",
                    message: message,
                    category: .critical
                )
            }

            // AC2: Notify all Fleet Managers
            service.addNotification(
                userID: nil,
                roleTarget: .fleetManager,
                title: "⚠️ Critical Work Order Overdue",
                message: message,
                category: .critical
            )

            // Schedule the local push notification (AC1 & AC2)
            NotificationScheduler.scheduleOverdueAlert(
                workOrderTitle: order.title,
                vehicleDetail: vehicleDetail,
                overdueText: overdueText,
                assignedTechID: order.assignedMaintenanceID
            )

            // Mark the flag so it only fires once
            service.workOrders[index].overdueAlertFired = true
            service.updateWorkOrder(service.workOrders[index])
        }
    }
}
