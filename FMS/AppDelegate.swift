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

        // Request local notification permission
        NotificationScheduler.requestPermission()

        return true
    }
}
