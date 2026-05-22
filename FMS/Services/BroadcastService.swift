//
//  BroadcastService.swift
//  FMS
//

import Foundation
import Supabase
import Observation

@Observable
@MainActor
final class BroadcastService {

    static let shared = BroadcastService()

    var messages: [BroadcastMessage] = []

    var isLoading = false

    private var channel: RealtimeChannelV2?

    private init() {}

    // MARK: Load existing broadcasts

    func load(orgID: UUID) async {

        isLoading = true

        defer {
            isLoading = false
        }

        do {

            messages = try await
                SupabaseService.shared
                .fetchBroadcastMessages(
                    orgID: orgID
                )

        } catch {

            print("Load error:", error)

        }
    }

    // MARK: Subscribe realtime updates

    func subscribe(orgID: UUID) {

        unsubscribe()

        let newChannel =
        SupabaseService.shared.client
            .channel("broadcast-\(orgID)")

        newChannel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "broadcast_messages"
        ) { [weak self] payload in

            guard let self else { return }

            Task { @MainActor in

                do {

                    let msg =
                    try payload.decodeRecord(
                        as: BroadcastMessage.self,
                        decoder: JSONDecoder()
                    )

                    self.messages.insert(
                        msg,
                        at: 0
                    )

                    NotificationScheduler
                        .scheduleBroadcastAlert(
                            title: msg.title,
                            body:
                            "\(msg.senderName): \(msg.message)"
                        )

                }
                catch {

                    print(
                        "Realtime decode error:",
                        error
                    )
                }
            }
        }

        Task {

            await newChannel.subscribe()

        }

        channel = newChannel
    }

    // MARK: Stop subscription

    func unsubscribe() {

        if let channel {

            Task {

                await channel.unsubscribe()

            }
        }

        channel = nil
    }

    // MARK: Send broadcast

    func send(
        title: String,
        message: String,
        senderID: UUID,
        senderName: String,
        orgID: UUID
    ) async {

        let msg = BroadcastMessage(
            id: UUID(),
            organizationID: orgID,
            senderID: senderID,
            senderName: senderName,
            title: title,
            message: message,
            sentAt: .now
        )

        do {

            try await
            SupabaseService.shared
                .addBroadcastMessage(
                    msg
                )

        } catch {

            print(
                "Broadcast send error:",
                error
            )
        }
    }
}
