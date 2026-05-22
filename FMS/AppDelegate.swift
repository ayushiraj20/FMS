//
//  AppDelegate.swift
//  FMS
//

import UIKit

final class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {

        application.registerForRemoteNotifications()

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {

        let token = deviceToken
            .map { String(format: "%02.2hhx", $0) }
            .joined()

        print("APNS token: \(token)")
    }
}

// Xcode setup required for background broadcast notifications:
// 1. Add the Push Notifications capability.
// 2. Add Background Modes and enable:
//    - Remote notifications
//    - Background fetch
