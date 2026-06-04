import Foundation
import Supabase

// MARK: - Fuel Service Errors

enum FuelServiceError: LocalizedError {
    case negativeAmount
    case zeroAmount
    case invalidLitres
    case invalidOdometer(previous: Int)
    case receiptUploadFailed(String)
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .negativeAmount:
            return "Amount cannot be negative."
        case .zeroAmount:
            return "Amount cannot be zero."
        case .invalidLitres:
            return "Litres must be greater than zero."
        case .invalidOdometer(let prev):
            return "Odometer must be greater than last recorded reading (\(prev) km)."
        case .receiptUploadFailed(let msg):
            return "Receipt upload failed: \(msg)"
        case .saveFailed(let msg):
            return "Could not save transaction: \(msg)"
        }
    }
}

// MARK: - Fuel Service

actor FuelService {
    private let client: SupabaseClient
    private let tableName = "fuelTransactions"
    private let bucketName = "fuel-receipts"

    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: - Validate

    func validate(amount: Double, litres: Double, odometer: Int, previousOdometer: Int) throws {
        guard amount >= 0 else { throw FuelServiceError.negativeAmount }
        guard amount > 0  else { throw FuelServiceError.zeroAmount }
        guard litres > 0 else { throw FuelServiceError.invalidLitres }
        guard odometer > previousOdometer else {
            throw FuelServiceError.invalidOdometer(previous: previousOdometer)
        }
    }

    // MARK: - Upload Receipt

    func uploadReceipt(
        imageData: Data,
        driverID: UUID,
        transactionID: UUID
    ) async throws -> String {
        let filePath = "\(driverID.uuidString)/\(transactionID.uuidString).jpg"

        do {
            try await client.storage
                .from(bucketName)
                .upload(
                    filePath,
                    data: imageData,
                    options: FileOptions(contentType: "image/jpeg", upsert: false)
                )
        } catch {
            throw FuelServiceError.receiptUploadFailed(error.localizedDescription)
        }

        let signedURL = try await client.storage
            .from(bucketName)
            .createSignedURL(path: filePath, expiresIn: 3600)

        return signedURL.absoluteString
    }

    // MARK: - Save Transaction

    @MainActor
    func saveTransaction(_ tx: FuelTransaction) async throws {
        do {
            try await client
                .from(tableName)
                .insert(tx)
                .execute()
        } catch {
            throw FuelServiceError.saveFailed(error.localizedDescription)
        }
    }

    // MARK: - Fetch Previous Odometer

    func previousOdometer(vehicleID: UUID) async throws -> Int {
        struct OdometerRow: Decodable {
            let odometerReading: Int
        }
        let rows: [OdometerRow] = try await client
            .from(tableName)
            .select("odometerReading")
            .eq("vehicleID", value: vehicleID.uuidString)
            .order("timestamp", ascending: false)
            .limit(1)
            .execute()
            .value
        return rows.first?.odometerReading ?? 0
    }

    // MARK: - Fetch for Driver

    func fetchTransactions(driverID: UUID) async throws -> [FuelTransaction] {
        let response: [FuelTransaction] = try await client
            .from(tableName)
            .select()
            .eq("driverID", value: driverID.uuidString)
            .order("timestamp", ascending: false)
            .execute()
            .value
        return response
    }

    // MARK: - Fetch All (Fleet Manager)

    func fetchAllTransactions() async throws -> [FuelTransaction] {
        let response: [FuelTransaction] = try await client
            .from(tableName)
            .select()
            .order("timestamp", ascending: false)
            .execute()
            .value
        return response
    }

    // MARK: - Verify / Reject

    func updateVerificationStatus(
        transactionID: UUID,
        status: FuelVerificationStatus,
        rejectionReason: String? = nil
    ) async throws {
        struct UpdatePayload: Encodable {
            let verificationStatus: String
            let rejectionReason: String?
        }
        let payload = UpdatePayload(
            verificationStatus: status.rawValue,
            rejectionReason: rejectionReason
        )
        try await client
            .from(tableName)
            .update(payload)
            .eq("transactionID", value: transactionID.uuidString)
            .execute()
    }

    // MARK: - Dashboard Aggregates

    func fetchTotalVerifiedSpend() async throws -> Double {
        struct Row: Decodable { let manualAmount: Double }
        let rows: [Row] = try await client
            .from(tableName)
            .select("manualAmount")
            .eq("verificationStatus", value: "Verified")
            .execute()
            .value
        return rows.reduce(0) { $0 + $1.manualAmount }
    }

    func fetchTodayVerifiedSpend() async throws -> Double {
        let rows: [FuelTransaction] = try await client
            .from(tableName)
            .select()
            .eq("verificationStatus", value: "Verified")
            .gte("timestamp", value: ISO8601DateFormatter().string(
                from: Calendar.current.startOfDay(for: Date())
            ))
            .execute()
            .value
        return rows.reduce(0) { $0 + $1.manualAmount }
    }

    func fetchPendingCount() async throws -> Int {
        let rows: [FuelTransaction] = try await client
            .from(tableName)
            .select()
            .eq("verificationStatus", value: "Pending")
            .execute()
            .value
        return rows.count
    }

    func fetchVehicleWiseSpend() async throws -> [VehicleFuelSpend] {
        struct Row: Decodable {
            let vehicleID: String
            let manualAmount: Double
        }
        let rows: [Row] = try await client
            .from(tableName)
            .select("vehicleID, manualAmount")
            .eq("verificationStatus", value: "Verified")
            .execute()
            .value

        var grouped: [String: Double] = [:]
        for row in rows {
            grouped[row.vehicleID, default: 0] += row.manualAmount
        }
        return grouped.compactMap { key, total in
            guard let vid = UUID(uuidString: key) else { return nil }
            return VehicleFuelSpend(vehicleID: vid, totalSpend: total)
        }.sorted { $0.totalSpend > $1.totalSpend }
    }

    func fetchDashboardSummary() async throws -> FuelDashboardSummary {
        async let total    = fetchTotalVerifiedSpend()
        async let today    = fetchTodayVerifiedSpend()
        async let pending  = fetchPendingCount()
        async let vehicles = fetchVehicleWiseSpend()

        return try await FuelDashboardSummary(
            totalVerifiedSpend: total,
            todayVerifiedSpend: today,
            pendingCount: pending,
            vehicleWiseSpend: vehicles
        )
    }
}
