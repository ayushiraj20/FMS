import Foundation
import Combine
import Observation
import UIKit

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
    var partOrders: [PartOrder]

    // Driver-specific data
    var shifts: [ShiftInfo]
    var fuelReceipts: [FuelReceipt]
    var sosAlerts: [SOSAlert]
    var chatMessages: [ChatMessage]
    var tripCheckpoints: [TripCheckpoint]
    var vehicleAlerts: [VehicleAlert]
    var breakLogs: [BreakLogEntry]
    var driverDutyStatus: [UUID: DutyStatus]
    var geofenceAlertedVehicleIDs: Set<UUID>
    var tripRoutePlansByTripID: [UUID: TripRoutePlan] = [:]
    var routeGeofenceAlertStates: [UUID: RouteGeofenceAlertState] = [:]

    init() {
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
        partOrders = []
        shifts = []
        fuelReceipts = []
        chatMessages = []
        tripCheckpoints = []
        vehicleAlerts = []
        breakLogs = []
        driverDutyStatus = [:]
        sosAlerts = []
        geofenceAlertedVehicleIDs = []
        
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
    /// - Local records not found in the remote list are kept (offline submissions).
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

    /// Merge remote vehicles into local list.
    /// Remote records update local ones; new remote records are inserted.
    /// Local-only records (added offline) are kept.
    /// This prevents a successful local assignment from being wiped by a stale sync.
    private func mergeVehicles(local: [Vehicle], remote: [Vehicle]) -> [Vehicle] {
        var result = local
        for remoteItem in remote {
            if let idx = result.firstIndex(where: { $0.id == remoteItem.id }) {
                result[idx] = remoteItem
            } else {
                result.insert(remoteItem, at: 0)
            }
        }
        return result.sorted { $0.displayName < $1.displayName }
    }

    /// Asynchronously fetches all remote data from Supabase and MERGES into local arrays.
    /// Each table is fetched independently — a failure on one table does NOT affect the others.
    /// Locally created records are kept when not present on the server.
    func syncWithDatabase() async {
        guard SupabaseConfig.isConfigured else { return }

        if let orgs = try? await SupabaseService.shared.fetchOrganizations(), !orgs.isEmpty {
            self.organizations = orgs
        }
        if let usersList = try? await SupabaseService.shared.fetchProfiles(), !usersList.isEmpty {
            self.users = usersList
            applyDutyStatusesFromProfiles()
        }
        if let vehiclesList = try? await SupabaseService.shared.fetchVehicles(), !vehiclesList.isEmpty {
            self.vehicles = vehiclesList.sorted { $0.displayName < $1.displayName }
        }
        // Re-derive each driver's assignedVehicleID from the vehicles array.
        // The RLS policy on 'profiles' only allows a user to update their OWN row,
        // so a fleet manager cannot update another driver's assigned_vehicle_id via
        // updateProfile. The source of truth for assignment is vehicles.assigned_driver_id,
        // which fleet managers CAN update. We apply that here so UI stays correct after sync.
        for index in users.indices where users[index].role == .driver {
            let driverID = users[index].id
            let assignedVehicle = vehicles.first { $0.assignedDriverID == driverID }
            users[index].assignedVehicleID = assignedVehicle?.id
        }
        if let docs = try? await SupabaseService.shared.fetchDocuments() {
            self.documents = docs
        }
        if let tripsList = try? await SupabaseService.shared.fetchTrips() {
            self.trips = tripsList
            reloadTripRoutePlansFromStoredTrips()
        }
        if let inspectionsList = try? await SupabaseService.shared.fetchInspections() {
            self.inspections = inspectionsList
        }
        if let remoteDefects = try? await SupabaseService.shared.fetchDefects() {
            self.defects = remoteDefects
            print("[Sync] Loaded \(remoteDefects.count) remote defect(s)")
        } else {
            print("[Sync] Defects fetch failed — keeping \(self.defects.count) local defect(s)")
        }
        if let remoteOrders = try? await SupabaseService.shared.fetchWorkOrders() {
            self.workOrders = remoteOrders
            print("[Sync] Loaded \(remoteOrders.count) remote work order(s)")
        } else {
            print("[Sync] Work orders fetch failed — keeping local data")
        }
        if let schedulesList = try? await SupabaseService.shared.fetchSchedules(), !schedulesList.isEmpty {
            self.maintenanceSchedules = schedulesList
        }
        if let notificationsList = try? await SupabaseService.shared.fetchNotifications() {
            self.notifications = notificationsList
        }
        if let chatList = try? await SupabaseService.shared.fetchChatMessages() {
            self.chatMessages = chatList
        }
        // Sync part orders for the first available organization
        if let orgID = organizations.first?.id {
            if let orders = try? await SupabaseService.shared.fetchPartOrders(organizationID: orgID) {
                self.partOrders = orders
                print("[Sync] Loaded \(orders.count) part order(s)")
            }
        }
    }

    func syncChatMessages() async {
        guard SupabaseConfig.isConfigured else { return }
        if let chatList = try? await SupabaseService.shared.fetchChatMessages() {
            // Merge remote messages into our local cache to prevent newly sent local
            // messages from disappearing before their Supabase insert is finished!
            var merged = self.chatMessages
            for remoteMsg in chatList {
                if let idx = merged.firstIndex(where: { $0.id == remoteMsg.id }) {
                    merged[idx] = remoteMsg
                } else {
                    merged.append(remoteMsg)
                }
            }
            self.chatMessages = merged.sorted { $0.timestamp < $1.timestamp }
        }
    }

    /// Lightweight refresh: only pulls defect_reports + work_orders and replaces local.
    /// Used by the Fleet Manager Defect Board. Local/seed data is always preserved.
    func syncDefectsAndWorkOrders() async {
        guard SupabaseConfig.isConfigured else {
            print("[DefectSync] No Supabase — showing \(self.defects.count) local defect(s)")
            return
        }
        do {
            let remoteDefects = try await SupabaseService.shared.fetchDefects()
            let remoteOrders  = try await SupabaseService.shared.fetchWorkOrders()
            self.defects      = remoteDefects
            self.workOrders   = remoteOrders
            print("[DefectSync] Synced from Supabase: \(self.defects.count) defect(s), \(self.workOrders.count) work order(s)")
        } catch {
            print("[DefectSync] ERROR: \(error) — keeping \(self.defects.count) local defect(s)")
        }
    }

    /// Lightweight refresh: pulls only maintenance-related tables.
    /// Used by the Maintenance role views for targeted refreshes.
    func syncMaintenanceData() async {
        guard SupabaseConfig.isConfigured else { return }
        do {
            let remoteOrders = try await SupabaseService.shared.fetchWorkOrders()
            self.workOrders = remoteOrders
            let remoteSchedules = try await SupabaseService.shared.fetchSchedules()
            self.maintenanceSchedules = remoteSchedules
            if let orgID = organizations.first?.id {
                let remotePartOrders = try await SupabaseService.shared.fetchPartOrders(organizationID: orgID)
                self.partOrders = remotePartOrders
            }
            print("[MaintenanceSync] Synced: \(workOrders.count) WOs, \(maintenanceSchedules.count) schedules, \(partOrders.count) part orders")
        } catch {
            print("[MaintenanceSync] ERROR: \(error)")
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

    func isDriver(_ driver: User, compatibleWith vehicle: Vehicle) -> Bool {
        guard driver.role == .driver else { return false }
        let license = driverLicenseCategory(for: driver)
        let requirement = licenseRequirement(for: vehicle)

        switch requirement {
        case .twoWheeler:
            return true
        case .light:
            return license == .light || license == .heavy
        case .heavy:
            return license == .heavy
        }
    }

    func driverLicenseSummary(for driver: User) -> String {
        switch driverLicenseCategory(for: driver) {
        case .twoWheeler:
            return "2-wheeler licence"
        case .light:
            return "Light vehicle licence"
        case .heavy:
            return "Heavy vehicle licence"
        }
    }

    func requiredLicenseSummary(for vehicle: Vehicle) -> String {
        switch licenseRequirement(for: vehicle) {
        case .twoWheeler:
            return "2-wheeler"
        case .light:
            return "Light vehicle"
        case .heavy:
            return "Heavy vehicle"
        }
    }


    func vehicle(for id: UUID?) -> Vehicle? {
        guard let id else { return nil }
        return vehicles.first { $0.id == id }
    }

    func user(for id: UUID?) -> User? {
        guard let id else { return nil }
        return users.first { $0.id == id }
    }

    private enum DriverLicenseCategory {
        case twoWheeler
        case light
        case heavy
    }

    private func driverLicenseCategory(for driver: User) -> DriverLicenseCategory {
        let profileText = "\(driver.title) \(driver.email)".lowercased()

        if profileText.contains("2 wheeler") ||
            profileText.contains("two wheeler") ||
            profileText.contains("bike") ||
            profileText.contains("motorcycle") ||
            profileText.contains("scooter") {
            return .twoWheeler
        }

        if profileText.contains("hmv") ||
            profileText.contains("heavy") ||
            profileText.contains("truck") ||
            profileText.contains("linehaul") ||
            profileText.contains("transport") {
            return .heavy
        }

        if profileText.contains("lmv") ||
            profileText.contains("light") ||
            profileText.contains("car") ||
            profileText.contains("van") {
            return .light
        }

        // Existing data has generic titles such as "Senior Driver"; treat them as
        // transport-capable drivers unless a narrower licence is explicitly recorded.
        return .heavy
    }

    private func licenseRequirement(for vehicle: Vehicle) -> DriverLicenseCategory {
        let vehicleText = "\(vehicle.vehicleType) \(vehicle.model) \(vehicle.displayName)".lowercased()

        if vehicleText.contains("2 wheeler") ||
            vehicleText.contains("two wheeler") ||
            vehicleText.contains("bike") ||
            vehicleText.contains("motorcycle") ||
            vehicleText.contains("scooter") {
            return .twoWheeler
        }

        if vehicleText.contains("truck") ||
            vehicleText.contains("heavy") ||
            vehicleText.contains("container") ||
            vehicleText.contains("bus") ||
            vehicleText.contains("trailer") {
            return .heavy
        }

        return .light
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

    func fleetUtilizationSummary() -> FleetUtilizationSummary {
        let total = vehicles.count
        let vehicleIDsWithOpenWork = Set(workOrders
            .filter { $0.status != .completed }
            .map(\.vehicleID))

        let maintenanceCount = vehicles.filter {
            $0.status == .outOfService || vehicleIDsWithOpenWork.contains($0.id)
        }.count

        let activeCount = vehicles.filter {
            ($0.status == .active || $0.status == .inService) &&
            !vehicleIDsWithOpenWork.contains($0.id)
        }.count

        let idleCount = vehicles.filter {
            $0.status == .idle &&
            !vehicleIDsWithOpenWork.contains($0.id)
        }.count

        let averageUtilization = total > 0
            ? Int((Double(vehicles.reduce(0) { $0 + $1.utilization }) / Double(total)).rounded())
            : 0

        let relevantTrips = trips.filter { $0.status == .completed || $0.status == .inProgress }
        let completedTrips = trips.filter { $0.status == .completed }
        let totalTripDistance = relevantTrips.reduce(0.0) { $0 + $1.distanceKM }
        let averageTripDistance = relevantTrips.isEmpty ? 0 : totalTripDistance / Double(relevantTrips.count)
        let activeTrips = trips.filter { $0.status == .inProgress }.count

        return FleetUtilizationSummary(
            totalVehicles: total,
            activeVehicles: activeCount,
            idleVehicles: idleCount,
            maintenanceVehicles: maintenanceCount,
            averageUtilization: averageUtilization,
            totalTripDistance: totalTripDistance,
            averageTripDistance: averageTripDistance,
            completedTrips: completedTrips.count,
            activeTrips: activeTrips
        )
    }

    func chatMessages(for driverID: UUID) -> [ChatMessage] {
        chatMessages.filter { $0.senderID == driverID || $0.receiverID == driverID }
            .sorted { $0.timestamp < $1.timestamp }
    }

    func chatMessages(between firstUserID: UUID, and secondUserID: UUID) -> [ChatMessage] {
        chatMessages
            .filter {
                $0.workOrderID == nil &&
                (
                    ($0.senderID == firstUserID && $0.receiverID == secondUserID) ||
                    ($0.senderID == secondUserID && $0.receiverID == firstUserID)
                )
            }
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
        if let cached = driverDutyStatus[driverID] {
            return cached
        }
        if let profileStatus = users.first(where: { $0.id == driverID })?.dutyStatus {
            return profileStatus
        }
        return .offDuty
    }

    func applyDutyStatusesFromProfiles() {
        for user in users where user.role == .driver {
            driverDutyStatus[user.id] = user.dutyStatus
        }
    }

    func assignedVehicle(for driverID: UUID) -> Vehicle? {
        vehicles.first { $0.assignedDriverID == driverID }
    }

    func canAssignVehicle(_ vehicle: Vehicle, to driver: User) -> Bool {
        guard let assigned = assignedVehicle(for: driver.id) else { return true }
        return assigned.id == vehicle.id
    }

    func hasOpenTripAssignment(for driverID: UUID) -> Bool {
        trips.contains { trip in
            trip.driverID == driverID &&
            (trip.status == .scheduled || trip.status == .inProgress)
        }
    }

    func isDriverAvailableForDispatch(_ driver: User) -> Bool {
        guard driver.role == .driver else { return false }
        return dutyStatus(for: driver.id) == .onDuty && !hasOpenTripAssignment(for: driver.id)
    }

    func availableDriversForDispatch(organizationID: UUID? = nil) -> [User] {
        users
            .filter { user in
                guard user.role == .driver else { return false }
                if let organizationID, user.organizationID != organizationID {
                    return false
                }
                return isDriverAvailableForDispatch(user)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Drivers eligible to be assigned a trip by a Fleet Manager.
    /// Unlike `isDriverAvailableForDispatch`, this does NOT require the driver to be On Duty —
    /// so the FM can pre-assign trips to off-duty drivers who will see them upon going online.
    func isDriverEligibleForTripAssignment(_ driver: User) -> Bool {
        guard driver.role == .driver else { return false }
        return !hasOpenTripAssignment(for: driver.id)
    }

    func driversEligibleForTripAssignment(organizationID: UUID? = nil) -> [User] {
        users
            .filter { user in
                guard user.role == .driver else { return false }
                if let organizationID, user.organizationID != organizationID {
                    return false
                }
                return isDriverEligibleForTripAssignment(user)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Driver-Specific Mutations

    func toggleDutyStatus(for driverID: UUID) {
        let current = dutyStatus(for: driverID)
        let newStatus: DutyStatus = current == .onDuty ? .offDuty : .onDuty
        setDutyStatus(newStatus, for: driverID)

        if newStatus == .onDuty, let driver = users.first(where: { $0.id == driverID }) {
            notifyFleetManagersDriverOnDuty(driver)
        }
    }

    func setDutyStatus(_ status: DutyStatus, for driverID: UUID) {
        driverDutyStatus[driverID] = status
        if let index = users.firstIndex(where: { $0.id == driverID }) {
            users[index].dutyStatus = status
        }

        guard SupabaseConfig.isConfigured else { return }
        Task {
            do {
                try await SupabaseService.shared.updateDriverDutyStatus(driverID: driverID, status: status)
            } catch {
                print("[Supabase ERROR] Failed to update duty status: \(error.localizedDescription)")
            }
        }
    }

    private func notifyFleetManagersDriverOnDuty(_ driver: User) {
        let managers = users.filter { user in
            user.role == .fleetManager &&
            user.organizationID == driver.organizationID
        }

        let tripNote = hasOpenTripAssignment(for: driver.id)
            ? " They already have a trip assigned."
            : " They are available for a new trip assignment."

        let message = "\(driver.name) is now on duty.\(tripNote)"

        for manager in managers {
            addNotification(
                userID: manager.id,
                roleTarget: nil,
                title: "Driver On Duty",
                message: message,
                category: .info
            )
        }

        if managers.isEmpty {
            addNotification(
                userID: nil,
                roleTarget: .fleetManager,
                title: "Driver On Duty",
                message: message,
                category: .info
            )
        }
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

    func triggerSOS(
        driverID: UUID,
        vehicleID: UUID,
        latitude: Double,
        longitude: Double,
        emergencyType: String = "SOS Alert",
        description: String? = nil
    ) {
        let driver = users.first { $0.id == driverID }
        let driverName = driver?.name ?? "Unknown Driver"
        
        let vehicle = vehicles.first { $0.id == vehicleID }
        let vehicleNumber = vehicle?.plateNumber ?? "Unknown Vehicle"
        
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
            createdAt: Date()
        )
        sosAlerts.insert(alert, at: 0)
        
        // Notify Fleet Managers
        let managers = users.filter { $0.role == .fleetManager }
        for mgr in managers {
            addNotification(
                userID: mgr.id,
                roleTarget: nil,
                title: "🚨 SOS Alert Active!",
                message: "\(driverName) triggered an emergency SOS from \(vehicleNumber).",
                category: .critical
            )
        }
        
        if SupabaseConfig.isConfigured {
            Task {
                try? await SupabaseService.shared.addSOSAlert(alert)
            }
        }
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
                do {
                    try await SupabaseService.shared.addChatMessage(msg)
                    print("[Supabase Chat] Message \(msg.id) successfully saved.")
                } catch {
                    print("[Supabase Chat ERROR] Failed to save chat message: \(error)")
                }
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
        } else if let receiverID, workOrderID == nil {
            let sender = users.first { $0.id == senderID }
            let receiver = users.first { $0.id == receiverID }
            let senderName = sender?.name ?? "Someone"
            let preview = message.count > 120 ? String(message.prefix(117)) + "…" : message

            if sender?.role == .driver, receiver?.role == .fleetManager {
                addNotification(
                    userID: receiverID,
                    roleTarget: nil,
                    title: "Voice message from driver",
                    message: "\(senderName): \(preview)",
                    category: .info
                )
            } else if sender?.role == .fleetManager, receiver?.role == .driver {
                addNotification(
                    userID: receiverID,
                    roleTarget: nil,
                    title: "Message from fleet manager",
                    message: "\(senderName): \(preview)",
                    category: .info
                )
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
            assignedVehicleID: nil,
            isPasswordResetRequired: true
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
            if role == .driver,
               let availableVehicle = vehicles.first(where: {
                   $0.organizationID == organizationID && $0.assignedDriverID == nil
               }),
               let idx = vehicles.firstIndex(where: { $0.id == availableVehicle.id }) {
                user.assignedVehicleID = availableVehicle.id
                vehicles[idx].assignedDriverID = user.id
                vehicles[idx].status = .active
            }
            users.insert(user, at: 0)
        }
    }

    func updateUser(_ user: User) {
        if let index = users.firstIndex(where: { $0.id == user.id }) {
            users[index] = user
            if SupabaseConfig.isConfigured {
                Task {
                    do {
                        try await SupabaseService.shared.updateProfile(user)
                        print("[Sync] Profile updated in Supabase: \(user.name)")
                    } catch {
                        print("[Sync] updateProfile FAILED for \(user.name): \(error)")
                    }
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
                do {
                    try await SupabaseService.shared.addVehicle(vehicle)
                    print("[Supabase] Vehicle successfully inserted: \(vehicle.displayName) (\(vehicle.plateNumber))")
                } catch {
                    print("[Supabase ERROR] Failed to insert vehicle: \(error)")
                }
            }
        }
    }

    func updateVehicle(_ vehicle: Vehicle) {
        guard let index = vehicles.firstIndex(where: { $0.id == vehicle.id }) else { return }
        vehicles[index] = vehicle
        syncDriverAssignments(using: vehicle)
        
        if SupabaseConfig.isConfigured {
            Task {
                do {
                    try await SupabaseService.shared.updateVehicle(vehicle)
                    print("[Sync] Vehicle updated in Supabase: \(vehicle.displayName)")
                } catch {
                    print("[Sync] updateVehicle FAILED for \(vehicle.displayName): \(error)")
                }
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

    func addDocument(vehicleID: UUID, type: DocumentType, number: String, expiryDate: Date, imageUrl: String? = nil) {
        if let index = documents.firstIndex(where: { $0.vehicleID == vehicleID && $0.type == type }) {
            documents[index].documentNumber = number
            documents[index].expiryDate = expiryDate
            if let imgUrl = imageUrl {
                documents[index].imageUrl = imgUrl
            }
            let doc = documents[index]
            if SupabaseConfig.isConfigured {
                Task {
                    do {
                        try await SupabaseService.shared.updateDocument(doc)
                        print("[Supabase] Document successfully updated: \(doc.type.rawValue) -> image_url: \(doc.imageUrl ?? "nil")")
                    } catch {
                        print("[Supabase ERROR] Failed to update document: \(error)")
                    }
                }
            }
        } else {
            let document = VehicleDocument(
                id: UUID(),
                vehicleID: vehicleID,
                type: type,
                documentNumber: number,
                expiryDate: expiryDate,
                isVerified: true,
                imageUrl: imageUrl
            )
            documents.insert(document, at: 0)
            
            if SupabaseConfig.isConfigured {
                Task {
                    do {
                        try await SupabaseService.shared.addDocument(document)
                        print("[Supabase] Document successfully inserted: \(document.type.rawValue) -> image_url: \(document.imageUrl ?? "nil")")
                    } catch {
                        print("[Supabase ERROR] Failed to insert document: \(error)")
                    }
                }
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
                do {
                    try await SupabaseService.shared.addWorkOrder(order)
                    print("[Supabase WorkOrder] WorkOrder \(order.id) successfully added ✅")
                } catch {
                    print("[Supabase WorkOrder ERROR] Failed to add WorkOrder to database: \(error.localizedDescription)\nFull Details: \(error)")
                }
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

    func deleteWorkOrder(_ workOrder: WorkOrder) {
        workOrders.removeAll { $0.id == workOrder.id }
        if SupabaseConfig.isConfigured {
            Task {
                do {
                    try await SupabaseService.shared.deleteWorkOrder(workOrder)
                    print("[Supabase] Work order deleted: \(workOrder.id)")
                } catch {
                    print("[Supabase ERROR] deleteWorkOrder: \(error)")
                }
            }
        }
    }

    // MARK: - Part Order Mutations

    func addPartOrder(_ order: PartOrder) {
        partOrders.insert(order, at: 0)
        if SupabaseConfig.isConfigured {
            Task {
                do {
                    try await SupabaseService.shared.addPartOrder(order)
                    print("[Supabase] Part order added: \(order.partName)")
                } catch {
                    print("[Supabase ERROR] addPartOrder: \(error)")
                }
            }
        }
    }

    func updatePartOrder(_ order: PartOrder) {
        guard let index = partOrders.firstIndex(where: { $0.id == order.id }) else { return }
        partOrders[index] = order
        if SupabaseConfig.isConfigured {
            Task {
                do {
                    try await SupabaseService.shared.updatePartOrder(order)
                    print("[Supabase] Part order updated: \(order.partName)")
                } catch {
                    print("[Supabase ERROR] updatePartOrder: \(error)")
                }
            }
        }
    }

    func deletePartOrder(_ order: PartOrder) {
        partOrders.removeAll { $0.id == order.id }
        if SupabaseConfig.isConfigured {
            Task {
                do {
                    try await SupabaseService.shared.deletePartOrder(order)
                    print("[Supabase] Part order deleted: \(order.partName)")
                } catch {
                    print("[Supabase ERROR] deletePartOrder: \(error)")
                }
            }
        }
    }

    // MARK: - Work Order Parts Mutations

    func saveWorkOrderParts(_ parts: [WorkOrderPartUsage], workOrderID: UUID, decrementStock: Bool = false) {
        if SupabaseConfig.isConfigured {
            Task {
                do {
                    try await SupabaseService.shared.saveWorkOrderParts(parts, workOrderID: workOrderID)
                    print("[Supabase] Saved \(parts.count) part(s) for work order \(workOrderID)")

                    // Post notification to reload inventory views in real time
                    NotificationCenter.default.post(name: Notification.Name("inventoryNeedsRefresh"), object: nil)

                    // Check each consumed part's updated quantity and alert fleet manager if low stock
                    await checkLowStockAndNotify(for: parts)
                } catch {
                    print("[Supabase ERROR] saveWorkOrderParts: \(error)")
                }
            }
        }
    }

    /// Fetches the current quantity of each part used in the work order and fires a
    /// low-stock notification (to Fleet Managers and Maintenance Personnel) for any
    /// part whose remaining quantity has dropped to 2 or below.
    private func checkLowStockAndNotify(for parts: [WorkOrderPartUsage]) async {
        guard let orgID = organizations.first?.id else { return }
        do {
            let allParts = try await SupabaseService.shared.fetchSpareParts(organizationID: orgID)
            let consumedIDs = Set(parts.map { $0.sparePartID })
            for part in allParts where consumedIDs.contains(part.id) {
                guard part.quantity <= 2 else { continue }

                let unitLabel = part.quantity == 1 ? "unit" : "units"
                let stockStatus = part.quantity == 0 ? "OUT OF STOCK" : "only \(part.quantity) \(unitLabel) remaining"
                let title = part.quantity == 0 ? "🚨 Part Out of Stock" : "⚠️ Low Stock Alert"
                let message = "\(part.name) (\(part.partNumber)) is \(stockStatus). Please reorder soon."

                // Notify Fleet Manager role
                addNotification(
                    userID: nil,
                    roleTarget: .fleetManager,
                    title: title,
                    message: message,
                    category: part.quantity == 0 ? .warning : .warning
                )
                // Notify Maintenance Personnel role
                addNotification(
                    userID: nil,
                    roleTarget: .maintenance,
                    title: title,
                    message: message,
                    category: .warning
                )
                print("[Low Stock] Notified: \(part.name) — qty \(part.quantity)")
            }
        } catch {
            print("[Low Stock Check ERROR] \(error)")
        }
    }

    // MARK: - Maintenance Schedule Mutations

    func addMaintenanceSchedule(vehicleID: UUID, serviceType: String, dueDate: Date) {
        let schedule = MaintenanceSchedule(
            id: UUID(),
            vehicleID: vehicleID,
            serviceType: serviceType,
            dueDate: dueDate,
            status: .upcoming
        )
        maintenanceSchedules.insert(schedule, at: 0)
        if SupabaseConfig.isConfigured {
            Task {
                do {
                    try await SupabaseService.shared.addMaintenanceSchedule(schedule)
                    print("[Supabase] Maintenance schedule added: \(serviceType)")
                } catch {
                    print("[Supabase ERROR] addMaintenanceSchedule: \(error)")
                }
            }
        }
    }

    func updateMaintenanceSchedule(_ schedule: MaintenanceSchedule) {
        guard let index = maintenanceSchedules.firstIndex(where: { $0.id == schedule.id }) else { return }
        maintenanceSchedules[index] = schedule
        if SupabaseConfig.isConfigured {
            Task {
                do {
                    try await SupabaseService.shared.updateMaintenanceSchedule(schedule)
                    print("[Supabase] Maintenance schedule updated: \(schedule.serviceType)")
                } catch {
                    print("[Supabase ERROR] updateMaintenanceSchedule: \(error)")
                }
            }
        }
    }

    func deleteMaintenanceSchedule(_ schedule: MaintenanceSchedule) {
        maintenanceSchedules.removeAll { $0.id == schedule.id }
        if SupabaseConfig.isConfigured {
            Task {
                do {
                    try await SupabaseService.shared.deleteMaintenanceSchedule(schedule)
                    print("[Supabase] Maintenance schedule deleted: \(schedule.serviceType)")
                } catch {
                    print("[Supabase ERROR] deleteMaintenanceSchedule: \(error)")
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
                do {
                    try await SupabaseService.shared.addInspection(record)
                    print("[Supabase] Inspection record \(record.id) (\(type.rawValue)) inserted successfully.")
                } catch {
                    print("[Supabase ERROR] Failed to insert inspection: \(error)")
                }
            }
        }
    }

    func addDefect(driverID: UUID, vehicleID: UUID, severity: WorkOrderPriority, description: String, title: String? = nil, images: [String]? = nil, photoImages: [UIImage]? = nil) {
        let defectID = UUID()
        var defect = DefectReport(
            id: defectID,
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
                    // Upload photos to Supabase Storage and collect signed URLs
                    if let photos = photoImages, !photos.isEmpty {
                        var uploadedURLs: [String] = []
                        for (index, photo) in photos.enumerated() {
                            guard let jpegData = photo.jpegData(compressionQuality: 0.7) else { continue }
                            let url = try await SupabaseService.shared.uploadDefectPhoto(
                                imageData: jpegData,
                                vehicleID: vehicleID,
                                defectID: defectID,
                                index: index
                            )
                            uploadedURLs.append(url)
                        }
                        defect.images = uploadedURLs
                        // Update the local copy too
                        if let idx = defects.firstIndex(where: { $0.id == defectID }) {
                            defects[idx].images = uploadedURLs
                        }
                    }
                    
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
                do {
                    try await SupabaseService.shared.updateDefect(updatedDefect)
                    print("[Supabase Defect Approval] Defect \(updatedDefect.id) successfully updated to Approved status ✅")
                } catch {
                    print("[Supabase Defect Approval ERROR] Failed to update defect status: \(error.localizedDescription)\nFull Details: \(error)")
                }
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
                do {
                    try await SupabaseService.shared.addWorkOrder(order)
                    print("[Supabase Defect Approval] WorkOrder \(order.id) successfully created and saved ✅")
                } catch {
                    print("[Supabase Defect Approval ERROR] Failed to save WorkOrder to database: \(error.localizedDescription)\nFull Details: \(error)")
                }
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
        
        // Update vehicle status to Transit (In Service)
        if let idx = vehicles.firstIndex(where: { $0.id == vehicleID }) {
            vehicles[idx].status = .inService
            let updatedVehicle = vehicles[idx]
            if SupabaseConfig.isConfigured {
                Task {
                    do {
                        try await SupabaseService.shared.updateVehicle(updatedVehicle)
                        print("[Supabase] Vehicle \(updatedVehicle.id) status updated to .inService successfully.")
                    } catch {
                        print("[Supabase ERROR] Failed to update vehicle status for starting trip: \(error)")
                    }
                }
            }
        }
        
        if SupabaseConfig.isConfigured {
            Task {
                do {
                    try await SupabaseService.shared.addTrip(trip)
                    print("[Supabase] Trip \(trip.id) started successfully.")
                } catch {
                    print("[Supabase ERROR] Failed to add started trip: \(error)")
                }
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
        
        // Update vehicle status to Transit (In Service)
        let vehicleID = trips[index].vehicleID
        if let idx = vehicles.firstIndex(where: { $0.id == vehicleID }) {
            vehicles[idx].status = .inService
            let updatedVehicle = vehicles[idx]
            if SupabaseConfig.isConfigured {
                Task {
                    do {
                        try await SupabaseService.shared.updateVehicle(updatedVehicle)
                        print("[Supabase] Vehicle \(updatedVehicle.id) status updated to .inService successfully (scheduled).")
                    } catch {
                        print("[Supabase ERROR] Failed to update vehicle status for scheduled trip start: \(error)")
                    }
                }
            }
        }
        
        if SupabaseConfig.isConfigured {
            let updated = trips[index]
            Task {
                do {
                    try await SupabaseService.shared.updateTrip(updated)
                    print("[Supabase] Scheduled trip \(id) started successfully.")
                } catch {
                    print("[Supabase ERROR] Failed to start scheduled trip: \(error)")
                }
            }
        }
    }

    func endTrip(_ trip: Trip) {
        guard let index = trips.firstIndex(where: { $0.id == trip.id }) else {
            print("[MockDataService ERROR] endTrip could not find trip with ID: \(trip.id) in local array. Performing fallback DB update.")
            
            // Update vehicle status to Active and unassign driver
            let vehicleID = trip.vehicleID
            if let idx = vehicles.firstIndex(where: { $0.id == vehicleID }) {
                vehicles[idx].status = .active
                vehicles[idx].assignedDriverID = nil
                vehicles[idx].odometer += Int(trip.distanceKM.rounded())
                let updatedVehicle = vehicles[idx]
                if SupabaseConfig.isConfigured {
                    Task {
                        do {
                            try await SupabaseService.shared.updateVehicle(updatedVehicle)
                            print("[Supabase] Vehicle \(updatedVehicle.id) status reverted to .active & unassigned (fallback).")
                        } catch {
                            print("[Supabase ERROR] Failed to revert vehicle status: \(error)")
                        }
                    }
                }
            }
            
            if let userIdx = users.firstIndex(where: { $0.id == trip.driverID }) {
                users[userIdx].assignedVehicleID = nil
                let updatedUser = users[userIdx]
                if SupabaseConfig.isConfigured {
                    Task {
                        do {
                            try await SupabaseService.shared.updateProfile(updatedUser)
                            print("[Supabase] Driver profile \(updatedUser.id) unassigned vehicle (fallback).")
                        } catch {
                            print("[Supabase ERROR] Failed to unassign profile vehicle (fallback): \(error)")
                        }
                    }
                }
            }
            
            if SupabaseConfig.isConfigured {
                var updated = trip
                updated.status = .completed
                updated.endDate = .now
                Task {
                    do {
                        try await SupabaseService.shared.updateTrip(updated)
                        print("[Supabase] Trip \(updated.id) ended successfully (fallback update).")
                    } catch {
                        print("[Supabase ERROR] Failed to end trip (fallback update): \(error)")
                    }
                }
            }
            return
        }
        
        trips[index].status = .completed
        trips[index].endDate = .now
        
        // Update vehicle status to Active and unassign driver
        let vehicleID = trip.vehicleID
        if let idx = vehicles.firstIndex(where: { $0.id == vehicleID }) {
            vehicles[idx].status = .active
            vehicles[idx].assignedDriverID = nil
            vehicles[idx].odometer += Int(trips[index].distanceKM.rounded())
            let updatedVehicle = vehicles[idx]
            if SupabaseConfig.isConfigured {
                Task {
                    do {
                        try await SupabaseService.shared.updateVehicle(updatedVehicle)
                        print("[Supabase] Vehicle \(updatedVehicle.id) status reverted to .active & unassigned.")
                    } catch {
                        print("[Supabase ERROR] Failed to revert vehicle status: \(error)")
                    }
                }
            }
        }
        
        if let userIdx = users.firstIndex(where: { $0.id == trip.driverID }) {
            users[userIdx].assignedVehicleID = nil
            let updatedUser = users[userIdx]
            if SupabaseConfig.isConfigured {
                Task {
                    do {
                        try await SupabaseService.shared.updateProfile(updatedUser)
                        print("[Supabase] Driver profile \(updatedUser.id) unassigned vehicle.")
                    } catch {
                        print("[Supabase ERROR] Failed to unassign profile vehicle: \(error)")
                    }
                }
            }
        }
        
        if SupabaseConfig.isConfigured {
            let updated = trips[index]
            Task {
                do {
                    try await SupabaseService.shared.updateTrip(updated)
                    print("[Supabase] Trip \(updated.id) ended successfully.")
                } catch {
                    print("[Supabase ERROR] Failed to end trip: \(error)")
                }
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
        distanceKM: Double,
        originLat: Double? = nil,
        originLng: Double? = nil,
        destinationLat: Double? = nil,
        destinationLng: Double? = nil
    ) async {
        guard startDate >= Date().addingTimeInterval(3600) else {
            addNotification(
                userID: nil,
                roleTarget: .fleetManager,
                title: "Trip Assignment Blocked",
                message: "Trips must be assigned at least 1 hour before the start time.",
                category: .warning
            )
            return
        }

        guard isDriver(driver, compatibleWith: vehicle) else {
            addNotification(
                userID: nil,
                roleTarget: .fleetManager,
                title: "Trip Assignment Blocked",
                message: "\(driver.name) does not have the required licence for \(vehicle.displayName) (\(vehicle.plateNumber)).",
                category: .warning
            )
            return
        }

        // 1. Assign vehicle to driver
        var updatedVehicle = vehicle
        updatedVehicle.assignedDriverID = driver.id
        updateVehicle(updatedVehicle)
        
        // 2. Create trip entry in trips
        var trip = Trip(
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
            notes: notes,
            originLat: originLat,
            originLng: originLng,
            destinationLat: destinationLat,
            destinationLng: destinationLng
        )
        trip = await tripWithRoutePlanAttached(trip)
        trips.insert(trip, at: 0)
        
        if SupabaseConfig.isConfigured {
            do {
                try await SupabaseService.shared.addTrip(trip)
                print("[Supabase] Assigned trip \(trip.id) inserted successfully.")
            } catch {
                print("[Supabase ERROR] Failed to insert assigned trip: \(error)")
            }
        }
        
        // 3. Create notification for assigned driver
        let routesNote = trip.routeDetails?.hasPrefix("route-plan:") == true
            ? " Open Trips to view the main route and alternate paths on the map."
            : ""
        let notificationMsg = "You have been assigned vehicle \(vehicle.plateNumber) for \(origin) to \(destination). Start: \(startDate.formatted(date: .abbreviated, time: .shortened)).\(routesNote)"
        addNotification(
            userID: driver.id,
            roleTarget: nil,
            title: "New Trip Assigned",
            message: notificationMsg,
            category: .info
        )
    }

    private func syncDriverAssignments(using vehicle: Vehicle) {
        // Update local users array to mirror the vehicle's driver assignment.
        // NOTE: We do NOT push these changes to Supabase profiles here because
        // the RLS policy only allows a user to update their own profile row.
        // assignedVehicleID on the profile is re-derived from vehicles on every
        // full sync, so local state stays consistent without needing a profile write.
        for index in users.indices where users[index].role == .driver {
            if users[index].id == vehicle.assignedDriverID {
                users[index].assignedVehicleID = vehicle.id
            } else if users[index].assignedVehicleID == vehicle.id {
                users[index].assignedVehicleID = nil
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
