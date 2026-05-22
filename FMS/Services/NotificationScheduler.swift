//
//  NotificationScheduler.swift
//  FMS
//
//  Created by Ayush Ahuja on 22/05/26.
//

import Foundation
import UserNotifications

enum NotificationScheduler {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { _, _ in }
    }

    static func scheduleOverdueAlert(
        workOrderTitle: String,
        vehicleDetail: String,
        overdueText: String,
        assignedTechID: UUID?
    ) {
        let content = UNMutableNotificationContent()
        content.title = "Critical Work Order Overdue"
        // AC4: includes WO name, vehicle details, how long overdue
        content.body = "\(workOrderTitle)\n\(vehicleDetail)\n\(overdueText)"
        content.sound = .defaultCritical
        content.categoryIdentifier = "OVERDUE_CRITICAL_WO"
        // Deliver immediately (trigger = nil means now)
        let request = UNNotificationRequest(
            identifier: "overdue-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
