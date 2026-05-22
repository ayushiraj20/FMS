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
    
    // Work Orders
    func fetchWorkOrders() async throws -> [WorkOrder] {
        let orders: [WorkOrder] = try await client.from("work_orders").select().execute().value
        return orders
    }
    
    func addWorkOrder(_ order: WorkOrder) async throws {

        // Save Work Order
        try await client.from("work_orders").insert(order).execute()

        // Create Bell Notification
        let notification = AppNotification(
            id: UUID(),
            userID: order.assignedMaintenanceID,
            roleTarget: .maintenance,
            title: "New Work Order Assigned",
            message: "\(order.title) has been assigned to you.",
            date: Date(),
            isRead: false,
            category: .info
        )

        // Save Notification in Supabase
        try await addNotification(notification)

        // Show Local iPhone Notification
        NotificationManager.shared.sendLocalNotification(
            title: "New Work Order",
            body: "\(order.title) assigned to you"
        )
    }
    
    // Chat Messages

//    func fetchMessages() async throws -> [ChatMessage] {
//
//        let messages: [ChatMessage] = try await client
//            .from("chat_messages")
//            .select()
//            .order("sent_at", ascending: true)
//            .execute()
//            .value
//
//        return messages
//    }
//
//    func sendMessage(_ message: ChatMessage) async throws {
//
//        try await client
//            .from("chat_messages")
//            .insert(message)
//            .execute()
//    }
    
    
    
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
    
    // Notifications
    func fetchNotifications() async throws -> [AppNotification] {
        let alerts: [AppNotification] = try await client.from("notifications").select().execute().value
        return alerts
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
}
