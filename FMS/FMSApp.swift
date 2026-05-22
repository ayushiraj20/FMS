//
//  FMSApp.swift
//  FMS
//
//  Created by Shashwat kumar on 19/05/26.
//

import SwiftUI

@main
struct FMSApp: App {
    @StateObject private var appViewModel = AppViewModel()

    init() {
        ThemeConfigurator.configure()
        NotificationManager.shared.requestPermission()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appViewModel)
        }
    }
}
