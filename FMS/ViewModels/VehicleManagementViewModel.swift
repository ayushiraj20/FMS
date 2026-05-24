import Foundation
import SwiftUI

import Observation

@Observable
@MainActor
final class VehicleManagementViewModel {
    private let service: MockDataService
    private let currentOrgID: UUID?

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
    var docType: DocumentType = .rc
    var docNumber = ""
    var docExpiryDate = Date.now.addingTimeInterval(86400 * 120)

    init(service: MockDataService, currentOrgID: UUID?) {
        self.service = service
        self.currentOrgID = currentOrgID
    }

    var filteredVehicles: [Vehicle] {
        service.vehicles.filter { vehicle in
            let matchesSearch = searchText.isEmpty ||
                vehicle.displayName.localizedCaseInsensitiveContains(searchText) ||
                vehicle.plateNumber.localizedCaseInsensitiveContains(searchText)
            
            let matchesFilter: Bool
            if let filter = selectedStatusFilter {
                if filter == .idle {
                    matchesFilter = (vehicle.status == .idle || vehicle.status == .outOfService)
                } else {
                    matchesFilter = (vehicle.status == filter)
                }
            } else {
                matchesFilter = true
            }
            
            return matchesSearch && matchesFilter
        }
    }

    var allCount: Int {
        service.vehicles.count
    }

    var activeCount: Int {
        service.vehicles.filter { $0.status == .active }.count
    }

    var inTransitCount: Int {
        service.vehicles.filter { $0.status == .inService }.count
    }

    var idleCount: Int {
        service.vehicles.filter { $0.status == .idle || $0.status == .outOfService }.count
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

    func defects(for vehicleID: UUID) -> [DefectReport] {
        service.defects.filter { $0.vehicleID == vehicleID }
    }

    func deleteVehicle(_ vehicle: Vehicle) {
        service.deleteVehicle(vehicle)
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
        isPresentingForm = false

    }

    // Documents
    func prepareForDocumentUpload() {
        docType = .rc
        docNumber = ""
        docExpiryDate = Date.now.addingTimeInterval(86400 * 120)
        isPresentingDocumentSheet = true
    }

    func saveDocument(for vehicleID: UUID) {
        service.addDocument(
            vehicleID: vehicleID,
            type: docType,
            number: docNumber,
            expiryDate: docExpiryDate
        )
        isPresentingDocumentSheet = false
    }
}
