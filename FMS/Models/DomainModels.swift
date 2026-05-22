import Foundation

enum UserRole: String, Codable, CaseIterable, Identifiable {
    case fleetManager = "Fleet Manager"
    case driver = "Driver"
    case maintenance = "Maintenance Personnel"

    var id: String { rawValue }
    var iconName: String {
        switch self {
        case .fleetManager: "chart.line.uptrend.xyaxis"
        case .driver: "steeringwheel"
        case .maintenance: "wrench.and.screwdriver"
        }
    }
}

enum VehicleStatus: String, Codable, CaseIterable {
    case active = "Active"
    case inService = "In Service"
    case idle = "Idle"
    case outOfService = "Out of Service"
}

enum DocumentType: String, Codable, CaseIterable, Identifiable {
    case rc = "RC"
    case insurance = "Insurance"
    case puc = "PUC"
    case permit = "Permit"

    var id: String { rawValue }
}

enum TripStatus: String, Codable, CaseIterable {
    case scheduled = "Scheduled"
    case inProgress = "In Progress"
    case completed = "Completed"
}

enum WorkOrderStatus: String, Codable, CaseIterable, Identifiable {
    case open = "Open"
    case inProgress = "In Progress"
    case waitingParts = "Waiting Parts"
    case completed = "Completed"

    var id: String { rawValue }
}

enum WorkOrderPriority: String, Codable, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"

    var id: String { rawValue }
}

enum InspectionType: String, Codable, CaseIterable, Identifiable {
    case preTrip = "Pre-Trip"
    case postTrip = "Post-Trip"

    var id: String { rawValue }
}

enum MaintenanceScheduleStatus: String, Codable, CaseIterable {
    case upcoming = "Upcoming"
    case overdue = "Overdue"
    case completed = "Completed"
}

enum NotificationCategory: String, Codable {
    case info = "Info"
    case warning = "Warning"
    case critical = "Critical"
    case success = "Success"
}

struct Organization: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var industry: String
    var fleetSize: Int
    var complianceScore: Int

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case industry
        case fleetSize = "fleet_size"
        case complianceScore = "compliance_score"
    }
}

struct User: Identifiable, Codable, Hashable {
    let id: UUID
    var organizationID: UUID
    var name: String
    var role: UserRole
    var email: String
    var password: String = "demo123"
    var phone: String
    var title: String
    var assignedVehicleID: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case name
        case role
        case email
        case phone
        case title
        case assignedVehicleID = "assigned_vehicle_id"
    }

    init(id: UUID, organizationID: UUID, name: String, role: UserRole, email: String, password: String = "demo123", phone: String, title: String, assignedVehicleID: UUID? = nil) {
        self.id = id
        self.organizationID = organizationID
        self.name = name
        self.role = role
        self.email = email
        self.password = password
        self.phone = phone
        self.title = title
        self.assignedVehicleID = assignedVehicleID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        organizationID = try container.decode(UUID.self, forKey: .organizationID)
        name = try container.decode(String.self, forKey: .name)
        role = try container.decode(UserRole.self, forKey: .role)
        email = try container.decode(String.self, forKey: .email)
        password = "demo123"
        phone = try container.decode(String.self, forKey: .phone)
        title = try container.decode(String.self, forKey: .title)
        assignedVehicleID = try container.decodeIfPresent(UUID.self, forKey: .assignedVehicleID)
    }
}

struct Vehicle: Identifiable, Codable, Hashable {
    let id: UUID
    var organizationID: UUID
    var displayName: String
    var plateNumber: String
    var model: String
    var status: VehicleStatus
    var fuelLevel: Int
    var odometer: Int
    var assignedDriverID: UUID?
    var nextServiceDate: Date
    var utilization: Int

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case displayName = "display_name"
        case plateNumber = "plate_number"
        case model
        case status
        case fuelLevel = "fuel_level"
        case odometer
        case assignedDriverID = "assigned_driver_id"
        case nextServiceDate = "next_service_date"
        case utilization
    }
}

struct VehicleDocument: Identifiable, Codable, Hashable {
    let id: UUID
    var vehicleID: UUID
    var type: DocumentType
    var documentNumber: String
    var expiryDate: Date
    var isVerified: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleID = "vehicle_id"
        case type
        case documentNumber = "document_number"
        case expiryDate = "expiry_date"
        case isVerified = "is_verified"
    }
}

struct Trip: Identifiable, Codable, Hashable {
    let id: UUID
    var driverID: UUID
    var vehicleID: UUID
    var origin: String
    var destination: String
    var startDate: Date
    var endDate: Date?
    var distanceKM: Double
    var status: TripStatus

    enum CodingKeys: String, CodingKey {
        case id
        case driverID = "driver_id"
        case vehicleID = "vehicle_id"
        case origin
        case destination
        case startDate = "start_date"
        case endDate = "end_date"
        case distanceKM = "distance_km"
        case status
    }
}

struct InspectionItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var isChecked: Bool
    var inspectionRecordID: UUID?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case isChecked = "is_checked"
        case inspectionRecordID = "inspection_record_id"
    }
}

struct InspectionRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var driverID: UUID
    var vehicleID: UUID
    var type: InspectionType
    var date: Date
    var notes: String
    var passed: Bool
    var items: [InspectionItem]

    enum CodingKeys: String, CodingKey {
        case id
        case driverID = "driver_id"
        case vehicleID = "vehicle_id"
        case type
        case date
        case notes
        case passed
        case items
    }

    init(id: UUID, driverID: UUID, vehicleID: UUID, type: InspectionType, date: Date, notes: String, passed: Bool, items: [InspectionItem]) {
        self.id = id
        self.driverID = driverID
        self.vehicleID = vehicleID
        self.type = type
        self.date = date
        self.notes = notes
        self.passed = passed
        self.items = items
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        driverID = try container.decode(UUID.self, forKey: .driverID)
        vehicleID = try container.decode(UUID.self, forKey: .vehicleID)
        type = try container.decode(InspectionType.self, forKey: .type)
        date = try container.decode(Date.self, forKey: .date)
        notes = try container.decode(String.self, forKey: .notes)
        passed = try container.decode(Bool.self, forKey: .passed)
        items = try container.decodeIfPresent([InspectionItem].self, forKey: .items) ?? []
    }
}

struct DefectReport: Identifiable, Codable, Hashable {
    let id: UUID
    var driverID: UUID
    var vehicleID: UUID
    var severity: WorkOrderPriority
    var description: String
    var reportedDate: Date
    var isResolved: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case driverID = "driver_id"
        case vehicleID = "vehicle_id"
        case severity
        case description
        case reportedDate = "reported_date"
        case isResolved = "is_resolved"
    }
}

struct WorkOrder: Identifiable, Codable, Hashable {
    let id: UUID
    var vehicleID: UUID
    var assignedMaintenanceID: UUID?
    var title: String
    var details: String
    var priority: WorkOrderPriority
    var status: WorkOrderStatus
    var scheduledDate: Date
    var completedDate: Date?
    var estimatedCost: Double
    var repairSummary: String

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleID = "vehicle_id"
        case assignedMaintenanceID = "assigned_maintenance_id"
        case title
        case details
        case priority
        case status
        case scheduledDate = "scheduled_date"
        case completedDate = "completed_date"
        case estimatedCost = "estimated_cost"
        case repairSummary = "repair_summary"
    }
}

struct MaintenanceSchedule: Identifiable, Codable, Hashable {
    let id: UUID
    var vehicleID: UUID
    var serviceType: String
    var dueDate: Date
    var status: MaintenanceScheduleStatus

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleID = "vehicle_id"
        case serviceType = "service_type"
        case dueDate = "due_date"
        case status
    }
}

struct AppNotification: Identifiable, Codable, Hashable {
    let id: UUID
    var userID: UUID?
    var roleTarget: UserRole?
    var title: String
    var message: String
    var date: Date
    var isRead: Bool
    var category: NotificationCategory

    enum CodingKeys: String, CodingKey {
        case id
        case userID = "user_id"
        case roleTarget = "role_target"
        case title
        case message
        case date
        case isRead = "is_read"
        case category
    }
}

struct KPIStat: Identifiable, Hashable {
    let id = UUID()
    var title: String
    var value: String
    var detail: String
    var trend: String
}


//struct ChatMessage: Identifiable, Codable, Hashable {
//
//    let id: UUID
//
//    var senderID: UUID
//    var receiverID: UUID
//
//    var vehicleID: UUID?
//    var workOrderID: UUID?
//
//    var message: String
//
//    var sentAt: Date
//
//    var isRead: Bool
//
//    enum CodingKeys: String, CodingKey {
//        case id
//        case senderID = "sender_id"
//        case receiverID = "receiver_id"
//        case vehicleID = "vehicle_id"
//        case workOrderID = "work_order_id"
//        case message
//        case sentAt = "sent_at"
//        case isRead = "is_read"
//    }
//}
