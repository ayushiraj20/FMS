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

    init() {
        ThemeConfigurator.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appViewModel)
        }
    }
}
