import Foundation
import SwiftUI
import UIKit
import Observation

@Observable
@MainActor
final class VehicleManagementViewModel {
    private let service: MockDataService
    private let currentOrgID: UUID?
    private let maintenanceThresholdDays = 10

    // List State
    var searchText = ""
    var selectedStatusFilter: VehicleStatus? = nil
    var selectedVehicle: Vehicle? = nil
    var isPresentingForm = false

    // Form Fields
    var displayName = ""
    var plateNumber = ""
    var model = ""
    var status: VehicleStatus = .active
    var fuelLevel = 50.0
    var odometer = ""
    var assignedDriverID: UUID? = nil
    var nextServiceDate = Date.now.addingTimeInterval(86400 * 10)
    var utilization = 70.0

    // Detail/Document State
    var isPresentingDocumentSheet = false
    var documentNumbers: [DocumentType: String] = [:]
    var documentExpiries: [DocumentType: Date] = [:]
    var documentImages: [DocumentType: UIImage?] = [:]
    var activeDocumentTypeForPhoto: DocumentType? = nil
    var selectedFileURL: URL? = nil
    var isPresentingFilePicker = false
    var isPresentingImagePicker = false
    
    // Delete State
    var vehicleToDelete: Vehicle? = nil
    var isPresentingDeleteConfirmation = false

    init(service: MockDataService, currentOrgID: UUID?) {
        self.service = service
        self.currentOrgID = currentOrgID
    }

    var vehicles: [Vehicle] {
        service.vehicles
    }

    var filteredVehicles: [Vehicle] {
        vehicles.filter { vehicle in
            let driverName = user(for: vehicle.assignedDriverID)?.name ?? ""
            let matchesSearch = searchText.isEmpty ||
                vehicle.displayName.localizedCaseInsensitiveContains(searchText) ||
                vehicle.plateNumber.localizedCaseInsensitiveContains(searchText) ||
                vehicle.model.localizedCaseInsensitiveContains(searchText) ||
                driverName.localizedCaseInsensitiveContains(searchText)
            
            let matchesFilter: Bool
            if let filter = selectedStatusFilter {
                matchesFilter = (vehicle.status == filter)
            } else {
                matchesFilter = true
            }
            
            return matchesSearch && matchesFilter
        }
        .sorted(by: vehiclePrioritySort)
    }

    var allCount: Int {
        vehicles.count
    }

    var activeCount: Int {
        vehicles.filter { $0.status == .active }.count
    }

    var inTransitCount: Int {
        vehicles.filter { $0.status == .inService }.count
    }

    var idleCount: Int {
        vehicles.filter { $0.status == .idle }.count
    }

    var maintenanceCount: Int {
        vehicles.filter { $0.status == .outOfService }.count
    }

    var assignedVehiclesCount: Int {
        vehicles.filter { $0.assignedDriverID != nil }.count
    }

    var liveTrackingCount: Int {
        vehicles.filter(isLiveTracked).count
    }

    var inactiveVehiclesCount: Int {
        max(0, allCount - liveTrackingCount)
    }

    var attentionCount: Int {
        vehicles.filter(needsAttention).count
    }

    var serviceDueSoonCount: Int {
        vehicles.filter { maintenanceDaysRemaining(for: $0) <= maintenanceThresholdDays }.count
    }

    var averageFuelLevel: Int {
        averageValue(for: \.fuelLevel)
    }

    var averageUtilization: Int {
        averageValue(for: \.utilization)
    }

    var assignmentCoverage: Double {
        ratio(assignedVehiclesCount, allCount)
    }

    var trackingCoverage: Double {
        ratio(liveTrackingCount, allCount)
    }

    var readinessScore: Int {
        Int(round((1 - ratio(maintenanceCount, allCount)) * 100))
    }

    var drivers: [User] {
        service.users(for: .driver)
    }

    func user(for driverID: UUID?) -> User? {
        service.user(for: driverID)
    }

    func vehicle(for vehicleID: UUID) -> Vehicle? {
        service.vehicle(for: vehicleID)
    }

    func documents(for vehicleID: UUID) -> [VehicleDocument] {
        service.documents(for: vehicleID)
    }

    func alerts(for vehicleID: UUID) -> [VehicleAlert] {
        service.alerts(for: vehicleID)
    }

    func activeAlertCount(for vehicle: Vehicle) -> Int {
        alerts(for: vehicle.id).count
    }

    func defects(for vehicleID: UUID) -> [DefectReport] {
        service.defects.filter { $0.vehicleID == vehicleID }
    }

    func unresolvedDefectCount(for vehicle: Vehicle) -> Int {
        defects(for: vehicle.id).filter { !$0.isResolved }.count
    }
    
    func latestTrip(for vehicle: Vehicle) -> Trip? {
        service.trips
            .filter { $0.vehicleID == vehicle.id }
            .sorted { $0.startDate > $1.startDate }
            .first
    }

    func driverName(for vehicle: Vehicle) -> String {
        user(for: vehicle.assignedDriverID)?.name ?? "Unassigned"
    }

    func shortDriverName(for vehicle: Vehicle) -> String {
        let name = driverName(for: vehicle)
        return name.components(separatedBy: " ").first ?? name
    }

    func isLiveTracked(_ vehicle: Vehicle) -> Bool {
        vehicle.status == .active || vehicle.status == .inService
    }

    func maintenanceDaysRemaining(for vehicle: Vehicle) -> Int {
        Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: .now),
            to: Calendar.current.startOfDay(for: vehicle.nextServiceDate)
        ).day ?? 0
    }

    func needsAttention(_ vehicle: Vehicle) -> Bool {
        vehicle.status == .outOfService ||
        vehicle.fuelLevel <= 25 ||
        activeAlertCount(for: vehicle) > 0 ||
        unresolvedDefectCount(for: vehicle) > 0 ||
        maintenanceDaysRemaining(for: vehicle) <= 7
    }

    func confirmDelete(_ vehicle: Vehicle) {
        vehicleToDelete = vehicle
        isPresentingDeleteConfirmation = true
    }

    func deleteConfirmed() {
        if let vehicle = vehicleToDelete {
            service.deleteVehicle(vehicle)
        }
        vehicleToDelete = nil
        isPresentingDeleteConfirmation = false
    }

    func prepareForAdd() {
        selectedVehicle = nil
        displayName = ""
        plateNumber = ""
        model = ""
        status = .active
        fuelLevel = 50.0
        odometer = ""
        assignedDriverID = nil
        nextServiceDate = Date.now.addingTimeInterval(86400 * 10)
        utilization = 70.0
        
        // Reset all document fields
        documentNumbers = [:]
        documentExpiries = [:]
        for type in DocumentType.allCases {
            documentNumbers[type] = ""
            documentExpiries[type] = Date.now.addingTimeInterval(86400 * 120)
            documentImages[type] = nil
        }
        
        selectedFileURL = nil
        isPresentingForm = true
    }

    func prepareForEdit(_ vehicle: Vehicle) {
        selectedVehicle = vehicle
        displayName = vehicle.displayName
        plateNumber = vehicle.plateNumber
        model = vehicle.model
        status = vehicle.status
        fuelLevel = Double(vehicle.fuelLevel)
        odometer = String(vehicle.odometer)
        assignedDriverID = vehicle.assignedDriverID
        nextServiceDate = vehicle.nextServiceDate
        utilization = Double(vehicle.utilization)
        
        // Reset all document fields for editing
        documentNumbers = [:]
        documentExpiries = [:]
        for type in DocumentType.allCases {
            documentNumbers[type] = ""
            documentExpiries[type] = Date.now.addingTimeInterval(86400 * 120)
            documentImages[type] = nil
        }
        
        selectedFileURL = nil
        isPresentingForm = true
    }

    func saveVehicle() {
        guard let orgID = currentOrgID, let odo = Int(odometer) else { return }

        let vehicle = Vehicle(
            id: selectedVehicle?.id ?? UUID(),
            organizationID: orgID,
            displayName: displayName,
            plateNumber: plateNumber,
            model: model,
            status: status,
            fuelLevel: Int(fuelLevel),
            odometer: odo,
            assignedDriverID: assignedDriverID,
            nextServiceDate: nextServiceDate,
            utilization: Int(utilization)
        )

        if selectedVehicle == nil {
            service.addVehicle(vehicle)
        } else {
            let previousDriverID = selectedVehicle?.assignedDriverID
            service.updateVehicle(vehicle)

            // If a new driver has been assigned, notify them personally using their UUID
            if let newDriverID = assignedDriverID, newDriverID != previousDriverID {
                service.addNotification(
                    userID: newDriverID,    // notifications.user_id = profiles.id of the driver
                    roleTarget: nil,        // personal notification, not a role broadcast
                    title: "Vehicle Assigned to You",
                    message: "\(displayName) (\(plateNumber)) has been assigned to you.",
                    category: .info
                )
            }
        }
        
        // Save all provided documents
        for type in DocumentType.allCases {
            if let number = documentNumbers[type], !number.trimmingCharacters(in: .whitespaces).isEmpty {
                service.addDocument(
                    vehicleID: vehicle.id,
                    type: type,
                    number: number,
                    expiryDate: documentExpiries[type] ?? Date.now.addingTimeInterval(86400 * 120)
                )
            }
        }
        
        isPresentingForm = false

    }

    // Documents
    func prepareForDocumentUpload() {
        documentNumbers = [:]
        documentExpiries = [:]
        for type in DocumentType.allCases {
            documentNumbers[type] = ""
            documentExpiries[type] = Date.now.addingTimeInterval(86400 * 120)
            documentImages[type] = nil
        }
        isPresentingDocumentSheet = true
    }

    func saveDocument(for vehicleID: UUID) {
        for type in DocumentType.allCases {
            if let number = documentNumbers[type], !number.trimmingCharacters(in: .whitespaces).isEmpty {
                service.addDocument(
                    vehicleID: vehicleID,
                    type: type,
                    number: number,
                    expiryDate: documentExpiries[type] ?? Date.now.addingTimeInterval(86400 * 120)
                )
            }
        }
        isPresentingDocumentSheet = false
    }

    private func vehiclePrioritySort(lhs: Vehicle, rhs: Vehicle) -> Bool {
        let lhsAttention = needsAttention(lhs)
        let rhsAttention = needsAttention(rhs)

        if lhsAttention != rhsAttention {
            return lhsAttention && !rhsAttention
        }

        let lhsLive = isLiveTracked(lhs)
        let rhsLive = isLiveTracked(rhs)

        if lhsLive != rhsLive {
            return lhsLive && !rhsLive
        }

        return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
    }

    private func averageValue(for keyPath: KeyPath<Vehicle, Int>) -> Int {
        guard !vehicles.isEmpty else { return 0 }
        let total = vehicles.reduce(0) { $0 + $1[keyPath: keyPath] }
        return Int(round(Double(total) / Double(vehicles.count)))
    }

    private func ratio(_ numerator: Int, _ denominator: Int) -> Double {
        guard denominator > 0 else { return 0 }
        return Double(numerator) / Double(denominator)
    }
}
