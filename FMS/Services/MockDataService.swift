import Foundation
import Combine
import Observation

@Observable
@MainActor
final class MockDataService {
    var organizations: [Organization]
    var users: [User]
    var vehicles: [Vehicle]
    var documents: [VehicleDocument]
    var trips: [Trip]
    var inspections: [InspectionRecord]
    var defects: [DefectReport]
    var workOrders: [WorkOrder]
    var maintenanceSchedules: [MaintenanceSchedule]
    var notifications: [AppNotification]

    // Driver-specific data
    var shifts: [ShiftInfo]
    var fuelReceipts: [FuelReceipt]
    var sosAlerts: [SOSAlert]
    var chatMessages: [ChatMessage]
    var tripCheckpoints: [TripCheckpoint]
    var vehicleAlerts: [VehicleAlert]
    var breakLogs: [BreakLogEntry]
    var driverDutyStatus: [UUID: DutyStatus]

    init() {
        let seed = DemoSeed.make()
        organizations = seed.organizations
        users = seed.users
        vehicles = seed.vehicles
        documents = seed.documents
        trips = seed.trips
        inspections = seed.inspections
        defects = seed.defects
        workOrders = seed.workOrders
        maintenanceSchedules = seed.maintenanceSchedules
        notifications = seed.notifications
        shifts = seed.shifts
        fuelReceipts = seed.fuelReceipts
        sosAlerts = []
        chatMessages = seed.chatMessages
        tripCheckpoints = seed.tripCheckpoints
        vehicleAlerts = seed.vehicleAlerts
        breakLogs = seed.breakLogs
        driverDutyStatus = seed.dutyStatuses
        
        // Asynchronously sync database if credentials are present
        if SupabaseConfig.isConfigured {
            Task {
                await syncWithDatabase()
            }
        }
    }

    /// Asynchronously fetches all remote data from Supabase and updates main queues.
    func syncWithDatabase() async {
        guard SupabaseConfig.isConfigured else { return }
        do {
            let orgs = try await SupabaseService.shared.fetchOrganizations()
            let usersList = try await SupabaseService.shared.fetchProfiles()
            let vehiclesList = try await SupabaseService.shared.fetchVehicles()
            let docs = try await SupabaseService.shared.fetchDocuments()
            let tripsList = try await SupabaseService.shared.fetchTrips()
            let inspectionsList = try await SupabaseService.shared.fetchInspections()
            let defectsList = try await SupabaseService.shared.fetchDefects()
            let orders = try await SupabaseService.shared.fetchWorkOrders()
            let schedulesList = try await SupabaseService.shared.fetchSchedules()
            let notificationsList = try await SupabaseService.shared.fetchNotifications()
            
            self.organizations = orgs
            self.users = usersList
            self.vehicles = vehiclesList
            self.documents = docs
            self.trips = tripsList
            self.inspections = inspectionsList
            self.defects = defectsList
            self.workOrders = orders
            self.maintenanceSchedules = schedulesList
            self.notifications = notificationsList
        } catch {
            print("Supabase live sync warning: \(error.localizedDescription)")
        }
    }

    func authenticate(email: String, password: String) -> User? {
        users.first { $0.email.lowercased() == email.lowercased() && $0.password == password }
    }

    func users(for role: UserRole? = nil) -> [User] {
        guard let role else { return users }
        return users.filter { $0.role == role }
    }

    func vehicles(for driverID: UUID? = nil) -> [Vehicle] {
        guard let driverID else { return vehicles }
        return vehicles.filter { $0.assignedDriverID == driverID }
    }

    func documents(for vehicleID: UUID) -> [VehicleDocument] {
        documents.filter { $0.vehicleID == vehicleID }
            .sorted { $0.expiryDate < $1.expiryDate }
    }

    func trips(for driverID: UUID) -> [Trip] {
        trips.filter { $0.driverID == driverID }
            .sorted { $0.startDate > $1.startDate }
    }

    func workOrders(for maintenanceID: UUID? = nil) -> [WorkOrder] {
        guard let maintenanceID else {
            return workOrders.sorted { $0.scheduledDate > $1.scheduledDate }
        }
        return workOrders.filter { $0.assignedMaintenanceID == maintenanceID }
            .sorted { $0.scheduledDate > $1.scheduledDate }
    }

    func schedules(for vehicleIDs: Set<UUID>? = nil) -> [MaintenanceSchedule] {
        guard let vehicleIDs else { return maintenanceSchedules.sorted { $0.dueDate < $1.dueDate } }
        return maintenanceSchedules.filter { vehicleIDs.contains($0.vehicleID) }
            .sorted { $0.dueDate < $1.dueDate }
    }

    func notifications(for user: User?) -> [AppNotification] {
        guard let user else {
            return notifications.sorted { $0.date > $1.date }
        }

        return notifications.filter {
            $0.userID == user.id || $0.roleTarget == user.role || ($0.userID == nil && $0.roleTarget == nil)
        }
        .sorted { $0.date > $1.date }
    }

    func vehicle(for id: UUID?) -> Vehicle? {
        guard let id else { return nil }
        return vehicles.first { $0.id == id }
    }

    func user(for id: UUID?) -> User? {
        guard let id else { return nil }
        return users.first { $0.id == id }
    }

    // MARK: - Driver-Specific Queries

    func currentShift(for driverID: UUID) -> ShiftInfo? {
        let today = Calendar.current.startOfDay(for: .now)
        return shifts.first { $0.driverID == driverID && Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    func activeTrip(for driverID: UUID) -> Trip? {
        trips.first { $0.driverID == driverID && $0.status == .inProgress }
    }

    func upcomingTrips(for driverID: UUID) -> [Trip] {
        trips.filter { $0.driverID == driverID && $0.status == .scheduled }
            .sorted { $0.startDate < $1.startDate }
    }

    func fuelReceipts(for driverID: UUID) -> [FuelReceipt] {
        fuelReceipts.filter { $0.driverID == driverID }
            .sorted { $0.date > $1.date }
    }

    func checkpoints(for tripID: UUID) -> [TripCheckpoint] {
        tripCheckpoints.filter { $0.tripID == tripID }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    func alerts(for vehicleID: UUID) -> [VehicleAlert] {
        vehicleAlerts.filter { $0.vehicleID == vehicleID && !$0.isAcknowledged }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func criticalAlerts(for vehicleID: UUID) -> [VehicleAlert] {
        alerts(for: vehicleID).filter { $0.severity == .critical }
    }

    func chatMessages(for driverID: UUID) -> [ChatMessage] {
        chatMessages.filter { $0.senderID == driverID || $0.receiverID == driverID }
            .sorted { $0.timestamp < $1.timestamp }
    }

    func todayInspection(for driverID: UUID) -> InspectionRecord? {
        let today = Calendar.current.startOfDay(for: .now)
        return inspections.first {
            $0.driverID == driverID && Calendar.current.isDate($0.date, inSameDayAs: today)
        }
    }

    func dutyStatus(for driverID: UUID) -> DutyStatus {
        driverDutyStatus[driverID] ?? .offDuty
    }

    // MARK: - Driver-Specific Mutations

    func toggleDutyStatus(for driverID: UUID) {
        let current = driverDutyStatus[driverID] ?? .offDuty
        driverDutyStatus[driverID] = (current == .onDuty) ? .offDuty : .onDuty
    }

    func addFuelReceipt(driverID: UUID, vehicleID: UUID, stationName: String, litres: Double, amount: Double, vehiclePlate: String) {
        let receipt = FuelReceipt(
            id: UUID(),
            driverID: driverID,
            vehicleID: vehicleID,
            date: .now,
            stationName: stationName,
            litres: litres,
            amount: amount,
            vehiclePlate: vehiclePlate
        )
        fuelReceipts.insert(receipt, at: 0)
    }

    func triggerSOS(driverID: UUID, vehicleID: UUID, latitude: Double, longitude: Double) {
        let alert = SOSAlert(
            id: UUID(),
            driverID: driverID,
            vehicleID: vehicleID,
            latitude: latitude,
            longitude: longitude,
            timestamp: .now,
            status: .triggered
        )
        sosAlerts.insert(alert, at: 0)
    }

    func sendChatMessage(senderID: UUID, receiverID: UUID, message: String) {
        let msg = ChatMessage(
            id: UUID(),
            senderID: senderID,
            receiverID: receiverID,
            message: message,
            timestamp: .now,
            isRead: false
        )
        chatMessages.append(msg)
    }

    func acknowledgeAlert(_ alert: VehicleAlert) {
        guard let index = vehicleAlerts.firstIndex(where: { $0.id == alert.id }) else { return }
        vehicleAlerts[index].isAcknowledged = true
    }

    func addBreakLog(driverID: UUID, breakType: String) {
        let entry = BreakLogEntry(
            id: UUID(),
            driverID: driverID,
            startTime: .now,
            endTime: nil,
            breakType: breakType
        )
        breakLogs.insert(entry, at: 0)
    }

    func endBreakLog(id: UUID) {
        guard let index = breakLogs.firstIndex(where: { $0.id == id }) else { return }
        breakLogs[index].endTime = .now
    }

    // MARK: - Existing Mutations

    func addUser(name: String, role: UserRole, email: String, phone: String, title: String, organizationID: UUID) async throws {
        var user = User(
            id: UUID(),
            organizationID: organizationID,
            name: name,
            role: role,
            email: email,
            password: "demo123",
            phone: phone,
            title: title,
            assignedVehicleID: nil
        )
        
        if SupabaseConfig.isConfigured {
            try await SupabaseService.shared.createUserAdmin(
                email: email,
                name: name,
                role: role,
                phone: phone,
                title: title,
                organizationID: organizationID
            )
            await syncWithDatabase()
        } else {
            if role == .driver {
                let assignedVehicleID: UUID
                let vehiclePlate: String
                
                if let availableVehicle = vehicles.first(where: { $0.assignedDriverID == nil }) {
                    assignedVehicleID = availableVehicle.id
                    vehiclePlate = availableVehicle.plateNumber
                    
                    // Update vehicle driver assignment
                    if let idx = vehicles.firstIndex(where: { $0.id == availableVehicle.id }) {
                        vehicles[idx].assignedDriverID = user.id
                        vehicles[idx].status = .active
                    }
                } else {
                    let newVehicleID = UUID()
                    let plate = "TRK-\(Int.random(in: 1000...9999))"
                    let newVehicle = Vehicle(
                        id: newVehicleID,
                        organizationID: organizationID,
                        displayName: "Tata Prima 5530",
                        plateNumber: plate,
                        model: "2024 Heavy Duty",
                        status: .active,
                        fuelLevel: 80,
                        odometer: 105_000,
                        assignedDriverID: user.id,
                        nextServiceDate: .now.addingTimeInterval(86400 * 30),
                        utilization: 75
                    )
                    vehicles.insert(newVehicle, at: 0)
                    assignedVehicleID = newVehicleID
                    vehiclePlate = plate
                }
                
                user.assignedVehicleID = assignedVehicleID
                
                // Seed Shift
                let todayStart = Calendar.current.startOfDay(for: .now)
                let shiftStart = todayStart.addingTimeInterval(6 * 3600) // 6:00 AM
                let shiftEnd = todayStart.addingTimeInterval(18 * 3600)  // 6:00 PM
                let breakAt = todayStart.addingTimeInterval(12 * 3600)   // 12:00 PM
                let newShift = ShiftInfo(
                    id: UUID(),
                    driverID: user.id,
                    startTime: shiftStart,
                    endTime: shiftEnd,
                    breakTime: breakAt,
                    date: todayStart
                )
                shifts.append(newShift)
                
                // Seed scheduled trip
                let scheduledTripID = UUID()
                let scheduledTrip = Trip(
                    id: scheduledTripID,
                    driverID: user.id,
                    vehicleID: assignedVehicleID,
                    origin: "Mumbai",
                    destination: "Pune Warehouse",
                    startDate: .now.addingTimeInterval(3600),
                    endDate: nil,
                    distanceKM: 148.0,
                    status: .scheduled
                )
                trips.append(scheduledTrip)
                
                // Seed checkpoints for scheduled trip
                let checkpoints = [
                    TripCheckpoint(id: UUID(), tripID: scheduledTripID, name: "Departed", status: .upcoming, arrivalTime: nil, departureTime: nil, sortOrder: 0),
                    TripCheckpoint(id: UUID(), tripID: scheduledTripID, name: "Checkpoint 1 - Panvel", status: .upcoming, arrivalTime: nil, departureTime: nil, sortOrder: 1),
                    TripCheckpoint(id: UUID(), tripID: scheduledTripID, name: "Checkpoint 2 - Lonavala", status: .upcoming, arrivalTime: nil, departureTime: nil, sortOrder: 2),
                    TripCheckpoint(id: UUID(), tripID: scheduledTripID, name: "Pune Warehouse", status: .upcoming, arrivalTime: nil, departureTime: nil, sortOrder: 3)
                ]
                tripCheckpoints.append(contentsOf: checkpoints)
                
                // Seed Fuel Receipt
                let receipt = FuelReceipt(
                    id: UUID(),
                    driverID: user.id,
                    vehicleID: assignedVehicleID,
                    date: .now.addingTimeInterval(-86400),
                    stationName: "HP Petroleum, Panvel",
                    litres: 45.0,
                    amount: 4725.0,
                    vehiclePlate: vehiclePlate
                )
                fuelReceipts.append(receipt)
                
                // Seed Vehicle Alert
                let alert = VehicleAlert(
                    id: UUID(),
                    vehicleID: assignedVehicleID,
                    alertType: .fuel,
                    severity: .warning,
                    alertDescription: "Fuel level dropping faster than expected",
                    recommendedAction: "Check for fuel leaks and refuel at the next station",
                    isAcknowledged: false,
                    createdAt: .now.addingTimeInterval(-1200)
                )
                vehicleAlerts.append(alert)
                
                // Duty Status
                driverDutyStatus[user.id] = .onDuty
            }
            users.insert(user, at: 0)
        }
    }

    func addVehicle(_ vehicle: Vehicle) {
        vehicles.insert(vehicle, at: 0)
        
        if SupabaseConfig.isConfigured {
            Task {
                try? await SupabaseService.shared.addVehicle(vehicle)
            }
        }
    }

    func updateVehicle(_ vehicle: Vehicle) {
        guard let index = vehicles.firstIndex(where: { $0.id == vehicle.id }) else { return }
        vehicles[index] = vehicle
        syncDriverAssignments(using: vehicle)
        
        if SupabaseConfig.isConfigured {
            Task {
                try? await SupabaseService.shared.updateVehicle(vehicle)
            }
        }
    }

    func deleteVehicle(_ vehicle: Vehicle) {
        vehicles.removeAll { $0.id == vehicle.id }
        documents.removeAll { $0.vehicleID == vehicle.id }
        for index in users.indices where users[index].assignedVehicleID == vehicle.id {
            users[index].assignedVehicleID = nil
        }
        
        if SupabaseConfig.isConfigured {
            Task {
                try? await SupabaseService.shared.deleteVehicle(vehicle)
            }
        }
    }

    func addDocument(vehicleID: UUID, type: DocumentType, number: String, expiryDate: Date) {
        let document = VehicleDocument(
            id: UUID(),
            vehicleID: vehicleID,
            type: type,
            documentNumber: number,
            expiryDate: expiryDate,
            isVerified: true
        )
        documents.insert(document, at: 0)
        
        if SupabaseConfig.isConfigured {
            Task {
                try? await SupabaseService.shared.addDocument(document)
            }
        }
    }

    func addWorkOrder(vehicleID: UUID, assignedMaintenanceID: UUID?, title: String, details: String, priority: WorkOrderPriority, scheduledDate: Date) {
        let order = WorkOrder(
            id: UUID(),
            vehicleID: vehicleID,
            assignedMaintenanceID: assignedMaintenanceID,
            title: title,
            details: details,
            priority: priority,
            status: .open,
            scheduledDate: scheduledDate,
            completedDate: nil,
            estimatedCost: Double.random(in: 250...2500),
            repairSummary: ""
        )
        workOrders.insert(order, at: 0)
        
        if SupabaseConfig.isConfigured {
            Task {
                try? await SupabaseService.shared.addWorkOrder(order)
            }
        }
    }

    func updateWorkOrder(_ workOrder: WorkOrder) {
        guard let index = workOrders.firstIndex(where: { $0.id == workOrder.id }) else { return }
        workOrders[index] = workOrder
        
        if SupabaseConfig.isConfigured {
            Task {
                try? await SupabaseService.shared.updateWorkOrder(workOrder)
            }
        }
    }

    func addInspection(driverID: UUID, vehicleID: UUID, type: InspectionType, notes: String, items: [InspectionItem]) {
        let record = InspectionRecord(
            id: UUID(),
            driverID: driverID,
            vehicleID: vehicleID,
            type: type,
            date: .now,
            notes: notes,
            passed: items.allSatisfy(\.isChecked),
            items: items
        )
        inspections.insert(record, at: 0)
        
        if SupabaseConfig.isConfigured {
            Task {
                try? await SupabaseService.shared.addInspection(record)
            }
        }
    }

    func addDefect(driverID: UUID, vehicleID: UUID, severity: WorkOrderPriority, description: String) {
        let defect = DefectReport(
            id: UUID(),
            driverID: driverID,
            vehicleID: vehicleID,
            severity: severity,
            description: description,
            reportedDate: .now,
            isResolved: false
        )
        defects.insert(defect, at: 0)
        
        if SupabaseConfig.isConfigured {
            Task {
                try? await SupabaseService.shared.addDefect(defect)
            }
        }
    }

    func startTrip(driverID: UUID, vehicleID: UUID, origin: String, destination: String) {
        let trip = Trip(
            id: UUID(),
            driverID: driverID,
            vehicleID: vehicleID,
            origin: origin,
            destination: destination,
            startDate: .now,
            endDate: nil,
            distanceKM: Double.random(in: 12...240),
            status: .inProgress
        )
        trips.insert(trip, at: 0)
        
        if SupabaseConfig.isConfigured {
            Task {
                try? await SupabaseService.shared.addTrip(trip)
            }
        }
    }

    func startScheduledTrip(id: UUID) {
        guard let index = trips.firstIndex(where: { $0.id == id }) else { return }
        trips[index].status = .inProgress
        trips[index].startDate = .now
        
        // Update first checkpoint status
        let cps = checkpoints(for: id)
        if let first = cps.first {
            if let cpIndex = tripCheckpoints.firstIndex(where: { $0.id == first.id }) {
                tripCheckpoints[cpIndex].status = .inTransit
                tripCheckpoints[cpIndex].arrivalTime = .now
            }
        }
        
        if SupabaseConfig.isConfigured {
            let updated = trips[index]
            Task {
                try? await SupabaseService.shared.updateTrip(updated)
            }
        }
    }

    func endTrip(_ trip: Trip) {
        guard let index = trips.firstIndex(where: { $0.id == trip.id }) else { return }
        trips[index].status = .completed
        trips[index].endDate = .now
        
        if SupabaseConfig.isConfigured {
            let updated = trips[index]
            Task {
                try? await SupabaseService.shared.updateTrip(updated)
            }
        }
    }

    func markNotificationRead(_ notification: AppNotification) {
        guard let index = notifications.firstIndex(where: { $0.id == notification.id }) else { return }
        notifications[index].isRead = true
        
        if SupabaseConfig.isConfigured {
            let updated = notifications[index]
            Task {
                try? await SupabaseService.shared.updateNotification(updated)
            }
        }
    }

    private func syncDriverAssignments(using vehicle: Vehicle) {
        for index in users.indices where users[index].role == .driver {
            if users[index].id == vehicle.assignedDriverID {
                users[index].assignedVehicleID = vehicle.id
            } else if users[index].assignedVehicleID == vehicle.id {
                users[index].assignedVehicleID = nil
            }
        }
    }
}

// MARK: - Demo Seed Data

enum DemoSeed {
    static func make() -> (
        organizations: [Organization],
        users: [User],
        vehicles: [Vehicle],
        documents: [VehicleDocument],
        trips: [Trip],
        inspections: [InspectionRecord],
        defects: [DefectReport],
        workOrders: [WorkOrder],
        maintenanceSchedules: [MaintenanceSchedule],
        notifications: [AppNotification],
        shifts: [ShiftInfo],
        fuelReceipts: [FuelReceipt],
        chatMessages: [ChatMessage],
        tripCheckpoints: [TripCheckpoint],
        vehicleAlerts: [VehicleAlert],
        breakLogs: [BreakLogEntry],
        dutyStatuses: [UUID: DutyStatus]
    ) {
        let orgID = UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA") ?? UUID()
        let managerID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB") ?? UUID()
        let driver1ID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC") ?? UUID()
        let driver2ID = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDBBBBBBBB") ?? UUID()
        let maint1ID = UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE") ?? UUID()
        let maint2ID = UUID(uuidString: "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF") ?? UUID()

        let vehicle1ID = UUID(uuidString: "11111111-1111-1111-1111-111111111111") ?? UUID()
        let vehicle2ID = UUID(uuidString: "22222222-2222-2222-2222-222222222222") ?? UUID()
        let vehicle3ID = UUID(uuidString: "33333333-3333-3333-3333-333333333333") ?? UUID()
        let vehicle4ID = UUID(uuidString: "44444444-4444-4444-4444-444444444444") ?? UUID()

        let activeTripID = UUID(uuidString: "55555555-5555-5555-5555-555555555555") ?? UUID()
        let scheduledTrip1ID = UUID(uuidString: "66666666-6666-6666-6666-666666666666") ?? UUID()
        let scheduledTrip2ID = UUID(uuidString: "77777777-7777-7777-7777-777777777777") ?? UUID()

        let organization = Organization(
            id: orgID,
            name: "NorthStar Logistics",
            industry: "Regional Distribution",
            fleetSize: 24,
            complianceScore: 96
        )

        let users = [
            User(id: managerID, organizationID: orgID, name: "Ava Peterson", role: .fleetManager, email: "manager@northstar.com", password: "demo123", phone: "+1 415 555 0192", title: "Fleet Operations Lead", assignedVehicleID: nil),
            User(id: driver1ID, organizationID: orgID, name: "Rajesh Kumar", role: .driver, email: "driver@northstar.com", password: "demo123", phone: "+91 98765 43210", title: "Senior Driver", assignedVehicleID: vehicle1ID),
            User(id: driver2ID, organizationID: orgID, name: "Maya Singh", role: .driver, email: "driver2@northstar.com", password: "demo123", phone: "+91 98765 43211", title: "Linehaul Driver", assignedVehicleID: vehicle2ID),
            User(id: maint1ID, organizationID: orgID, name: "Chris Miller", role: .maintenance, email: "maintenance@northstar.com", password: "demo123", phone: "+1 415 555 0141", title: "Workshop Supervisor", assignedVehicleID: nil),
            User(id: maint2ID, organizationID: orgID, name: "Nina Lopez", role: .maintenance, email: "maintenance2@northstar.com", password: "demo123", phone: "+1 415 555 0148", title: "Maintenance Technician", assignedVehicleID: nil)
        ]

        let vehicles = [
            Vehicle(id: vehicle1ID, organizationID: orgID, displayName: "Tata Ace", plateNumber: "TRK-2847", model: "2024 Light Truck", status: .active, fuelLevel: 74, odometer: 128_420, assignedDriverID: driver1ID, nextServiceDate: .now.addingTimeInterval(86400 * 8), utilization: 88),
            Vehicle(id: vehicle2ID, organizationID: orgID, displayName: "Tata Prima 5530", plateNumber: "TX-14-LGT", model: "2023 Heavy Duty", status: .active, fuelLevel: 56, odometer: 96_870, assignedDriverID: driver2ID, nextServiceDate: .now.addingTimeInterval(86400 * 17), utilization: 81),
            Vehicle(id: vehicle3ID, organizationID: orgID, displayName: "Ashok Leyland 4220", plateNumber: "NV-11-CRG", model: "2022 Container Carrier", status: .inService, fuelLevel: 23, odometer: 167_540, assignedDriverID: nil, nextServiceDate: .now.addingTimeInterval(86400 * 2), utilization: 67),
            Vehicle(id: vehicle4ID, organizationID: orgID, displayName: "Eicher Pro 2110", plateNumber: "AZ-09-RTE", model: "2024 Urban Delivery", status: .idle, fuelLevel: 91, odometer: 41_120, assignedDriverID: nil, nextServiceDate: .now.addingTimeInterval(86400 * 24), utilization: 49)
        ]

        let documents: [VehicleDocument] = [
            VehicleDocument(id: UUID(), vehicleID: vehicle1ID, type: .rc, documentNumber: "RC-982371", expiryDate: .now.addingTimeInterval(86400 * 250), isVerified: true),
            VehicleDocument(id: UUID(), vehicleID: vehicle1ID, type: .insurance, documentNumber: "INS-443201", expiryDate: .now.addingTimeInterval(86400 * 120), isVerified: true),
            VehicleDocument(id: UUID(), vehicleID: vehicle1ID, type: .puc, documentNumber: "PUC-220914", expiryDate: .now.addingTimeInterval(86400 * 46), isVerified: true),
            VehicleDocument(id: UUID(), vehicleID: vehicle1ID, type: .permit, documentNumber: "PMT-572104", expiryDate: .now.addingTimeInterval(86400 * 180), isVerified: true),
            VehicleDocument(id: UUID(), vehicleID: vehicle2ID, type: .rc, documentNumber: "RC-812003", expiryDate: .now.addingTimeInterval(86400 * 190), isVerified: true),
            VehicleDocument(id: UUID(), vehicleID: vehicle2ID, type: .insurance, documentNumber: "INS-392212", expiryDate: .now.addingTimeInterval(86400 * 85), isVerified: true),
            VehicleDocument(id: UUID(), vehicleID: vehicle3ID, type: .permit, documentNumber: "PMT-102914", expiryDate: .now.addingTimeInterval(86400 * 30), isVerified: false)
        ]

        let trips = [
            Trip(id: UUID(), driverID: driver1ID, vehicleID: vehicle1ID, origin: "Mumbai", destination: "Nashik", startDate: .now.addingTimeInterval(-86400), endDate: .now.addingTimeInterval(-82000), distanceKM: 168, status: .completed),
            Trip(id: activeTripID, driverID: driver1ID, vehicleID: vehicle1ID, origin: "Mumbai", destination: "Pune Warehouse", startDate: .now.addingTimeInterval(-7200), endDate: nil, distanceKM: 148, status: .inProgress),
            Trip(id: scheduledTrip1ID, driverID: driver1ID, vehicleID: vehicle1ID, origin: "Pune", destination: "Kolhapur", startDate: .now.addingTimeInterval(86400), endDate: nil, distanceKM: 232, status: .scheduled),
            Trip(id: scheduledTrip2ID, driverID: driver1ID, vehicleID: vehicle1ID, origin: "Mumbai", destination: "Surat", startDate: .now.addingTimeInterval(86400 * 2), endDate: nil, distanceKM: 284, status: .scheduled),
            Trip(id: UUID(), driverID: driver2ID, vehicleID: vehicle2ID, origin: "Delhi", destination: "Jaipur", startDate: .now.addingTimeInterval(8600), endDate: nil, distanceKM: 280, status: .scheduled)
        ]

        let inspectionTemplate = [
            InspectionItem(id: UUID(), title: "Brakes and parking brake", isChecked: true),
            InspectionItem(id: UUID(), title: "Lights and indicators", isChecked: true),
            InspectionItem(id: UUID(), title: "Tyres and wheel nuts", isChecked: true),
            InspectionItem(id: UUID(), title: "Fluid leaks under vehicle", isChecked: true),
            InspectionItem(id: UUID(), title: "Horn, mirrors, and camera view", isChecked: true)
        ]

        let inspections = [
            InspectionRecord(id: UUID(), driverID: driver1ID, vehicleID: vehicle1ID, type: .preTrip, date: .now.addingTimeInterval(-90000), notes: "All systems normal before departure.", passed: true, items: inspectionTemplate),
            InspectionRecord(id: UUID(), driverID: driver1ID, vehicleID: vehicle1ID, type: .postTrip, date: .now.addingTimeInterval(-50000), notes: "Minor dirt buildup near rear lamp housing.", passed: true, items: inspectionTemplate)
        ]

        let defects = [
            DefectReport(id: UUID(), driverID: driver1ID, vehicleID: vehicle1ID, severity: .medium, description: "Rear left marker lamp flickers intermittently on rough roads.", reportedDate: .now.addingTimeInterval(-30000), isResolved: false),
            DefectReport(id: UUID(), driverID: driver2ID, vehicleID: vehicle2ID, severity: .high, description: "Noticeable vibration from front axle above 70 km/h.", reportedDate: .now.addingTimeInterval(-54000), isResolved: false)
        ]

        let workOrders = [
            WorkOrder(id: UUID(), vehicleID: vehicle3ID, assignedMaintenanceID: maint1ID, title: "Brake line inspection", details: "ABS alert triggered during highway run. Inspect brake lines and sensor cluster.", priority: .critical, status: .inProgress, scheduledDate: .now.addingTimeInterval(-7200), completedDate: nil, estimatedCost: 1450, repairSummary: ""),
            WorkOrder(id: UUID(), vehicleID: vehicle2ID, assignedMaintenanceID: maint2ID, title: "Front axle vibration diagnosis", details: "Driver reported vibration beyond 70 km/h. Check alignment and suspension mounts.", priority: .high, status: .open, scheduledDate: .now.addingTimeInterval(14400), completedDate: nil, estimatedCost: 780, repairSummary: ""),
            WorkOrder(id: UUID(), vehicleID: vehicle1ID, assignedMaintenanceID: maint1ID, title: "Marker lamp replacement", details: "Replace rear left marker lamp and inspect connector corrosion.", priority: .medium, status: .waitingParts, scheduledDate: .now.addingTimeInterval(86400), completedDate: nil, estimatedCost: 120, repairSummary: "")
        ]

        let schedules = [
            MaintenanceSchedule(id: UUID(), vehicleID: vehicle1ID, serviceType: "Engine oil and filters", dueDate: .now.addingTimeInterval(86400 * 8), status: .upcoming),
            MaintenanceSchedule(id: UUID(), vehicleID: vehicle2ID, serviceType: "Tyre rotation and balancing", dueDate: .now.addingTimeInterval(86400 * 17), status: .upcoming),
            MaintenanceSchedule(id: UUID(), vehicleID: vehicle3ID, serviceType: "Brake system audit", dueDate: .now.addingTimeInterval(-86400), status: .overdue),
            MaintenanceSchedule(id: UUID(), vehicleID: vehicle4ID, serviceType: "Quarterly preventive maintenance", dueDate: .now.addingTimeInterval(86400 * 24), status: .upcoming)
        ]

        let notifications = [
            AppNotification(id: UUID(), userID: managerID, roleTarget: nil, title: "Insurance renewal due", message: "Two policies will expire within the next 90 days. Review documents dashboard.", date: .now.addingTimeInterval(-1800), isRead: false, category: .warning),
            AppNotification(id: UUID(), userID: nil, roleTarget: .driver, title: "Pre-trip inspection required", message: "Complete the inspection checklist before starting your next trip.", date: .now.addingTimeInterval(-2400), isRead: false, category: .info),
            AppNotification(id: UUID(), userID: nil, roleTarget: .maintenance, title: "Critical work order assigned", message: "Brake line inspection for Ashok Leyland 4220 is now in progress.", date: .now.addingTimeInterval(-4000), isRead: false, category: .critical),
            AppNotification(id: UUID(), userID: nil, roleTarget: nil, title: "Compliance score improved", message: "NorthStar Logistics reached 96% documentation compliance this week.", date: .now.addingTimeInterval(-8600), isRead: true, category: .success),
            AppNotification(id: UUID(), userID: driver1ID, roleTarget: nil, title: "Route Updated", message: "Your trip Mumbai → Pune has been updated with a new waypoint.", date: .now.addingTimeInterval(-600), isRead: false, category: .warning)
        ]

        // Driver shift for today
        let todayStart = Calendar.current.startOfDay(for: .now)
        let shiftStart = todayStart.addingTimeInterval(6 * 3600) // 6:00 AM
        let shiftEnd = todayStart.addingTimeInterval(18 * 3600)  // 6:00 PM
        let breakAt = todayStart.addingTimeInterval(12 * 3600)   // 12:00 PM

        let shifts = [
            ShiftInfo(id: UUID(), driverID: driver1ID, startTime: shiftStart, endTime: shiftEnd, breakTime: breakAt, date: todayStart),
            ShiftInfo(id: UUID(), driverID: driver2ID, startTime: shiftStart, endTime: shiftEnd, breakTime: breakAt, date: todayStart)
        ]

        let fuelReceipts = [
            FuelReceipt(id: UUID(), driverID: driver1ID, vehicleID: vehicle1ID, date: .now.addingTimeInterval(-86400), stationName: "HP Petroleum, Panvel", litres: 45.0, amount: 4725.0, vehiclePlate: "TRK-2847"),
            FuelReceipt(id: UUID(), driverID: driver1ID, vehicleID: vehicle1ID, date: .now.addingTimeInterval(-86400 * 3), stationName: "IOCL, Vashi", litres: 50.0, amount: 5250.0, vehiclePlate: "TRK-2847")
        ]

        let chatMessages = [
            ChatMessage(id: UUID(), senderID: driver1ID, receiverID: maint1ID, message: "Hi, the rear lamp is flickering again on highway.", timestamp: .now.addingTimeInterval(-3600), isRead: true),
            ChatMessage(id: UUID(), senderID: maint1ID, receiverID: driver1ID, message: "Noted. We have ordered the replacement part. Will fix during next service.", timestamp: .now.addingTimeInterval(-3000), isRead: true),
            ChatMessage(id: UUID(), senderID: driver1ID, receiverID: maint1ID, message: "Thanks. Is it safe to continue driving?", timestamp: .now.addingTimeInterval(-2400), isRead: true),
            ChatMessage(id: UUID(), senderID: maint1ID, receiverID: driver1ID, message: "Yes, it's safe. Just avoid night driving if possible until we fix it.", timestamp: .now.addingTimeInterval(-1800), isRead: false)
        ]

        let tripCheckpoints = [
            TripCheckpoint(id: UUID(), tripID: activeTripID, name: "Departed", status: .completed, arrivalTime: .now.addingTimeInterval(-7200), departureTime: .now.addingTimeInterval(-7200), sortOrder: 0),
            TripCheckpoint(id: UUID(), tripID: activeTripID, name: "Checkpoint 1 - Panvel", status: .completed, arrivalTime: .now.addingTimeInterval(-5400), departureTime: .now.addingTimeInterval(-5000), sortOrder: 1),
            TripCheckpoint(id: UUID(), tripID: activeTripID, name: "Checkpoint 2 - Lonavala", status: .inTransit, arrivalTime: nil, departureTime: nil, sortOrder: 2),
            TripCheckpoint(id: UUID(), tripID: activeTripID, name: "Pune Warehouse", status: .upcoming, arrivalTime: nil, departureTime: nil, sortOrder: 3)
        ]

        let vehicleAlerts = [
            VehicleAlert(id: UUID(), vehicleID: vehicle1ID, alertType: .fuel, severity: .warning, alertDescription: "Fuel level dropping faster than expected", recommendedAction: "Check for fuel leaks and refuel at the next station", isAcknowledged: false, createdAt: .now.addingTimeInterval(-1200))
        ]

        let breakLogs = [
            BreakLogEntry(id: UUID(), driverID: driver1ID, startTime: .now.addingTimeInterval(-86400 + 21600), endTime: .now.addingTimeInterval(-86400 + 23400), breakType: "Lunch Break")
        ]

        let dutyStatuses: [UUID: DutyStatus] = [
            driver1ID: .onDuty,
            driver2ID: .offDuty
        ]

        return (
            organizations: [organization],
            users: users,
            vehicles: vehicles,
            documents: documents,
            trips: trips,
            inspections: inspections,
            defects: defects,
            workOrders: workOrders,
            maintenanceSchedules: schedules,
            notifications: notifications,
            shifts: shifts,
            fuelReceipts: fuelReceipts,
            chatMessages: chatMessages,
            tripCheckpoints: tripCheckpoints,
            vehicleAlerts: vehicleAlerts,
            breakLogs: breakLogs,
            dutyStatuses: dutyStatuses
        )
    }
}

