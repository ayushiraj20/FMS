//
//  FuelRepository.swift
//  FMS
//
//  Created by Ayush Ahuja on 27/05/26.
//

import Foundation
import SwiftUI

@MainActor
final class FuelRepository {
    private let service: FuelService

    init(service: FuelService) {
        self.service = service
    }

    // MARK: - Driver: Submit Refuel

    func submitRefuel(
        imageData: Data,
        amount: Double,
        litres: Double,
        odometer: Int,
        vehicleID: UUID,
        driverID: UUID,
        tripID: UUID?
    ) async throws -> FuelTransaction {
        // 1. Validate
        let prevOdo = try await service.previousOdometer(vehicleID: vehicleID)
        try await service.validate(
            amount: amount,
            litres: litres,
            odometer: odometer,
            previousOdometer: prevOdo
        )

        // 2. Upload receipt
        let transactionID = UUID()
        let receiptURL = try await service.uploadReceipt(
            imageData: imageData,
            driverID: driverID,
            transactionID: transactionID
        )

        // 3. Build transaction
        let tx = FuelTransaction(
            id: transactionID,
            vehicleID: vehicleID,
            driverID: driverID,
            tripID: tripID,
            manualAmount: amount,
            litres: litres,
            odometerReading: odometer,
            receiptImageURL: receiptURL
        )

        // 4. Save to Supabase
        try await service.saveTransaction(tx)
        return tx
    }

    // MARK: - Driver: Fetch Own

    func transactionsForDriver(_ driverID: UUID) async throws -> [FuelTransaction] {
        try await service.fetchTransactions(driverID: driverID)
    }

    // MARK: - Fleet Manager: Fetch All

    func allTransactions() async throws -> [FuelTransaction] {
        try await service.fetchAllTransactions()
    }

    // MARK: - Fleet Manager: Verify

    func verify(transactionID: UUID) async throws {
        try await service.updateVerificationStatus(
            transactionID: transactionID,
            status: .verified
        )
    }

    // MARK: - Fleet Manager: Reject

    func reject(transactionID: UUID, reason: String) async throws {
        try await service.updateVerificationStatus(
            transactionID: transactionID,
            status: .rejected,
            rejectionReason: reason
        )
    }

    // MARK: - Dashboard

    func dashboardSummary() async throws -> FuelDashboardSummary {
        try await service.fetchDashboardSummary()
    }
}
