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

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case senderID = "sender_id"
        case senderName = "sender_name"
        case title
        case message
        case sentAt = "sent_at"
    }

    init(id: UUID, organizationID: UUID, senderID: UUID, senderName: String, title: String, message: String, sentAt: Date) {
        self.id = id
        self.organizationID = organizationID
        self.senderID = senderID
        self.senderName = senderName
        self.title = title
        self.message = message
        self.sentAt = sentAt
    }

    private struct DynamicCodingKeys: CodingKey {
        var stringValue: String
        init?(stringValue: String) {
            self.stringValue = stringValue
        }
        var intValue: Int?
        init?(intValue: Int) {
            return nil
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        organizationID = try container.decode(UUID.self, forKey: .organizationID)
        senderID = try container.decode(UUID.self, forKey: .senderID)
        title = try container.decode(String.self, forKey: .title)
        message = try container.decode(String.self, forKey: .message)
        sentAt = try container.decode(Date.self, forKey: .sentAt)

        // Try decoding flat sender_name
        if let directName = try? container.decode(String.self, forKey: .senderName) {
            senderName = directName
        } else {
            // Try decoding nested profiles relation
            struct ProfileName: Codable {
                let name: String
            }
            if let nestedProfile = try? decoder.container(keyedBy: DynamicCodingKeys.self)
                .decode(ProfileName.self, forKey: DynamicCodingKeys(stringValue: "profiles")!) {
                senderName = nestedProfile.name
            } else if let nestedProfilesArray = try? decoder.container(keyedBy: DynamicCodingKeys.self)
                .decode([ProfileName].self, forKey: DynamicCodingKeys(stringValue: "profiles")!),
                      let firstProfile = nestedProfilesArray.first {
                senderName = firstProfile.name
            } else {
                senderName = "Unknown Sender"
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(organizationID, forKey: .organizationID)
        try container.encode(senderID, forKey: .senderID)
        try container.encode(title, forKey: .title)
        try container.encode(message, forKey: .message)
        try container.encode(sentAt, forKey: .sentAt)
        // Omit sender_name when encoding so database insert doesn't fail on missing column
    }
}
