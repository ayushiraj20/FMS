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
    private var postgresChangeSubscription: RealtimeSubscription?

    private init() {}

    // MARK: Load existing broadcasts

    func load(orgID: UUID) async {

        isLoading = true

        defer {
            isLoading = false
        }

        if SupabaseConfig.isConfigured {
            do {
                messages = try await
                    SupabaseService.shared
                    .fetchBroadcastMessages(
                        orgID: orgID
                    )
            } catch {
                print("Load error:", error)
            }
        } else {
            messages = []
        }
    }

    // MARK: Subscribe realtime updates

    func subscribe(orgID: UUID) {

        guard SupabaseConfig.isConfigured else { return }

        unsubscribe()

        let newChannel =
        SupabaseService.shared.client
            .channel("broadcast-\(orgID)")

        postgresChangeSubscription = newChannel.onPostgresChange(
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

                    // Avoid duplicate insertion if sent from this device
                    if !self.messages.contains(where: { $0.id == msg.id }) {
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
            do {
                try await newChannel.subscribeWithError()
            } catch {
                print("Realtime subscribe error:", error)
            }
        }

        channel = newChannel
    }

    // MARK: Stop subscription

    func unsubscribe() {

        if let channel {
            postgresChangeSubscription?.cancel()
            postgresChangeSubscription = nil

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

        // Insert locally immediately (checking for duplicates just in case)
        if !self.messages.contains(where: { $0.id == msg.id }) {
            self.messages.insert(msg, at: 0)
        }

        // Trigger local push notification
        NotificationScheduler.scheduleBroadcastAlert(
            title: msg.title,
            body: "\(msg.senderName): \(msg.message)"
        )

        if SupabaseConfig.isConfigured {
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
}
