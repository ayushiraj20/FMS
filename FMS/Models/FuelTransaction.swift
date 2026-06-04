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

// MARK: - Fuel Efficiency & Carbon Analytics

enum CarbonEfficiencyAnalytics {
    static let dieselEmissionKGPerLitre = 2.68
    static let estimatedDieselPricePerLitreINR = 95.0
    static let targetEfficiencyKMPerLitre = 10.0

    static func dashboardSummary(
        trips: [Trip],
        vehicles: [Vehicle],
        drivers: [User],
        fuelReceipts: [FuelReceipt],
        fuelTransactions: [FuelTransaction],
        monthContaining date: Date = .now
    ) -> CarbonDashboardSummary {
        let interval = Calendar.current.dateInterval(of: .month, for: date)
        let monthlyTrips = trips.filter { trip in
            trip.status == .completed &&
            trip.distanceKM > 0 &&
            interval?.contains(trip.startDate) != false
        }
        let monthlyReceipts = fuelReceipts.filter { interval?.contains($0.date) != false }
        let monthlyTransactions = fuelTransactions.filter {
            $0.verificationStatus != .rejected &&
            interval?.contains($0.timestamp) != false
        }

        let fleetDistance = monthlyTrips.reduce(0) { $0 + $1.distanceKM }
        let fleetLitres = fuelLitres(receipts: monthlyReceipts, transactions: monthlyTransactions)
        let fleetEfficiency = efficiency(distanceKM: fleetDistance, litres: fleetLitres)
        let fleetCO2 = fleetLitres * dieselEmissionKGPerLitre
        let targetLitres = fleetDistance / targetEfficiencyKMPerLitre
        let wastedLitres = max(0, fleetLitres - targetLitres)

        let vehicleMetrics = vehicles.compactMap { vehicle -> CarbonPerformanceMetric? in
            let vehicleTrips = monthlyTrips.filter { $0.vehicleID == vehicle.id }
            let distance = vehicleTrips.reduce(0) { $0 + $1.distanceKM }
            let litres = fuelLitres(
                receipts: monthlyReceipts.filter { $0.vehicleID == vehicle.id },
                transactions: monthlyTransactions.filter { $0.vehicleID == vehicle.id }
            )
            guard distance > 0 || litres > 0 else { return nil }
            return CarbonPerformanceMetric(
                id: vehicle.id,
                name: vehicle.displayName,
                subtitle: vehicle.plateNumber,
                distanceKM: distance,
                litres: litres,
                carbonKG: litres * dieselEmissionKGPerLitre
            )
        }

        let driverMetrics = drivers.filter { $0.role == .driver }.compactMap { driver -> CarbonPerformanceMetric? in
            let driverTrips = monthlyTrips.filter { $0.driverID == driver.id }
            let distance = driverTrips.reduce(0) { $0 + $1.distanceKM }
            let litres = fuelLitres(
                receipts: monthlyReceipts.filter { $0.driverID == driver.id },
                transactions: monthlyTransactions.filter { $0.driverID == driver.id }
            )
            guard distance > 0 || litres > 0 else { return nil }
            return CarbonPerformanceMetric(
                id: driver.id,
                name: driver.name,
                subtitle: driver.title,
                distanceKM: distance,
                litres: litres,
                carbonKG: litres * dieselEmissionKGPerLitre
            )
        }

        return CarbonDashboardSummary(
            fleetEfficiencyKMPerLitre: fleetEfficiency,
            fleetCO2KG: fleetCO2,
            potentialSavingsINR: wastedLitres * estimatedDieselPricePerLitreINR,
            potentialLitresSaved: wastedLitres,
            vehicleMetrics: vehicleMetrics.sortedForWaste(),
            driverMetrics: driverMetrics.sortedForWaste()
        )
    }

    static func driverSummary(
        driverID: UUID,
        trips: [Trip],
        fuelReceipts: [FuelReceipt],
        fuelTransactions: [FuelTransaction],
        monthContaining date: Date = .now
    ) -> CarbonDriverSummary {
        let interval = Calendar.current.dateInterval(of: .month, for: date)
        let monthlyTrips = trips.filter {
            $0.driverID == driverID &&
            $0.status == .completed &&
            $0.distanceKM > 0 &&
            interval?.contains($0.startDate) != false
        }
        let monthlyReceipts = fuelReceipts.filter {
            $0.driverID == driverID && interval?.contains($0.date) != false
        }
        let monthlyTransactions = fuelTransactions.filter {
            $0.driverID == driverID &&
            $0.verificationStatus != .rejected &&
            interval?.contains($0.timestamp) != false
        }
        let distance = monthlyTrips.reduce(0) { $0 + $1.distanceKM }
        let litres = fuelLitres(receipts: monthlyReceipts, transactions: monthlyTransactions)
        let monthlyEfficiency = efficiency(distanceKM: distance, litres: litres)
        let lastTrip = trips
            .filter { $0.driverID == driverID && $0.status == .completed }
            .sorted { $0.startDate > $1.startDate }
            .first
            .map { trip in
                let tripLitres = fuelTransactions
                    .filter { $0.tripID == trip.id && $0.verificationStatus != .rejected }
                    .reduce(0) { $0 + CarbonEfficiencyAnalytics.litres(fromSpend: $1.manualAmount) }
                return CarbonLastTripPerformance(
                    tripID: trip.id,
                    route: "\(trip.origin) → \(trip.destination)",
                    distanceKM: trip.distanceKM,
                    efficiencyKMPerLitre: efficiency(distanceKM: trip.distanceKM, litres: tripLitres)
                )
            }

        return CarbonDriverSummary(
            efficiencyKMPerLitre: monthlyEfficiency,
            grade: CarbonGrade.grade(for: monthlyEfficiency),
            carbonKG: litres * dieselEmissionKGPerLitre,
            litres: litres,
            distanceKM: distance,
            lastTrip: lastTrip
        )
    }

    static func litres(fromSpend amount: Double) -> Double {
        guard estimatedDieselPricePerLitreINR > 0 else { return 0 }
        return amount / estimatedDieselPricePerLitreINR
    }

    private static func fuelLitres(receipts: [FuelReceipt], transactions: [FuelTransaction]) -> Double {
        let receiptLitres = receipts.reduce(0) { $0 + $1.litres }
        let transactionLitres = transactions.reduce(0) { $0 + litres(fromSpend: $1.manualAmount) }
        return receiptLitres + transactionLitres
    }

    private static func efficiency(distanceKM: Double, litres: Double) -> Double? {
        guard distanceKM > 0, litres > 0 else { return nil }
        return distanceKM / litres
    }
}

struct CarbonDashboardSummary {
    var fleetEfficiencyKMPerLitre: Double?
    var fleetCO2KG: Double
    var potentialSavingsINR: Double
    var potentialLitresSaved: Double
    var vehicleMetrics: [CarbonPerformanceMetric]
    var driverMetrics: [CarbonPerformanceMetric]
}

struct CarbonDriverSummary {
    var efficiencyKMPerLitre: Double?
    var grade: CarbonGrade
    var carbonKG: Double
    var litres: Double
    var distanceKM: Double
    var lastTrip: CarbonLastTripPerformance?
}

struct CarbonLastTripPerformance {
    var tripID: UUID
    var route: String
    var distanceKM: Double
    var efficiencyKMPerLitre: Double?
}

struct CarbonPerformanceMetric: Identifiable, Hashable {
    var id: UUID
    var name: String
    var subtitle: String
    var distanceKM: Double
    var litres: Double
    var carbonKG: Double

    var efficiencyKMPerLitre: Double? {
        guard distanceKM > 0, litres > 0 else { return nil }
        return distanceKM / litres
    }

    var potentialSavingsINR: Double {
        guard litres > 0 else { return 0 }
        let targetLitres = distanceKM / CarbonEfficiencyAnalytics.targetEfficiencyKMPerLitre
        let wastedLitres = max(0, litres - targetLitres)
        return wastedLitres * CarbonEfficiencyAnalytics.estimatedDieselPricePerLitreINR
    }
}

enum CarbonGrade: String {
    case a = "A"
    case b = "B"
    case c = "C"
    case d = "D"

    static func grade(for efficiency: Double?) -> CarbonGrade {
        guard let efficiency else { return .d }
        if efficiency >= 10 { return .a }
        if efficiency >= 8 { return .b }
        if efficiency >= 6 { return .c }
        return .d
    }
}

private extension Array where Element == CarbonPerformanceMetric {
    func sortedForWaste() -> [CarbonPerformanceMetric] {
        sorted {
            if $0.potentialSavingsINR == $1.potentialSavingsINR {
                return ($0.efficiencyKMPerLitre ?? .greatestFiniteMagnitude) < ($1.efficiencyKMPerLitre ?? .greatestFiniteMagnitude)
            }
            return $0.potentialSavingsINR > $1.potentialSavingsINR
        }
    }
}
