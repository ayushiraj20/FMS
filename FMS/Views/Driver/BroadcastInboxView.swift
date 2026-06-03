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
        List {
            if broadcastService.isLoading && broadcastService.messages.isEmpty {
                ProgressView("Loading broadcasts...")
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else if broadcastService.messages.isEmpty {
                ContentUnavailableView(
                    "No Broadcasts",
                    systemImage: "megaphone.fill",
                    description: Text("Fleet manager messages will appear here")
                )
                .frame(maxWidth: .infinity, minHeight: 400)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(broadcastService.messages) { message in
                    BroadcastRowView(message: message)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
        }
        .listStyle(.plain)
        .background(DriverTheme.background.ignoresSafeArea())
        .refreshable {
            await loadBroadcasts()
        }
        .navigationTitle("Broadcast")
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
