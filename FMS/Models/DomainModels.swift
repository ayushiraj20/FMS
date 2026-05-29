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
    var isPasswordResetRequired: Bool = false

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case name
        case role
        case email
        case phone
        case title
        case assignedVehicleID = "assigned_vehicle_id"
        case isPasswordResetRequired = "is_password_reset_required"
    }

    init(id: UUID, organizationID: UUID, name: String, role: UserRole, email: String, password: String = "demo123", phone: String, title: String, assignedVehicleID: UUID? = nil, isPasswordResetRequired: Bool = false) {
        self.id = id
        self.organizationID = organizationID
        self.name = name
        self.role = role
        self.email = email
        self.password = password
        self.phone = phone
        self.title = title
        self.assignedVehicleID = assignedVehicleID
        self.isPasswordResetRequired = isPasswordResetRequired
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
        isPasswordResetRequired = try container.decodeIfPresent(Bool.self, forKey: .isPasswordResetRequired) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(organizationID, forKey: .organizationID)
        try container.encode(name, forKey: .name)
        try container.encode(role, forKey: .role)
        try container.encode(email, forKey: .email)
        try container.encode(phone, forKey: .phone)
        try container.encode(title, forKey: .title)
        if let assignedVehicleID = assignedVehicleID {
            try container.encode(assignedVehicleID, forKey: .assignedVehicleID)
        } else {
            try container.encodeNil(forKey: .assignedVehicleID)
        }
        try container.encode(isPasswordResetRequired, forKey: .isPasswordResetRequired)
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
    var fuelConsumption: Double
    var vehicleType: String
    var fuelType: String
    var manufacturer: String
    var vehicleYear: String
    var vinNumber: String

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
        case fuelConsumption = "fuel_consumption"
        case vehicleType = "vehicle_type"
        case fuelType = "fuel_type"
        case manufacturer
        case vehicleYear = "vehicle_year"
        case vinNumber = "vin_number"
    }

    init(id: UUID, organizationID: UUID, displayName: String, plateNumber: String, model: String, status: VehicleStatus, fuelLevel: Int, odometer: Int, assignedDriverID: UUID?, nextServiceDate: Date, utilization: Int, fuelConsumption: Double = 0.0, vehicleType: String = "Truck", fuelType: String = "Diesel", manufacturer: String = "", vehicleYear: String = "", vinNumber: String = "") {
        self.id = id
        self.organizationID = organizationID
        self.displayName = displayName
        self.plateNumber = plateNumber
        self.model = model
        self.status = status
        self.fuelLevel = fuelLevel
        self.odometer = odometer
        self.assignedDriverID = assignedDriverID
        self.nextServiceDate = nextServiceDate
        self.utilization = utilization
        self.fuelConsumption = fuelConsumption
        self.vehicleType = vehicleType
        self.fuelType = fuelType
        self.manufacturer = manufacturer
        self.vehicleYear = vehicleYear
        self.vinNumber = vinNumber
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        organizationID = try container.decode(UUID.self, forKey: .organizationID)
        displayName = try container.decode(String.self, forKey: .displayName)
        plateNumber = try container.decode(String.self, forKey: .plateNumber)
        model = try container.decode(String.self, forKey: .model)
        status = try container.decode(VehicleStatus.self, forKey: .status)
        fuelLevel = try container.decode(Int.self, forKey: .fuelLevel)
        odometer = try container.decode(Int.self, forKey: .odometer)
        assignedDriverID = try container.decodeIfPresent(UUID.self, forKey: .assignedDriverID)
        nextServiceDate = (try? container.decode(Date.self, forKey: .nextServiceDate)) ?? Date()
        utilization = try container.decode(Int.self, forKey: .utilization)
        fuelConsumption = (try? container.decode(Double.self, forKey: .fuelConsumption)) ?? 0.0
        vehicleType = (try? container.decode(String.self, forKey: .vehicleType)) ?? "Truck"
        fuelType = (try? container.decode(String.self, forKey: .fuelType)) ?? "Diesel"
        manufacturer = (try? container.decode(String.self, forKey: .manufacturer)) ?? ""
        vehicleYear = (try? container.decode(String.self, forKey: .vehicleYear)) ?? ""
        vinNumber = (try? container.decode(String.self, forKey: .vinNumber)) ?? ""
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(organizationID, forKey: .organizationID)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(plateNumber, forKey: .plateNumber)
        try container.encode(model, forKey: .model)
        try container.encode(status, forKey: .status)
        try container.encode(fuelLevel, forKey: .fuelLevel)
        try container.encode(odometer, forKey: .odometer)
        if let assignedDriverID = assignedDriverID {
            try container.encode(assignedDriverID, forKey: .assignedDriverID)
        } else {
            try container.encodeNil(forKey: .assignedDriverID)
        }
        try container.encode(nextServiceDate, forKey: .nextServiceDate)
        try container.encode(utilization, forKey: .utilization)
        try container.encode(fuelConsumption, forKey: .fuelConsumption)
        try container.encode(vehicleType, forKey: .vehicleType)
        try container.encode(fuelType, forKey: .fuelType)
        try container.encode(manufacturer, forKey: .manufacturer)
        try container.encode(vehicleYear, forKey: .vehicleYear)
        try container.encode(vinNumber, forKey: .vinNumber)
    }
}

struct VehicleDocument: Identifiable, Codable, Hashable {
    let id: UUID
    var vehicleID: UUID
    var type: DocumentType
    var documentNumber: String
    var expiryDate: Date
    var isVerified: Bool
    var imageUrl: String?

    enum CodingKeys: String, CodingKey {
        case id
        case vehicleID = "vehicle_id"
        case type
        case documentNumber = "document_number"
        case expiryDate = "expiry_date"
        case isVerified = "is_verified"
        case imageUrl = "image_url"
    }

    init(id: UUID, vehicleID: UUID, type: DocumentType, documentNumber: String, expiryDate: Date, isVerified: Bool, imageUrl: String? = nil) {
        self.id = id
        self.vehicleID = vehicleID
        self.type = type
        self.documentNumber = documentNumber
        self.expiryDate = expiryDate
        self.isVerified = isVerified
        self.imageUrl = imageUrl
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        vehicleID = try container.decode(UUID.self, forKey: .vehicleID)
        type = try container.decode(DocumentType.self, forKey: .type)
        documentNumber = try container.decode(String.self, forKey: .documentNumber)
        expiryDate = try container.decode(Date.self, forKey: .expiryDate)
        isVerified = try container.decode(Bool.self, forKey: .isVerified)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
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
    var originLat: Double? = nil
    var originLng: Double? = nil
    var destinationLat: Double? = nil
    var destinationLng: Double? = nil

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
        case originLat = "origin_lat"
        case originLng = "origin_lng"
        case destinationLat = "destination_lat"
        case destinationLng = "destination_lng"
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(driverID, forKey: .driverID)
        try container.encode(vehicleID, forKey: .vehicleID)
        try container.encode(type, forKey: .type)
        try container.encode(date, forKey: .date)
        try container.encode(notes, forKey: .notes)
        try container.encode(passed, forKey: .passed)
        // Note: Do not encode 'items' since it belongs to a separate table (inspection_items)
        // and does not exist in the inspection_records table.
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

struct SOSAlert: Identifiable, Codable, Hashable {
    let id: UUID
    var driverID: UUID
    var driverName: String
    var vehicleID: UUID
    var vehicleNumber: String
    var emergencyType: String
    var latitude: Double
    var longitude: Double
    var description: String?
    var status: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case driverID = "driver_id"
        case driverName = "driver_name"
        case vehicleID = "vehicle_id"
        case vehicleNumber = "vehicle_number"
        case emergencyType = "emergency_type"
        case latitude
        case longitude
        case description
        case status
        case createdAt = "created_at"
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
        case timestamp = "sent_at"
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

// MARK: - Trip Start Inspection Models

enum ItemStatus: String, Codable, Hashable {
    case unchecked = "Unchecked"
    case passed = "Passed"
    case failed = "Failed"
}

struct InspectionItem2: Identifiable, Hashable {
    let id: UUID
    var title: String
    var icon: String
    var hint: String
    var status: ItemStatus
    var failureNote: String

    init(id: UUID = UUID(), title: String, icon: String, hint: String, status: ItemStatus = .unchecked, failureNote: String = "") {
        self.id = id
        self.title = title
        self.icon = icon
        self.hint = hint
        self.status = status
        self.failureNote = failureNote
    }

    static func defaultList() -> [InspectionItem2] {
        [
            InspectionItem2(title: "Brakes", icon: "exclamationmark.circle.fill", hint: "Check brake pads, fluid level, and responsiveness"),
            InspectionItem2(title: "Tyres / Wheels", icon: "circle.circle", hint: "Inspect tread depth, pressure, and wheel nuts"),
            InspectionItem2(title: "Steering", icon: "steeringwheel", hint: "Check for play, leaks, and smooth operation"),
            InspectionItem2(title: "Lights & Signals", icon: "lightbulb.fill", hint: "Test headlights, indicators, and brake lights"),
            InspectionItem2(title: "Mirrors", icon: "rectangle.on.rectangle.angled", hint: "Ensure all mirrors are clean and properly adjusted"),
            InspectionItem2(title: "Horn", icon: "speaker.wave.3.fill", hint: "Test horn functionality"),
            InspectionItem2(title: "Windshield & Wipers", icon: "drop.fill", hint: "Check for cracks, wiper blades, and washer fluid"),
            InspectionItem2(title: "Engine / Fluids", icon: "engine.combustion.fill", hint: "Check oil, coolant, and listen for unusual sounds"),
            InspectionItem2(title: "Seatbelt", icon: "seatbelt.fill", hint: "Verify seatbelt locks and retracts properly"),
            InspectionItem2(title: "Emergency Kit", icon: "cross.case.fill", hint: "First aid kit, fire extinguisher, and warning triangle"),
        ]
    }
}

// MARK: - Spare Parts Inventory

struct SparePart: Identifiable, Codable, Hashable {
    let id: UUID
    var organizationID: UUID
    var name: String
    var partNumber: String
    var category: String
    var quantity: Int
    var minimumRequired: Int
    var icon: String

    var isOutOfStock: Bool { quantity == 0 }
    var isLowStock: Bool { quantity > 0 && quantity <= minimumRequired }
    var isCriticallyLow: Bool { quantity < 2 }

    enum CodingKeys: String, CodingKey {
        case id
        case organizationID = "organization_id"
        case name
        case partNumber = "part_number"
        case category
        case quantity
        case minimumRequired = "minimum_required"
        case icon
    }
}
