//
//  FuelTransaction.swift
//  FMS
//
//  Created by Ayush Ahuja on 27/05/26.
//

import Foundation

// MARK: - Verification Status

enum FuelVerificationStatus: String, Codable, CaseIterable, Sendable {
    case pending  = "Pending"
    case verified = "Verified"
    case rejected = "Rejected"

    var displayName: String { rawValue }

    var iconName: String {
        switch self {
        case .pending:  return "clock.fill"
        case .verified: return "checkmark.seal.fill"
        case .rejected: return "xmark.seal.fill"
        }
    }
}

// MARK: - Fuel Transaction

struct FuelTransaction: Identifiable, Hashable, Sendable {
    let id: UUID
    var vehicleID: UUID
    var driverID: UUID
    var tripID: UUID?
    var manualAmount: Double
    var odometerReading: Int
    var receiptImageURL: String
    var timestamp: Date
    var verificationStatus: FuelVerificationStatus
    var rejectionReason: String?

    enum CodingKeys: String, CodingKey {
        case id                 = "transactionID"
        case vehicleID          = "vehicleID"
        case driverID           = "driverID"
        case tripID             = "tripID"
        case manualAmount       = "manualAmount"
        case odometerReading    = "odometerReading"
        case receiptImageURL    = "receiptImageURL"
        case timestamp          = "timestamp"
        case verificationStatus = "verificationStatus"
        case rejectionReason    = "rejectionReason"
    }

    init(
        id: UUID = UUID(),
        vehicleID: UUID,
        driverID: UUID,
        tripID: UUID?,
        manualAmount: Double,
        odometerReading: Int,
        receiptImageURL: String
    ) {
        self.id = id
        self.vehicleID = vehicleID
        self.driverID = driverID
        self.tripID = tripID
        self.manualAmount = manualAmount
        self.odometerReading = odometerReading
        self.receiptImageURL = receiptImageURL
        self.timestamp = Date()
        self.verificationStatus = .pending
        self.rejectionReason = nil
    }
}

extension FuelTransaction: Encodable {
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(vehicleID, forKey: .vehicleID)
        try container.encode(driverID, forKey: .driverID)
        try container.encode(tripID, forKey: .tripID)
        try container.encode(manualAmount, forKey: .manualAmount)
        try container.encode(odometerReading, forKey: .odometerReading)
        try container.encode(receiptImageURL, forKey: .receiptImageURL)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(verificationStatus, forKey: .verificationStatus)
        try container.encode(rejectionReason, forKey: .rejectionReason)
    }
}

extension FuelTransaction: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        vehicleID = try container.decode(UUID.self, forKey: .vehicleID)
        driverID = try container.decode(UUID.self, forKey: .driverID)
        tripID = try container.decodeIfPresent(UUID.self, forKey: .tripID)
        manualAmount = try container.decode(Double.self, forKey: .manualAmount)
        odometerReading = try container.decode(Int.self, forKey: .odometerReading)
        receiptImageURL = try container.decode(String.self, forKey: .receiptImageURL)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        verificationStatus = try container.decode(FuelVerificationStatus.self, forKey: .verificationStatus)
        rejectionReason = try container.decodeIfPresent(String.self, forKey: .rejectionReason)
    }
}

// MARK: - Dashboard Aggregates

struct FuelDashboardSummary {
    var totalVerifiedSpend: Double
    var todayVerifiedSpend: Double
    var pendingCount: Int
    var vehicleWiseSpend: [VehicleFuelSpend]
}

struct VehicleFuelSpend: Identifiable {
    var id: UUID { vehicleID }
    var vehicleID: UUID
    var totalSpend: Double
}
