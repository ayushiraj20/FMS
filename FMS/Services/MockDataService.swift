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
        // All data loads from Supabase via syncWithDatabase().
        // No mock/seed data — real data only.
        organizations = []
        users = []
        vehicles = []
        documents = []
        trips = []
        inspections = []
        defects = []
        workOrders = []
        maintenanceSchedules = []
        notifications = []
        shifts = []
        fuelReceipts = []
        sosAlerts = []
        chatMessages = []
        tripCheckpoints = []
        vehicleAlerts = []
        breakLogs = []
        driverDutyStatus = [:]
        
        checkOverdueCriticalWorkOrders()
        
        // Asynchronously sync database if credentials are present
        if SupabaseConfig.isConfigured {
            Task {
                await syncWithDatabase()
            }
        }
    }

    /// Merge a remote list into a local list by ID.
    /// - Remote records that match a local record (by id) replace the local version.
    /// - Remote records not found locally are inserted at the front.
    /// - Local records not found in the remote list are KEPT (seed data / offline submissions).
    private func mergeDefects(local: [DefectReport], remote: [DefectReport]) -> [DefectReport] {
        var result = local
        for remoteItem in remote {
            if let idx = result.firstIndex(where: { $0.id == remoteItem.id }) {
                result[idx] = remoteItem          // update with server version
            } else {
                result.insert(remoteItem, at: 0)  // brand-new record from server
            }
        }
        return result.sorted { $0.reportedDate > $1.reportedDate }
    }

    private func mergeWorkOrders(local: [WorkOrder], remote: [WorkOrder]) -> [WorkOrder] {
        var result = local
        for remoteItem in remote {
            if let idx = result.firstIndex(where: { $0.id == remoteItem.id }) {
                result[idx] = remoteItem
            } else {
                result.insert(remoteItem, at: 0)
            }
        }
        return result.sorted { $0.scheduledDate > $1.scheduledDate }
    }

    /// Asynchronously fetches all remote data from Supabase and MERGES into local arrays.
    /// Each table is fetched independently — a failure on one table does NOT affect the others.
    /// Local seed/offline data is NEVER wiped, even if Supabase returns an empty list.
    func syncWithDatabase() async {
        guard SupabaseConfig.isConfigured else { return }

        if let orgs = try? await SupabaseService.shared.fetchOrganizations(), !orgs.isEmpty {
            self.organizations = orgs
        }
        if let usersList = try? await SupabaseService.shared.fetchProfiles(), !usersList.isEmpty {
            self.users = usersList
        }
        if let vehiclesList = try? await SupabaseService.shared.fetchVehicles(), !vehiclesList.isEmpty {
            self.vehicles = vehiclesList
        }
        if let docs = try? await SupabaseService.shared.fetchDocuments() {
            self.documents = docs
        }
        if let tripsList = try? await SupabaseService.shared.fetchTrips() {
            self.trips = tripsList
        }
        if let inspectionsList = try? await SupabaseService.shared.fetchInspections() {
            self.inspections = inspectionsList
        }
        // MERGE: remote defects update or extend local list — never replace/wipe it
        if let remoteDefects = try? await SupabaseService.shared.fetchDefects() {
            self.defects = mergeDefects(local: self.defects, remote: remoteDefects)
            print("[Sync] Merged \(remoteDefects.count) remote defect(s) → total \(self.defects.count)")
        } else {
            print("[Sync] Defects fetch failed — keeping \(self.defects.count) local defect(s)")
        }
        if let remoteOrders = try? await SupabaseService.shared.fetchWorkOrders() {
            self.workOrders = mergeWorkOrders(local: self.workOrders, remote: remoteOrders)
            print("[Sync] Merged \(remoteOrders.count) remote work order(s) → total \(self.workOrders.count)")
        } else {
            print("[Sync] Work orders fetch failed — keeping local data")
        }
        if let schedulesList = try? await SupabaseService.shared.fetchSchedules(), !schedulesList.isEmpty {
            self.maintenanceSchedules = schedulesList
        }
        if let notificationsList = try? await SupabaseService.shared.fetchNotifications() {
            self.notifications = notificationsList
        }
        do {
            let sosList = try await SupabaseService.shared.fetchSOSAlerts()
            self.sosAlerts = sosList
            print("[Sync] Synced \(sosList.count) SOS alert(s) from Supabase ✅")
        } catch {
            print("[Sync] SOS alerts fetch FAILED: \(error) ❌")
        }
    }

    /// Lightweight refresh: only pulls defect_reports + work_orders and MERGES into local.
    /// Used by the Fleet Manager Defect Board. Local/seed data is always preserved.
    func syncDefectsAndWorkOrders() async {
        guard SupabaseConfig.isConfigured else {
            print("[DefectSync] No Supabase — showing \(self.defects.count) local defect(s)")
            return
        }
        do {
            let remoteDefects = try await SupabaseService.shared.fetchDefects()
            let remoteOrders  = try await SupabaseService.shared.fetchWorkOrders()
            self.defects      = mergeDefects(local: self.defects, remote: remoteDefects)
            self.workOrders   = mergeWorkOrders(local: self.workOrders, remote: remoteOrders)
            print("[DefectSync] After merge: \(self.defects.count) defect(s), \(self.workOrders.count) work order(s)")
        } catch {
            print("[DefectSync] ERROR: \(error) — keeping \(self.defects.count) local defect(s)")
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
        guard let user else { return [] }   // never return all notifications without a user

        return notifications.filter {
            // Personal: notification.user_id == this user's profiles.id UUID
            $0.userID == user.id ||
            // Role-broadcast: notification.role_target == this user's role
            $0.roleTarget == user.role ||
            // Global broadcast: no user and no role
            ($0.userID == nil && $0.roleTarget == nil)
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

    func chatMessages(forWorkOrder workOrderID: UUID) -> [ChatMessage] {
        chatMessages.filter { $0.workOrderID == workOrderID }
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

    func triggerSOS(driverID: UUID, vehicleID: UUID, latitude: Double, longitude: Double, emergencyType: String = "Accident", description: String? = nil) {
        let driver = users.first { $0.id == driverID }
        let vehicle = vehicles.first { $0.id == vehicleID }
        let driverName = driver?.name ?? "Unknown Driver"
        let vehicleNumber = vehicle?.plateNumber ?? "KA01AB1234"

        let alert = SOSAlert(
            id: UUID(),
            driverID: driverID,
            driverName: driverName,
            vehicleID: vehicleID,
            vehicleNumber: vehicleNumber,
            emergencyType: emergencyType,
            latitude: latitude,
            longitude: longitude,
            description: description,
            status: "ACTIVE",
            createdAt: .now
        )
        sosAlerts.insert(alert, at: 0)
        
        if SupabaseConfig.isConfigured {
            Task {
                do {
                    try await SupabaseService.shared.addSOSAlert(alert)
                    print("Supabase: Successfully saved SOS alert ✅")
                } catch {
                    print("Supabase: Error inserting SOSAlert: \(error.localizedDescription) ❌")
                }
            }
        }
        
        // Post local notification for real-time offline demo mode
        NotificationCenter.default.post(
            name: NSNotification.Name("LocalSOSTriggered"),
            object: nil,
            userInfo: ["alert": alert]
        )
    }

    func sendChatMessage(senderID: UUID, receiverID: UUID?, message: String, workOrderID: UUID? = nil) {
        let msg = ChatMessage(
            id: UUID(),
            senderID: senderID,
            receiverID: receiverID,
            message: message,
            timestamp: .now,
            isRead: false,
            workOrderID: workOrderID
        )
        chatMessages.append(msg)
        
        if SupabaseConfig.isConfigured {
            Task {
                try? await SupabaseService.shared.addChatMessage(msg)
            }
        }
        
        // Push notification on new message in coordination thread
        if let wID = workOrderID, let order = workOrders.first(where: { $0.id == wID }) {
            let sender = users.first { $0.id == senderID }
            let senderName = sender?.name ?? "Someone"
            let senderRoleText = sender?.role.rawValue ?? "Team Member"
            let alertMsg = "\(senderName) (\(senderRoleText)): \(message)"
            
            let managers = users.filter { $0.role == .fleetManager }
            let vehicle = vehicles.first { $0.id == order.vehicleID }
            
            if sender?.role == .maintenance {
                for mgr in managers {
                    addNotification(userID: mgr.id, roleTarget: nil, title: "New Repair Message", message: alertMsg, category: .maintenance)
                }
                if let driverID = vehicle?.assignedDriverID {
                    addNotification(userID: driverID, roleTarget: nil, title: "New Repair Message", message: alertMsg, category: .maintenance)
                }
            } else if sender?.role == .fleetManager {
                if let techID = order.assignedMaintenanceID {
                    addNotification(userID: techID, roleTarget: nil, title: "New Repair Message", message: alertMsg, category: .maintenance)
                }
                if let driverID = vehicle?.assignedDriverID {
                    addNotification(userID: driverID, roleTarget: nil, title: "New Repair Message", message: alertMsg, category: .maintenance)
                }
            } else if sender?.role == .driver {
                for mgr in managers {
                    addNotification(userID: mgr.id, roleTarget: nil, title: "New Repair Message", message: alertMsg, category: .maintenance)
                }
                if let techID = order.assignedMaintenanceID {
                    addNotification(userID: techID, roleTarget: nil, title: "New Repair Message", message: alertMsg, category: .maintenance)
                }
            }
        }
    }

    func acknowledgeAlert(_ alert: VehicleAlert) {
        guard let index = vehicleAlerts.firstIndex(where: { $0.id == alert.id }) else { return }
        vehicleAlerts[index].isAcknowledged = true
    }

    func addBreakLog(driverID: UUID, breakType: String, durationMinutes: Int? = nil) {
        var end: Date? = nil
        if let duration = durationMinutes {
            end = Date().addingTimeInterval(TimeInterval(duration * 60))
        }
        
        let entry = BreakLogEntry(
            id: UUID(),
            driverID: driverID,
            startTime: .now,
            endTime: end,
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

    func updateUser(_ user: User) {
        if let index = users.firstIndex(where: { $0.id == user.id }) {
            users[index] = user
            if SupabaseConfig.isConfigured {
                Task {
                    try? await SupabaseService.shared.updateProfile(user)
                }
            }
        }
    }

    func deleteUser(_ user: User) {
        users.removeAll { $0.id == user.id }
        
        if SupabaseConfig.isConfigured {
            Task {
                do {
                    try await SupabaseService.shared.deleteProfile(user)
                } catch {
                    print("Supabase deleteProfile error: \(error)")
                }
            }
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
            if SupabaseConfig.isConfigured {
                let userToSync = users[index]
                Task {
                    try? await SupabaseService.shared.updateProfile(userToSync)
                }
            }
        }
        
        if SupabaseConfig.isConfigured {
            Task {
                do {
                    try await SupabaseService.shared.deleteVehicle(vehicle)
                } catch {
                    print("Supabase deleteVehicle error: \(error)")
                }
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
        let oldStatus = workOrders[index].status
        workOrders[index] = workOrder
        
        // Update linked defect report state
        if let defectReportID = workOrder.defectReportID,
           let defectIndex = defects.firstIndex(where: { $0.id == defectReportID }) {
            var updatedDefect = defects[defectIndex]
            switch workOrder.status {
            case .open:
                updatedDefect.status = .approved
                updatedDefect.isResolved = false
            case .inProgress, .waitingParts:
                updatedDefect.status = .inRepair
                updatedDefect.isResolved = false
            case .completed:
                updatedDefect.status = .completed
                updatedDefect.isResolved = true
            }
            defects[defectIndex] = updatedDefect
            
            if SupabaseConfig.isConfigured {
                let dToSync = updatedDefect
                Task {
                    try? await SupabaseService.shared.updateDefect(dToSync)
                }
            }
        }
        
        // Notify if state changed to Completed
        if oldStatus != .completed && workOrder.status == .completed {
            let vehicle = vehicles.first { $0.id == workOrder.vehicleID }
            let plate = vehicle?.plateNumber ?? "Vehicle"
            let text = "Repair completed for \(plate): \(workOrder.title)."
            
            // 1. Notify Fleet Managers
            let managers = users.filter { $0.role == .fleetManager }
            for mgr in managers {
                addNotification(userID: mgr.id, roleTarget: nil, title: "Repair Completed", message: text, category: .success)
            }
            
            // 2. Notify Driver
            if let defectReportID = workOrder.defectReportID,
               let defect = defects.first(where: { $0.id == defectReportID }) {
                let driverMsg = "Your vehicle \(plate) is ready for duty! The reported issue '\(workOrder.title)' has been repaired."
                addNotification(userID: defect.driverID, roleTarget: nil, title: "Vehicle Ready for Duty", message: driverMsg, category: .success)
            } else if let driverID = vehicle?.assignedDriverID {
                let driverMsg = "Your vehicle \(plate) is ready for duty! The reported issue '\(workOrder.title)' has been repaired."
                addNotification(userID: driverID, roleTarget: nil, title: "Vehicle Ready for Duty", message: driverMsg, category: .success)
            }
        }
        
        if SupabaseConfig.isConfigured {
            Task {
                do {
                    try await SupabaseService.shared.updateWorkOrder(workOrder)
                } catch {
                    print("Supabase updateWorkOrder error: \(error)")
                }
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

    func addDefect(driverID: UUID, vehicleID: UUID, severity: WorkOrderPriority, description: String, title: String? = nil, images: [String]? = nil) {
        let defect = DefectReport(
            id: UUID(),
            driverID: driverID,
            vehicleID: vehicleID,
            severity: severity,
            description: description,
            reportedDate: .now,
            isResolved: false,
            title: title,
            images: images,
            status: .pending
        )
        defects.insert(defect, at: 0)
        
        // Notify Fleet Managers
        let driverName = users.first(where: { $0.id == driverID })?.name ?? "Driver"
        let vehiclePlate = vehicles.first(where: { $0.id == vehicleID })?.plateNumber ?? "Vehicle"
        let msg = "\(driverName) reported defect on \(vehiclePlate): \(title ?? description)"
        
        let managers = users.filter { $0.role == .fleetManager }
        for mgr in managers {
            addNotification(
                userID: mgr.id,
                roleTarget: nil,
                title: "New Defect Reported",
                message: msg,
                category: .critical
            )
        }
        
        if SupabaseConfig.isConfigured {
            Task {
                do {
                    try await SupabaseService.shared.addDefect(defect)
                    print("Defect report successfully saved to Supabase ✅")
                } catch {
                    print("🚨 Supabase addDefect Error: \(error.localizedDescription)\nFull Details: \(error)")
                }
            }
        }
    }

    func approveDefectReport(
        defect: DefectReport,
        assignedTechID: UUID,
        title: String,
        priority: WorkOrderPriority,
        details: String
    ) {
        // 1. Mark defect resolved/approved
        guard let defectIndex = defects.firstIndex(where: { $0.id == defect.id }) else { return }
        defects[defectIndex].isResolved = false
        defects[defectIndex].status = .approved
        
        if SupabaseConfig.isConfigured {
            let updatedDefect = defects[defectIndex]
            Task {
                try? await SupabaseService.shared.updateDefect(updatedDefect)
            }
        }
        
        // 2. Create work order
        let order = WorkOrder(
            id: UUID(),
            vehicleID: defect.vehicleID,
            assignedMaintenanceID: assignedTechID,
            title: title,
            details: details,
            priority: priority,
            status: .open,
            scheduledDate: .now,
            completedDate: nil,
            estimatedCost: 150.0,
            repairSummary: "",
            overdueAlertFired: false,
            defectReportID: defect.id,
            images: defect.images
        )
        workOrders.insert(order, at: 0)
        
        if SupabaseConfig.isConfigured {
            Task {
                try? await SupabaseService.shared.addWorkOrder(order)
            }
        }
        
        // 3. Notify assigned technician
        let msg = "You have been assigned to repair work order: \(title)."
        addNotification(
            userID: assignedTechID,
            roleTarget: nil,
            title: "New Repair Assignment",
            message: msg,
            category: .maintenance
        )
        
        // 4. Notify driver that repair is approved
        let driverMsg = "Your reported defect '\(title)' has been approved for repair."
        addNotification(
            userID: defect.driverID,
            roleTarget: nil,
            title: "Repair Request Approved",
            message: driverMsg,
            category: .success
        )
    }
    
    func rejectDefectReport(defect: DefectReport) {
        guard let defectIndex = defects.firstIndex(where: { $0.id == defect.id }) else { return }
        defects[defectIndex].isResolved = true
        defects[defectIndex].status = .completed
        
        if SupabaseConfig.isConfigured {
            let updatedDefect = defects[defectIndex]
            Task {
                try? await SupabaseService.shared.updateDefect(updatedDefect)
            }
        }
        
        // Notify driver of rejection
        let title = defect.title ?? "Defect"
        let driverMsg = "Your defect request '\(title)' has been closed/resolved by the Fleet Manager."
        addNotification(
            userID: defect.driverID,
            roleTarget: nil,
            title: "Defect Report Closed",
            message: driverMsg,
            category: .warning
        )
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
    func addNotification(
        userID: UUID?,
        roleTarget: UserRole?,
        title: String,
        message: String,
        category: NotificationCategory
    ) {
        let notification = AppNotification(
            id: UUID(),
            userID: userID,
            roleTarget: roleTarget,
            title: title,
            message: message,
            date: .now,
            isRead: false,
            category: category
        )
        notifications.insert(notification, at: 0)

        // Schedule local push notification
        NotificationScheduler.scheduleBroadcastAlert(title: title, body: message)

        if SupabaseConfig.isConfigured {
            Task { try? await SupabaseService.shared.addNotification(notification) }
        }
    }

    func addTripAssignment(
        driver: User,
        vehicle: Vehicle,
        origin: String,
        destination: String,
        routeDetails: String?,
        notes: String?,
        startDate: Date,
        endDate: Date?,
        distanceKM: Double
    ) {
        // 1. Assign vehicle to driver
        var updatedVehicle = vehicle
        updatedVehicle.assignedDriverID = driver.id
        updateVehicle(updatedVehicle)
        
        // 2. Create trip entry in trips
        let trip = Trip(
            id: UUID(),
            driverID: driver.id,
            vehicleID: vehicle.id,
            origin: origin,
            destination: destination,
            startDate: startDate,
            endDate: endDate,
            distanceKM: distanceKM,
            status: .scheduled,
            safetyScore: nil,
            routeDetails: routeDetails,
            notes: notes
        )
        trips.insert(trip, at: 0)
        
        if SupabaseConfig.isConfigured {
            Task {
                try? await SupabaseService.shared.addTrip(trip)
            }
        }
        
        // 3. Create notification for assigned driver
        let notificationMsg = "You have been assigned vehicle \(vehicle.plateNumber) for \(origin) → \(destination) route."
        addNotification(
            userID: driver.id,
            roleTarget: nil,
            title: "New Trip Assigned",
            message: notificationMsg,
            category: .info
        )
    }

    private func syncDriverAssignments(using vehicle: Vehicle) {
        for index in users.indices where users[index].role == .driver {
            var updated = false
            if users[index].id == vehicle.assignedDriverID {
                if users[index].assignedVehicleID != vehicle.id {
                    users[index].assignedVehicleID = vehicle.id
                    updated = true
                }
            } else if users[index].assignedVehicleID == vehicle.id {
                users[index].assignedVehicleID = nil
                updated = true
            }
            
            if updated && SupabaseConfig.isConfigured {
                let userToSync = users[index]
                Task {
                    try? await SupabaseService.shared.updateProfile(userToSync)
                }
            }
        }
    }
    
    func checkOverdueCriticalWorkOrders() {
        for order in workOrders where order.isOverdue {
            // Use overdueAlertFired flag instead of checking local notifications array.
            // This survives a Supabase sync (which overwrites the local notifications array)
            // because the flag is stored on the work order row itself in Supabase.
            if order.overdueAlertFired { continue }

            guard let vehicle = self.vehicle(for: order.vehicleID) else { continue }

            let title = "Critical Work Order Overdue"
            let vehicleDetails = "\(vehicle.displayName) (\(vehicle.plateNumber))"
            let message = "Work Order '\(order.title)' for \(vehicleDetails) is \(order.overdueDurationString)."

            // 1. Notify Technician
            if let techID = order.assignedMaintenanceID {
                addNotification(
                    userID: techID,
                    roleTarget: nil,
                    title: title,
                    message: message,
                    category: .critical
                )
            }

            // 2. Notify Fleet Manager
            addNotification(
                userID: nil,
                roleTarget: .fleetManager,
                title: title,
                message: message,
                category: .critical
            )

            // 3. Persist the flag so this alert is never re-fired even after a sync
            if let index = workOrders.firstIndex(where: { $0.id == order.id }) {
                workOrders[index].overdueAlertFired = true
                let updated = workOrders[index]
                if SupabaseConfig.isConfigured {
                    Task {
                        do {
                            try await SupabaseService.shared.updateWorkOrder(updated)
                        } catch {
                            print("Supabase overdueAlertFired update error: \(error)")
                        }
                    }
                }
            }
        }
    }
}


// MARK: - Demo Seed Data

// DemoSeed removed – all data is sourced from Supabase.
