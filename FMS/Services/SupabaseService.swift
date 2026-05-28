import Foundation
import Supabase

@MainActor
final class SupabaseService {
    static let shared = SupabaseService()
    
    let client: SupabaseClient
    
    private init() {
        self.client = SupabaseClient(supabaseURL: SupabaseConfig.url, supabaseKey: SupabaseConfig.key)
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
            .update(order)
            .eq("id", value: order.id)
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
}

