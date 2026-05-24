//
//  BroadcastComposeView.swift
//  FMS
//
//  Created by Ayush Ahuja on 22/05/26.
//

import SwiftUI

struct BroadcastComposeView: View {

    @Environment(AppViewModel.self)
    private var appViewModel

    @Environment(\.dismiss)
    private var dismiss

    @State
    private var title = ""

    @State
    private var message = ""

    @State
    private var isSending = false

    var body: some View {

        NavigationStack {

            Form {

                Section("Broadcast Title") {

                    TextField(
                        "Enter title",
                        text: $title
                    )
                }

                Section("Message") {

                    TextEditor(
                        text: $message
                    )
                    .frame(
                        minHeight: 150
                    )
                }
            }

            .navigationTitle(
                "New Broadcast"
            )

            .toolbar {

                ToolbarItem(
                    placement:
                    .topBarTrailing
                ) {

                    Button("Send") {

                        Task {

                            await sendBroadcast()

                        }
                    }
                    .disabled(
                        title.isEmpty ||
                        message.isEmpty ||
                        isSending
                    )
                }
            }

            .overlay {

                if isSending {

                    ProgressView(
                        "Sending..."
                    )
                }
            }
        }
    }

    func sendBroadcast()
    async {

        guard
            let user =
            appViewModel.currentUser,

            let orgID =
            appViewModel.currentOrganization?.id

        else {

            return
        }

        isSending = true

        defer {

            isSending = false
        }

        await BroadcastService.shared.send(

            title: title,

            message: message,

            senderID: user.id,

            senderName: user.name,

            orgID: orgID
        )

        dismiss()
    }
}
