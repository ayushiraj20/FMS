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
    case cancelled = "Cancelled"
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
    case maintenance = "Maintenance"
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
    var safetyScore: Int? = nil
    var routeDetails: String? = nil
    var notes: String? = nil

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
        case safetyScore = "safety_score"
        case routeDetails = "route_details"
        case notes
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

enum DefectStatus: String, Codable, CaseIterable, Identifiable {
    case pending = "Pending"
    case approved = "Approved"
    case inRepair = "In Repair"
    case completed = "Completed"
    
    var id: String { rawValue }
}

struct DefectReport: Identifiable, Codable, Hashable {
    let id: UUID
    var driverID: UUID
    var vehicleID: UUID
    var severity: WorkOrderPriority
    var description: String
    var reportedDate: Date
    var isResolved: Bool
    var title: String? = nil
    var images: [String]? = nil
    var status: DefectStatus = .pending

    enum CodingKeys: String, CodingKey {
        case id
        case driverID = "driver_id"
        case vehicleID = "vehicle_id"
        case severity
        case description
        case reportedDate = "reported_date"
        case isResolved = "is_resolved"
        case title
        case images
        case status
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
    var overdueAlertFired: Bool = false
    var defectReportID: UUID? = nil
    var images: [String]? = nil

    // MARK: - Computed
    var isOverdue: Bool {
        priority == .critical &&
        status != .completed &&
        scheduledDate < Date.now
    }

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
        case overdueAlertFired = "overdue_alert_fired"
        case defectReportID = "defect_report_id"
        case images
    }
    
    
    var overdueDurationString: String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.day, .hour, .minute]
        formatter.unitsStyle = .full
        formatter.maximumUnitCount = 1
        
        let timeInterval = Date.now.timeIntervalSince(scheduledDate)
        if let durationString = formatter.string(from: timeInterval) {
            return "\(durationString) overdue"
        }
        return "overdue"
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
    var iconName: String = "chart.bar.fill"
    var badgeText: String? = nil
    var badgeColor: BadgeColorType = .none

    enum BadgeColorType: Hashable {
        case none
        case critical
        case action
        case success
    }
}

// MARK: - Driver-Specific Models

enum DutyStatus: String, Codable, CaseIterable {
    case onDuty = "On Duty"
    case offDuty = "Off Duty"
}

struct ShiftInfo: Identifiable, Codable, Hashable {
    let id: UUID
    var driverID: UUID
    var startTime: Date
    var endTime: Date
    var breakTime: Date?
    var date: Date

    enum CodingKeys: String, CodingKey {
        case id
        case driverID = "driver_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case breakTime = "break_time"
        case date
    }

    var totalHours: Double {
        endTime.timeIntervalSince(startTime) / 3600.0
    }

    var elapsedHours: Double {
        let now = Date.now
        guard now > startTime else { return 0 }
        guard now < endTime else { return totalHours }
        return now.timeIntervalSince(startTime) / 3600.0
    }

    var remainingHours: Double {
        max(0, totalHours - elapsedHours)
    }

    var progress: Double {
        guard totalHours > 0 else { return 0 }
        return min(1.0, elapsedHours / totalHours)
    }
}

struct FuelReceipt: Identifiable, Codable, Hashable {
    let id: UUID
    var driverID: UUID
    var vehicleID: UUID
    var date: Date
    var stationName: String
    var litres: Double
    var amount: Double
    var vehiclePlate: String

    enum CodingKeys: String, CodingKey {
        case id
        case driverID = "driver_id"
        case vehicleID = "vehicle_id"
        case date
        case stationName = "station_name"
        case litres
        case amount
        case vehiclePlate = "vehicle_plate"
    }
}

enum SOSStatus: String, Codable {
    case triggered = "Triggered"
    case confirmed = "Confirmed"
    case resolved = "Resolved"
    case cancelled = "Cancelled"
}

struct SOSAlert: Identifiable, Codable, Hashable {
    let id: UUID
    var driverID: UUID
    var vehicleID: UUID
    var latitude: Double
    var longitude: Double
    var timestamp: Date
    var status: SOSStatus

    enum CodingKeys: String, CodingKey {
        case id
        case driverID = "driver_id"
        case vehicleID = "vehicle_id"
        case latitude
        case longitude
        case timestamp
        case status
    }
}

struct ChatMessage: Identifiable, Codable, Hashable {
    let id: UUID
    var senderID: UUID
    var receiverID: UUID?
    var message: String
    var timestamp: Date
    var isRead: Bool
    var workOrderID: UUID? = nil

    enum CodingKeys: String, CodingKey {
        case id
        case senderID = "sender_id"
        case receiverID = "receiver_id"
        case message
        case timestamp
        case isRead = "is_read"
        case workOrderID = "work_order_id"
    }
}

enum CheckpointStatus: String, Codable, CaseIterable {
    case completed = "Completed"
    case inTransit = "In Transit"
    case upcoming = "Upcoming"
}

struct TripCheckpoint: Identifiable, Codable, Hashable {
    let id: UUID
    var tripID: UUID
    var name: String
    var status: CheckpointStatus
    var arrivalTime: Date?
    var departureTime: Date?
    var sortOrder: Int

    enum CodingKeys: String, CodingKey {
        case id
        case tripID = "trip_id"
        case name
        case status
        case arrivalTime = "arrival_time"
        case departureTime = "departure_time"
        case sortOrder = "sort_order"
    }
}

enum VehicleAlertType: String, Codable, CaseIterable {
    case engine = "Engine"
    case fuel = "Fuel"
    case battery = "Battery"
    case tire = "Tire"
    case brake = "Brake"
    case temperature = "Temperature"
}

enum AlertSeverity: String, Codable, CaseIterable {
    case critical = "Critical"
    case warning = "Warning"
    case info = "Info"
}

struct VehicleAlert: Identifiable, Codable, Hashable {
    let id: UUID
    var vehicleID: UUID
    var alertType: VehicleAlertType
    var severity: AlertSeverity
    var alertDescription: String
    var recommendedAction: String
    var isAcknowledged: Bool
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleID = "vehicle_id"
        case alertType = "alert_type"
        case severity
        case alertDescription = "description"
        case recommendedAction = "recommended_action"
        case isAcknowledged = "is_acknowledged"
        case createdAt = "created_at"
    }
}

enum DefectIssueType: String, Codable, CaseIterable, Identifiable {
    case engine = "Engine"
    case brakes = "Brakes"
    case tyres = "Tyres"
    case lights = "Lights"
    case body = "Body"
    case fuelSystem = "Fuel System"
    case electrical = "Electrical"
    case other = "Other"

    var id: String { rawValue }
}

enum InspectionItemStatus: String, Codable {
    case unchecked = "Unchecked"
    case passed = "Passed"
    case failed = "Failed"
}

struct DriverInspectionItem: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var iconName: String
    var status: InspectionItemStatus
    var failureDescription: String
    var isCritical: Bool

    init(id: UUID = UUID(), title: String, iconName: String, status: InspectionItemStatus = .unchecked, failureDescription: String = "", isCritical: Bool = false) {
        self.id = id
        self.title = title
        self.iconName = iconName
        self.status = status
        self.failureDescription = failureDescription
        self.isCritical = isCritical
    }
}

struct BreakLogEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var driverID: UUID
    var startTime: Date
    var endTime: Date?
    var breakType: String

    enum CodingKeys: String, CodingKey {
        case id
        case driverID = "driver_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case breakType = "break_type"
    }
}

