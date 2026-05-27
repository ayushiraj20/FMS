//
//  NotificationScheduler.swift
//  FMS
//

import Foundation
import UserNotifications

enum NotificationScheduler {

    static func requestPermission() {

        UNUserNotificationCenter.current()
            .requestAuthorization(
                options: [.alert, .sound, .badge]
            ) { granted, error in

                if let error = error {
                    print(error.localizedDescription)
                }

                print("Permission granted: \(granted)")
            }
    }

    // MARK: - Overdue Alert

    static func scheduleOverdueAlert(
        workOrderTitle: String,
        vehicleDetail: String,
        overdueText: String,
        assignedTechID: UUID?
    ) {

        let content = UNMutableNotificationContent()

        content.title = "Critical Work Order Overdue"

        content.body =
        "\(workOrderTitle)\n\(vehicleDetail)\n\(overdueText)"

        content.sound = .defaultCritical

        content.categoryIdentifier =
        "OVERDUE_CRITICAL_WO"

        let request = UNNotificationRequest(
            identifier: "overdue-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter
            .current()
            .add(request)
    }

    // MARK: - Broadcast Alert

    static func scheduleBroadcastAlert(
        title: String,
        body: String
    ) {

        let content =
        UNMutableNotificationContent()

        content.title = title
        content.body = body
        content.sound = .default

        let request =
        UNNotificationRequest(
            identifier:
                "broadcast-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter
            .current()
            .add(request)
    }

    // MARK: - Maintenance Reminder

    static func scheduleMaintenanceReminder(
        workOrderTitle: String,
        vehicleDetail: String,
        scheduledDate: Date
    ) {

        let content = UNMutableNotificationContent()

        content.title =
        "Upcoming Maintenance Task"

        content.body =
        "\(workOrderTitle)\n\(vehicleDetail)\nStarts in 1 minute"

        content.sound = .default

        // TESTING:
        // Notify 1 minute before

        let reminderDate =
        Calendar.current.date(
            byAdding: .minute,
            value: -1,
            to: scheduledDate
        ) ?? scheduledDate

        let components =
        Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: reminderDate
        )

        let trigger =
        UNCalendarNotificationTrigger(
            dateMatching: components,
            repeats: false
        )

        let request =
        UNNotificationRequest(
            identifier:
            "maintenance-\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter
            .current()
            .add(request)
    }

    // MARK: - Trip Assignment Alert

    static func scheduleTripAssignmentAlert(
        vehiclePlate: String,
        routeText: String
    ) {
        let content = UNMutableNotificationContent()
        content.title = "New Trip Assigned"
        content.body = "You have been assigned vehicle \(vehiclePlate) for \(routeText) route."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "trip-assignment-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
