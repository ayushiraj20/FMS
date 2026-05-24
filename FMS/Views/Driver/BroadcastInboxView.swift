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

        Group {

            // Loading state

            if broadcastService.isLoading {

                ProgressView(
                    "Loading broadcasts..."
                )
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
            }

            // Empty state

            else if broadcastService.messages.isEmpty {

                ContentUnavailableView(
                    "No Broadcasts",
                    systemImage:
                    "megaphone.fill",
                    description:
                    Text(
                    "Fleet manager messages will appear here"
                    )
                )
            }

            // Message list

            else {

                List(
                    broadcastService.messages
                ) { message in

                    BroadcastRowView(
                        message: message
                    )

                }
            }
        }

        .navigationTitle(
            "Broadcasts"
        )

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
    }
}
