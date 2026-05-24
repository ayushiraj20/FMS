//
//  BroadcastMessage.swift
//  FMS
//
//  Created by Ayush Ahuja on 22/05/26.
//

import Foundation
struct BroadcastMessage: Codable, Identifiable, Hashable {

    let id: UUID
    let organizationID: UUID
    let senderID: UUID

    var senderName: String
    var title: String
    var message: String
    var sentAt: Date

    enum CodingKeys:String,CodingKey {

        case id

        case organizationID="organization_id"

        case senderID="sender_id"

        case senderName="sender_name"

        case title
        case message

        case sentAt="sent_at"
    }
}
