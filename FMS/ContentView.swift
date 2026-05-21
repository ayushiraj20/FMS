//
//  ContentView.swift
//  FMS
//
//  Created by Shashwat kumar on 19/05/26.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        RootAppView()
    }
}

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
}
