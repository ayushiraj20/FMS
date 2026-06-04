//
//  FuelViewModel.swift
//  FMS
//
//  Created by Ayush Ahuja on 27/05/26.
//

import Foundation
import SwiftUI
import Observation

@Observable
final class FuelViewModel {

    // MARK: - Driver Submission State

    var amountText: String = ""
    var litresText: String = ""
    var odometerText: String = ""
    var receiptImageData: Data? = nil
    var receiptImage: Image? = nil
    var isUploadingReceipt: Bool = false
    var receiptUploadSucceeded: Bool = false
    var isSubmitting: Bool = false
    var submissionError: String? = nil
    var submissionSuccess: Bool = false

    // MARK: - Computed Guards

    var canSubmit: Bool {
        !amountText.isEmpty &&
        !litresText.isEmpty &&
        !odometerText.isEmpty &&
        receiptUploadSucceeded &&
        !isSubmitting
    }

    var resumeTripBlocked: Bool {
        !receiptUploadSucceeded
    }

    // MARK: - Fleet Manager State

    var allTransactions: [FuelTransaction] = []
    var isLoadingTransactions: Bool = false
    var verificationError: String? = nil

    // MARK: - Dashboard State

    var dashboardSummary: FuelDashboardSummary? = nil

    // MARK: - Repository

    private let repo: FuelRepository

    init(repo: FuelRepository) {
        self.repo = repo
    }

    // MARK: - Driver: Set Receipt

    func setReceipt(data: Data, image: Image) {
        receiptImageData = data
        receiptImage = image
        receiptUploadSucceeded = true
    }

    func clearReceipt() {
        receiptImageData = nil
        receiptImage = nil
        receiptUploadSucceeded = false
    }

    // MARK: - Driver: Submit Refuel

    func submitRefuel(vehicleID: UUID, driverID: UUID, tripID: UUID?) async {
        guard let imageData = receiptImageData else {
            submissionError = "Receipt upload required."
            return
        }
        guard let amount = Double(amountText) else {
            submissionError = "Enter a valid fuel amount."
            return
        }
        guard amount > 0 else {
            submissionError = "Amount cannot be zero or negative."
            return
        }
        guard let litres = Double(litresText), litres > 0 else {
            submissionError = "Enter valid fuel litres."
            return
        }
        guard let odometer = Int(odometerText), odometer > 0 else {
            submissionError = "Enter a valid odometer reading."
            return
        }

        isSubmitting = true
        submissionError = nil

        do {
            _ = try await repo.submitRefuel(
                imageData: imageData,
                amount: amount,
                litres: litres,
                odometer: odometer,
                vehicleID: vehicleID,
                driverID: driverID,
                tripID: tripID
            )
            submissionSuccess = true
            resetForm()
        } catch let error as FuelServiceError {
            submissionError = error.errorDescription
        } catch {
            submissionError = error.localizedDescription
        }

        isSubmitting = false
    }

    private func resetForm() {
        amountText = ""
        litresText = ""
        odometerText = ""
        receiptImageData = nil
        receiptImage = nil
        receiptUploadSucceeded = false
    }

    // MARK: - Fleet Manager: Load All

    func loadAllTransactions() async {
        isLoadingTransactions = true
        verificationError = nil
        do {
            allTransactions = try await repo.allTransactions()
        } catch {
            verificationError = error.localizedDescription
        }
        isLoadingTransactions = false
    }

    // MARK: - Fleet Manager: Verify

    func verify(transaction: FuelTransaction) async {
        do {
            try await repo.verify(transactionID: transaction.id)
            await loadAllTransactions()
        } catch {
            verificationError = error.localizedDescription
        }
    }

    // MARK: - Fleet Manager: Reject

    func reject(transaction: FuelTransaction, reason: String) async {
        do {
            try await repo.reject(transactionID: transaction.id, reason: reason)
            await loadAllTransactions()
        } catch {
            verificationError = error.localizedDescription
        }
    }

    // MARK: - Dashboard

    func loadDashboard() async {
        do {
            dashboardSummary = try await repo.dashboardSummary()
        } catch {
            print("FuelViewModel dashboard error: \(error)")
        }
    }
}
