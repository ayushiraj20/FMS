import Foundation
import Supabase

@MainActor
final class SupabaseService {
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    
    private init() {
        self.client = SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.key)
    }
    
    // MARK: - Password Reset
    func resetPassword(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email, redirectTo: URL(string: "fleeto://reset-callback"))
    }

    func handleSessionFromURL(_ url: URL) async throws -> Session {
        return try await client.auth.session(from: url)
    }

    // Organizations
    func fetchOrganizations() async throws -> [Organization] {
        let orgs: [Organization] = try await client.from("organizations").select().execute().value
        return orgs
    }
    
    func addOrganization(_ organization: Organization) async throws {
        try await client.from("organizations").insert(organization).execute()
    }
    
    // Profiles
    func fetchProfiles() async throws -> [User] {
        let profiles: [User] = try await client.from("profiles").select().execute().value
        return profiles
    }
    
    func addProfile(_ user: User) async throws {
        try await client.from("profiles").insert(user).execute()
    }
    
    func updateProfile(_ user: User) async throws {
        try await client.from("profiles")
            .update(user)
            .eq("id", value: user.id)
            .execute()
    }

    func updateDriverDutyStatus(driverID: UUID, status: DutyStatus) async throws {
        struct DutyStatusPayload: Encodable {
            let duty_status: String
        }

        try await client.from("profiles")
            .update(DutyStatusPayload(duty_status: status.rawValue))
            .eq("id", value: driverID)
            .execute()
    }
    
    func deleteProfile(_ user: User) async throws {
        try await client.from("profiles")
            .delete()
            .eq("id", value: user.id)
            .execute()
    }
    
    struct CreateUserParams: Codable {
        let p_email: String
        let p_password: String
        let p_name: String
        let p_role: String
        let p_phone: String
        let p_title: String
        let p_organization_id: UUID
    }
    
    func createUserAdmin(email: String, name: String, role: UserRole, phone: String, title: String, organizationID: UUID) async throws {
        let params = CreateUserParams(
            p_email: email,
            p_password: "demo123",
            p_name: name,
            p_role: role.rawValue,
            p_phone: phone,
            p_title: title,
            p_organization_id: organizationID
        )
        try await client.rpc("create_user_admin", params: params).execute()
    }
    
    // Vehicles
    func fetchVehicles() async throws -> [Vehicle] {
        let vehicles: [Vehicle] = try await client.from("vehicles").select().execute().value
        return vehicles
    }
    
    func addVehicle(_ vehicle: Vehicle) async throws {
        try await client.from("vehicles").insert(vehicle).execute()
    }
    
    func updateVehicle(_ vehicle: Vehicle) async throws {
        try await client.from("vehicles")
            .update(vehicle)
            .eq("id", value: vehicle.id)
            .execute()
    }
    
    func deleteVehicle(_ vehicle: Vehicle) async throws {
        try await client.from("vehicles")
            .delete()
            .eq("id", value: vehicle.id)
            .execute()
    }
    
    // Vehicle Documents
    func fetchDocuments() async throws -> [VehicleDocument] {
        let docs: [VehicleDocument] = try await client.from("vehicle_documents").select().execute().value
        return docs
    }
    
    func addDocument(_ document: VehicleDocument) async throws {
        try await client.from("vehicle_documents").insert(document).execute()
    }
    
    func updateDocument(_ document: VehicleDocument) async throws {
        try await client.from("vehicle_documents")
            .update(document)
            .eq("id", value: document.id)
            .execute()
    }
    
    func uploadDocumentImage(
        imageData: Data,
        vehicleID: UUID,
        documentType: String
    ) async throws -> String {
        let bucketName = "vehicle-documents"
        let filePath = "\(vehicleID.uuidString)/\(documentType).jpg"
        
        try await client.storage
            .from(bucketName)
            .upload(
                filePath,
                data: imageData,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )
            
        let signedURL = try await client.storage
            .from(bucketName)
            .createSignedURL(path: filePath, expiresIn: 315360000) // 10 years
            
        return signedURL.absoluteString
    }
    
    // Trips
    func fetchTrips() async throws -> [Trip] {
        let trips: [Trip] = try await client.from("trips").select().execute().value
        return trips
    }
    
    func addTrip(_ trip: Trip) async throws {
        try await client.from("trips").insert(trip).execute()
    }
    
    func updateTrip(_ trip: Trip) async throws {
        try await client.from("trips")
            .update(trip)
            .eq("id", value: trip.id)
            .execute()
    }
    
    // Inspections
    func fetchInspections() async throws -> [InspectionRecord] {
        let records: [InspectionRecord] = try await client.from("inspection_records")
            .select("*, items:inspection_items(*)")
            .execute()
            .value
        return records
    }
    
    func addInspection(_ record: InspectionRecord) async throws {
        try await client.from("inspection_records").insert(record).execute()
        for item in record.items {
            var dbItem = item
            dbItem.inspectionRecordID = record.id
            try await client.from("inspection_items").insert(dbItem).execute()
        }
    }
    
    // Defects
    func fetchDefects() async throws -> [DefectReport] {
        let defects: [DefectReport] = try await client.from("defect_reports").select().execute().value
        return defects
    }
    
    /// Upload a defect photo to the `defect-photos` storage bucket.
    /// Returns the signed URL string to store in the `defect_reports.images` column.
    func uploadDefectPhoto(
        imageData: Data,
        vehicleID: UUID,
        defectID: UUID,
        index: Int
    ) async throws -> String {
        let bucketName = "defect-photos"
        let filePath = "\(vehicleID.uuidString)/\(defectID.uuidString)_\(index).jpg"

        try await client.storage
            .from(bucketName)
            .upload(
                filePath,
                data: imageData,
                options: FileOptions(contentType: "image/jpeg", upsert: true)
            )

        let signedURL = try await client.storage
            .from(bucketName)
            .createSignedURL(path: filePath, expiresIn: 315360000) // 10 years

        return signedURL.absoluteString
    }

    func addDefect(_ defect: DefectReport) async throws {
        try await client.from("defect_reports").insert(defect).execute()
    }
    
    func updateDefect(_ defect: DefectReport) async throws {
        try await client.from("defect_reports")
            .update(defect)
            .eq("id", value: defect.id)
            .execute()
    }
    
    // Work Orders
    func fetchWorkOrders() async throws -> [WorkOrder] {
        let orders: [WorkOrder] = try await client.from("work_orders").select().execute().value
        return orders
    }
    
    func addWorkOrder(_ order: WorkOrder) async throws {
        try await client.from("work_orders").insert(order).execute()
    }
    
    func updateWorkOrder(_ order: WorkOrder) async throws {
        try await client.from("work_orders")
            .upsert(order)
            .execute()
    }
    
    // Maintenance Schedules
    func fetchSchedules() async throws -> [MaintenanceSchedule] {
        let schedules: [MaintenanceSchedule] = try await client.from("maintenance_schedules").select().execute().value
        return schedules
    }
    
    func fetchBroadcastMessages(
        orgID: UUID
    ) async throws -> [BroadcastMessage] {

        let rows: [BroadcastMessage] =
        try await client
            .from("broadcast_messages")
            .select("""
            id,
            organization_id,
            sender_id,
            profiles(name),
            title,
            message,
            sent_at
            """)
            .eq("organization_id", value: orgID)
            .order("sent_at", ascending: false)
            .execute()
            .value

        return rows
    }

    func addBroadcastMessage(
        _ message: BroadcastMessage
    ) async throws {

        try await client
            .from("broadcast_messages")
            .insert(message)
            .execute()
    }
    
    // Notifications
    /// Fetch ALL notifications (used only for full sync / admin)
    func fetchNotifications() async throws -> [AppNotification] {
        let alerts: [AppNotification] = try await client
            .from("notifications")
            .select()
            .execute()
            .value
        return alerts
    }

    /// Fetch notifications for a specific logged-in user using their UUID.
    /// Returns:
    ///   - Notifications where user_id == currentUser.id  (personal)
    ///   - Notifications where role_target == currentUser.role (role-broadcast)
    ///   - Notifications where both user_id and role_target are null (global broadcast)
    func fetchNotificationsForUser(userID: UUID, roleRawValue: String) async throws -> [AppNotification] {
        let all: [AppNotification] = try await client
            .from("notifications")
            .select()
            .execute()
            .value

        return all.filter {
            // Personal: directly addressed to this user's UUID
            $0.userID == userID ||
            // Role-broadcast: addressed to this user's role
            $0.roleTarget?.rawValue == roleRawValue ||
            // Global broadcast: no user and no role target
            ($0.userID == nil && $0.roleTarget == nil)
        }
        .sorted { $0.date > $1.date }
    }

    func addNotification(_ alert: AppNotification) async throws {
        try await client.from("notifications").insert(alert).execute()
    }

    func updateNotification(_ alert: AppNotification) async throws {
        try await client.from("notifications")
            .update(alert)
            .eq("id", value: alert.id)
            .execute()
    }

    // MARK: - Chat Messages
    func fetchChatMessages() async throws -> [ChatMessage] {
        let messages: [ChatMessage] = try await client
            .from("chat_messages")
            .select()
            .execute()
            .value
        return messages
    }

    func addChatMessage(_ message: ChatMessage) async throws {
        try await client
            .from("chat_messages")
            .insert(message)
            .execute()
    }
    
    // MARK: - SOS Alerts
    func fetchSOSAlerts() async throws -> [SOSAlert] {
        let alerts: [SOSAlert] = try await client
            .from("sos_alerts")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        return alerts
    }

    // Only send the fields the driver populates; let Supabase auto-generate id/created_at
    struct SOSAlertInsert: Encodable {
        let driver_id: UUID
        let driver_name: String
        let vehicle_id: UUID
        let vehicle_number: String
        let emergency_type: String
        let latitude: Double
        let longitude: Double
        let description: String?
        let status: String
    }

    func addSOSAlert(_ alert: SOSAlert) async throws {
        let payload = SOSAlertInsert(
            driver_id: alert.driverID,
            driver_name: alert.driverName,
            vehicle_id: alert.vehicleID,
            vehicle_number: alert.vehicleNumber,
            emergency_type: alert.emergencyType,
            latitude: alert.latitude,
            longitude: alert.longitude,
            description: alert.description,
            status: alert.status
        )
        try await client
            .from("sos_alerts")
            .insert(payload)
            .execute()
    }

    // Only update the status field
    struct SOSAlertStatusUpdate: Encodable {
        let status: String
    }

    func updateSOSAlert(_ alert: SOSAlert) async throws {
        let payload = SOSAlertStatusUpdate(status: alert.status)
        try await client
            .from("sos_alerts")
            .update(payload)
            .eq("id", value: alert.id)
            .execute()
    }

    // MARK: - Spare Parts
    func fetchSpareParts(organizationID: UUID) async throws -> [SparePart] {
        let parts: [SparePart] = try await client
            .from("spare_parts")
            .select()
            .eq("organization_id", value: organizationID)
            .order("name")
            .execute()
            .value
        return parts
    }

    func addSparePart(_ part: SparePart) async throws {
        try await client
            .from("spare_parts")
            .insert(part)
            .execute()
    }

    func updateSparePart(_ part: SparePart) async throws {
        struct SparePartUpdate: Encodable {
            let name: String
            let part_number: String
            let category: String
            let quantity: Int
            let minimum_required: Int
            let icon: String
        }
        let payload = SparePartUpdate(
            name: part.name,
            part_number: part.partNumber,
            category: part.category,
            quantity: part.quantity,
            minimum_required: part.minimumRequired,
            icon: part.icon
        )
        try await client
            .from("spare_parts")
            .update(payload)
            .eq("id", value: part.id)
            .execute()
    }

    func deleteSparePart(_ part: SparePart) async throws {
        try await client
            .from("spare_parts")
            .delete()
            .eq("id", value: part.id)
            .execute()
    }

    // MARK: - Part Orders
    func fetchPartOrders(organizationID: UUID) async throws -> [PartOrder] {
        let orders: [PartOrder] = try await client
            .from("part_orders")
            .select()
            .eq("organization_id", value: organizationID)
            .order("order_date", ascending: false)
            .execute()
            .value
        return orders
    }

    func addPartOrder(_ order: PartOrder) async throws {
        try await client
            .from("part_orders")
            .insert(order)
            .execute()
    }

    func updatePartOrder(_ order: PartOrder) async throws {
        struct PartOrderUpdate: Encodable {
            let status: String
            let estimated_delivery: Date?
            let notes: String
        }
        let payload = PartOrderUpdate(
            status: order.status.rawValue,
            estimated_delivery: order.estimatedDelivery,
            notes: order.notes
        )
        try await client
            .from("part_orders")
            .update(payload)
            .eq("id", value: order.id)
            .execute()
    }

    func deletePartOrder(_ order: PartOrder) async throws {
        try await client
            .from("part_orders")
            .delete()
            .eq("id", value: order.id)
            .execute()
    }

    // MARK: - Work Order Parts
    func fetchWorkOrderParts(workOrderID: UUID) async throws -> [WorkOrderPartUsage] {
        let parts: [WorkOrderPartUsage] = try await client
            .from("work_order_parts")
            .select()
            .eq("work_order_id", value: workOrderID)
            .execute()
            .value
        return parts
    }

    func saveWorkOrderParts(_ parts: [WorkOrderPartUsage], workOrderID: UUID) async throws {
        // 1. Fetch existing parts for this work order to calculate deltas
        let existingParts: [WorkOrderPartUsage]
        do {
            existingParts = try await fetchWorkOrderParts(workOrderID: workOrderID)
        } catch {
            existingParts = []
        }

        // 2. Delete existing parts for this work order, then insert fresh
        try await client
            .from("work_order_parts")
            .delete()
            .eq("work_order_id", value: workOrderID)
            .execute()

        if !parts.isEmpty {
            try await client
                .from("work_order_parts")
                .insert(parts)
                .execute()
        }

        // 3. Process deltas to adjust spare parts stock in the database
        // Create a map of existing parts by sparePartID
        var existingQuantities: [UUID: Int] = [:]
        for ep in existingParts {
            existingQuantities[ep.sparePartID] = (existingQuantities[ep.sparePartID] ?? 0) + ep.quantityUsed
        }

        // Create a map of new parts by sparePartID
        var newQuantities: [UUID: Int] = [:]
        for np in parts {
            newQuantities[np.sparePartID] = (newQuantities[np.sparePartID] ?? 0) + np.quantityUsed
        }

        // Combine all unique keys
        let allPartIDs = Set(existingQuantities.keys).union(newQuantities.keys)

        for partID in allPartIDs {
            let oldQty = existingQuantities[partID] ?? 0
            let newQty = newQuantities[partID] ?? 0
            let delta = newQty - oldQty

            if delta > 0 {
                // Decrement stock by delta
                try await decrementSparePartQuantity(partID: partID, byAmount: delta)
            } else if delta < 0 {
                // Increment stock by abs(delta) (parts returned to inventory)
                try await incrementSparePartQuantity(partID: partID, byAmount: abs(delta))
            }
        }
    }

    // MARK: - Work Order Delete
    func deleteWorkOrder(_ order: WorkOrder) async throws {
        try await client
            .from("work_orders")
            .delete()
            .eq("id", value: order.id)
            .execute()
    }

    // MARK: - Maintenance Schedules (CUD)
    func addMaintenanceSchedule(_ schedule: MaintenanceSchedule) async throws {
        try await client
            .from("maintenance_schedules")
            .insert(schedule)
            .execute()
    }

    func updateMaintenanceSchedule(_ schedule: MaintenanceSchedule) async throws {
        struct ScheduleUpdate: Encodable {
            let service_type: String
            let due_date: Date
            let status: String
        }
        let payload = ScheduleUpdate(
            service_type: schedule.serviceType,
            due_date: schedule.dueDate,
            status: schedule.status.rawValue
        )
        try await client
            .from("maintenance_schedules")
            .update(payload)
            .eq("id", value: schedule.id)
            .execute()
    }

    func deleteMaintenanceSchedule(_ schedule: MaintenanceSchedule) async throws {
        try await client
            .from("maintenance_schedules")
            .delete()
            .eq("id", value: schedule.id)
            .execute()
    }

    // MARK: - Spare Parts Stock Adjustment
    func decrementSparePartQuantity(partID: UUID, byAmount: Int) async throws {
        // Fetch current quantity, then update
        let parts: [SparePart] = try await client
            .from("spare_parts")
            .select()
            .eq("id", value: partID)
            .execute()
            .value
        guard let part = parts.first else { return }
        let newQuantity = max(0, part.quantity - byAmount)
        struct QuantityUpdate: Encodable {
            let quantity: Int
        }
        try await client
            .from("spare_parts")
            .update(QuantityUpdate(quantity: newQuantity))
            .eq("id", value: partID)
            .execute()
    }

    func incrementSparePartQuantity(partID: UUID, byAmount: Int) async throws {
        // Fetch current quantity, then update
        let parts: [SparePart] = try await client
            .from("spare_parts")
            .select()
            .eq("id", value: partID)
            .execute()
            .value
        guard let part = parts.first else { return }
        let newQuantity = part.quantity + byAmount
        struct QuantityUpdate: Encodable {
            let quantity: Int
        }
        try await client
            .from("spare_parts")
            .update(QuantityUpdate(quantity: newQuantity))
            .eq("id", value: partID)
            .execute()
    }

    // MARK: - MFA (Two-Factor Authentication)

    /// Enroll a new TOTP factor. Returns the factor ID, QR code data URI, secret, and OTP URI.
    func enrollMFA(friendlyName: String = "FMS Authenticator") async throws -> (factorID: String, qrCode: String, secret: String, uri: String) {
        let response = try await client.auth.mfa.enroll(
            params: MFAEnrollParams(
                issuer: "FleetOS",
                friendlyName: friendlyName
            )
        )
        return (
            factorID: response.id,
            qrCode: response.totp?.qrCode ?? "",
            secret: response.totp?.secret ?? "",
            uri: response.totp?.uri ?? ""
        )
    }

    /// Create a challenge and verify in one step. Returns the updated session on success.
    func challengeAndVerifyMFA(factorID: String, code: String) async throws {
        try await client.auth.mfa.challengeAndVerify(
            params: MFAChallengeAndVerifyParams(
                factorId: factorID,
                code: code
            )
        )
    }

    /// List all MFA factors for the currently authenticated user.
    /// Returns only verified TOTP factors.
    func listVerifiedMFAFactors() async throws -> [(id: String, friendlyName: String?)] {
        let response = try await client.auth.mfa.listFactors()
        return response.totp
            .filter { $0.status == .verified }
            .map { (id: $0.id, friendlyName: $0.friendlyName) }
    }

    /// List all MFA factors (including unverified) for cleanup during enrollment.
    func listAllMFAFactors() async throws -> [(id: String, status: String, friendlyName: String?)] {
        let response = try await client.auth.mfa.listFactors()
        return response.totp.map { (id: $0.id, status: $0.status.rawValue, friendlyName: $0.friendlyName) }
    }

    /// Remove an enrolled MFA factor.
    func unenrollMFA(factorID: String) async throws {
        try await client.auth.mfa.unenroll(params: MFAUnenrollParams(factorId: factorID))
    }
}

