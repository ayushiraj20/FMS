//
//  FMSApp.swift
//  FMS
//
//  Created by Shashwat kumar on 19/05/26.
//

import SwiftUI

@main
struct FMSApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self)
    private var appDelegate

    @State
    private var appViewModel =
    AppViewModel()

    // Strong reference for monitoring service

    @State
    private var overdueMonitor:
    OverdueWorkOrderMonitor?

    init() {

        ThemeConfigurator.configure()

        // Request notification permission
        // (overdue alerts + broadcasts)

        NotificationScheduler
            .requestPermission()
    }

    var body: some Scene {

        WindowGroup {

            ContentView()

                .environment(
                    appViewModel
                )
                .onOpenURL { url in
                    Task {
                        await appViewModel.handleDeepLink(url)
                    }
                }

                .onAppear {

                    // Start overdue monitoring

                    overdueMonitor =
                    OverdueWorkOrderMonitor(
                        service:
                        appViewModel.service
                    )

                    overdueMonitor?
                        .start()
                }
        }
    }
}
