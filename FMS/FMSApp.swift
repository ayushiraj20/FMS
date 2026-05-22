//
//  FMSApp.swift
//  FMS
//
//  Created by Shashwat kumar on 19/05/26.
//

import SwiftUI

@main
struct FMSApp: App {
    @State private var appViewModel = AppViewModel()
    // Hold a strong reference
    @State private var overdueMonitor: OverdueWorkOrderMonitor?

    init() {
        ThemeConfigurator.configure()
        NotificationScheduler.requestPermission()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appViewModel)
                .onAppear {
                    overdueMonitor = OverdueWorkOrderMonitor(service: appViewModel.service)
                    overdueMonitor?.start()
                }
        }
    }
}
