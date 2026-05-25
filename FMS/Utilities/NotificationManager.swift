//
//  NotificationManager.swift
//  FMS
//
//  Created by Shashwat kumar on 22/05/26.
//

import Foundation
import UserNotifications

class NotificationManager {

    static let shared = NotificationManager()

    func requestPermission() {

        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .sound, .badge]
        ) { success, error in

            if success {
                print("Permission granted")
            }
        }
    }

    func sendLocalNotification(
        title: String,
        body: String
    ) {

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 5,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }
}
