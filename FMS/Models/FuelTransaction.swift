//
//  FuelTransaction.swift
//  FMS
//
//  Created by Ayush Ahuja on 27/05/26.
//

import Foundation

// MARK: - Verification Status

enum FuelVerificationStatus: String, Codable, CaseIterable {
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

struct FuelTransaction: Identifiable, Codable, Hashable {
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
