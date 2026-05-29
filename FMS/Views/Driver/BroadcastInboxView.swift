//
//  BroadcastInboxView.swift
//  FMS
//
//  Created by Ayush Ahuja on 22/05/26.
//

import SwiftUI

struct BroadcastInboxView: View {

    @Environment(AppViewModel.self)
    private var appViewModel

    @State
    private var broadcastService =
    BroadcastService.shared

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack {
                if broadcastService.isLoading {
                    ProgressView("Loading broadcasts...")
                        .frame(maxWidth: .infinity, minHeight: 200)
                        .padding(.top, 40)
                } else if broadcastService.messages.isEmpty {
                    ContentUnavailableView(
                        "No Broadcasts",
                        systemImage: "megaphone.fill",
                        description: Text("Fleet manager messages will appear here")
                    )
                    .frame(maxWidth: .infinity, minHeight: 400)
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(broadcastService.messages) { message in
                            BroadcastRowView(message: message)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
        }
        .background(DriverTheme.background.ignoresSafeArea())
        .refreshable {
            await loadBroadcasts()
        }
        .navigationTitle("Broadcasts")
        .task {
            await loadBroadcasts()
        }
    }

    func loadBroadcasts()
    async {

        guard let orgID =
        appViewModel
        .currentOrganization?
        .id

        else {

            return

        }

        await
        BroadcastService.shared
        .load(
            orgID: orgID
        )

        
        
        BroadcastService.shared
            .subscribe(
                orgID: orgID
            )
    }
}
