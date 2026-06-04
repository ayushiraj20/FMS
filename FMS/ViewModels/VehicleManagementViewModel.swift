//import Foundation
//import SwiftUI
//import UIKit
//import Observation
//
//@Observable
//@MainActor
//final class VehicleManagementViewModel {
//    private let service: MockDataService
//    private let currentOrgID: UUID?
//    private let maintenanceThresholdDays = 10
//
//    // List State
//    var searchText = ""
//    var selectedStatusFilter: VehicleStatus? = nil
//    var selectedVehicle: Vehicle? = nil
//    var isPresentingForm = false
//
//    // Form Fields
//    var displayName = ""
//    var plateNumber = ""
//    var model = ""
//    var status: VehicleStatus = .active
//    var fuelLevel = 50.0
//    var odometer = ""
//    var assignedDriverID: UUID? = nil
//    var nextServiceDate = Date.now.addingTimeInterval(86400 * 10)
//    var utilization = ""
//    var fuelConsumption = ""
//    var vehicleType = "Truck"
//    var fuelType = "Diesel"
//    var manufacturer = ""
//    var vehicleYear = ""
//    var vinNumber = ""
//
//    // Detail/Document State
//    var activeVehicleID = UUID()
//    var isPresentingDocumentSheet = false
//    var documentNumbers: [DocumentType: String] = [:]
//    var documentExpiries: [DocumentType: Date] = [:]
//    var documentImages: [DocumentType: UIImage?] = [:]
//    var documentImageURLs: [DocumentType: String] = [:]
//    var documentOCRStatus: [DocumentType: String] = [:]
//    var documentResolvedTypes: [DocumentType: DocumentType] = [:]
//    var uploadingDocuments: Set<DocumentType> = []
//    var activeDocumentTypeForPhoto: DocumentType? = nil
//    var selectedFileURL: URL? = nil
//    var isPresentingFilePicker = false
//    var isPresentingImagePicker = false
//    
//    // Delete State
//    var vehicleToDelete: Vehicle? = nil
//    var isPresentingDeleteConfirmation = false
//
//    init(service: MockDataService, currentOrgID: UUID?) {
//        self.service = service
//        self.currentOrgID = currentOrgID
//    }
//
//    var vehicles: [Vehicle] {
//        service.vehicles
//    }
//
//    var filteredVehicles: [Vehicle] {
//        vehicles.filter { vehicle in
//            let driverName = user(for: vehicle.assignedDriverID)?.name ?? ""
//            let matchesSearch = searchText.isEmpty ||
//                vehicle.displayName.localizedCaseInsensitiveContains(searchText) ||
//                vehicle.plateNumber.localizedCaseInsensitiveContains(searchText) ||
//                vehicle.model.localizedCaseInsensitiveContains(searchText) ||
//                driverName.localizedCaseInsensitiveContains(searchText)
//            
//            let matchesFilter: Bool
//            if let filter = selectedStatusFilter {
//                matchesFilter = (vehicle.status == filter)
//            } else {
//                matchesFilter = true
//            }
//            
//            return matchesSearch && matchesFilter
//        }
//        .sorted(by: vehiclePrioritySort)
//    }
//
//    var allCount: Int {
//        vehicles.count
//    }
//
//    var activeCount: Int {
//        vehicles.filter { $0.status == .active }.count
//    }
//
//    var inTransitCount: Int {
//        vehicles.filter { $0.status == .inService }.count
//    }
//
//    var idleCount: Int {
//        vehicles.filter { $0.status == .idle }.count
//    }
//
//    var maintenanceCount: Int {
//        vehicles.filter { $0.status == .outOfService }.count
//    }
//
//    var assignedVehiclesCount: Int {
//        vehicles.filter { $0.assignedDriverID != nil }.count
//    }
//
//    var liveTrackingCount: Int {
//        vehicles.filter(isLiveTracked).count
//    }
//
//    var inactiveVehiclesCount: Int {
//        max(0, allCount - liveTrackingCount)
//    }
//
//    var attentionCount: Int {
//        vehicles.filter(needsAttention).count
//    }
//
//    var serviceDueSoonCount: Int {
//        vehicles.filter { isMaintenanceDueSoon($0) }.count
//    }
//
//    var averageFuelLevel: Int {
//        averageValue(for: \.fuelLevel)
//    }
//
//    var averageUtilization: Int {
//        averageValue(for: \.utilization)
//    }
//
//    var assignmentCoverage: Double {
//        ratio(assignedVehiclesCount, allCount)
//    }
//
//    var trackingCoverage: Double {
//        ratio(liveTrackingCount, allCount)
//    }
//
//    var readinessScore: Int {
//        Int(round((1 - ratio(maintenanceCount, allCount)) * 100))
//    }
//
//    var drivers: [User] {
//        service.users(for: .driver)
//    }
//
//    func user(for driverID: UUID?) -> User? {
//        service.user(for: driverID)
//    }
//
//    func vehicle(for vehicleID: UUID) -> Vehicle? {
//        service.vehicle(for: vehicleID)
//    }
//
//    func documents(for vehicleID: UUID) -> [VehicleDocument] {
//        service.documents(for: vehicleID)
//    }
//
//    func alerts(for vehicleID: UUID) -> [VehicleAlert] {
//        service.alerts(for: vehicleID)
//    }
//
//    func activeAlertCount(for vehicle: Vehicle) -> Int {
//        alerts(for: vehicle.id).count
//    }
//
//    func defects(for vehicleID: UUID) -> [DefectReport] {
//        service.defects.filter { $0.vehicleID == vehicleID }
//    }
//
//    func unresolvedDefectCount(for vehicle: Vehicle) -> Int {
//        defects(for: vehicle.id).filter { !$0.isResolved }.count
//    }
//
//    func driverName(for vehicle: Vehicle) -> String {
//        user(for: vehicle.assignedDriverID)?.name ?? "Unassigned"
//    }
//
//    func shortDriverName(for vehicle: Vehicle) -> String {
//        let name = driverName(for: vehicle)
//        return name.components(separatedBy: " ").first ?? name
//    }
//
//    /// Returns the active (in-progress) trip for the driver assigned to this vehicle, if any.
//    func activeTrip(for vehicle: Vehicle) -> Trip? {
//        guard let driverID = vehicle.assignedDriverID else { return nil }
//        return service.trips.first { $0.driverID == driverID && $0.status == .inProgress }
//    }
//
//    /// Human-readable route string from real trip data, or a status-based fallback.
//    func routeText(for vehicle: Vehicle) -> String {
//        if let trip = activeTrip(for: vehicle) {
//            return "\(trip.origin) → \(trip.destination)"
//        }
//        switch vehicle.status {
//        case .active, .inService: return "No active trip"
//        case .idle:               return "Awaiting dispatch"
//        case .outOfService:       return "In maintenance"
//        }
//    }
//
//    func isLiveTracked(_ vehicle: Vehicle) -> Bool {
//        vehicle.status == .active || vehicle.status == .inService
//    }
//
//    func maintenanceDaysRemaining(for vehicle: Vehicle) -> Int {
//        vehicle.maintenanceDaysRemaining
//    }
//
//    func maintenanceKilometersRemaining(for vehicle: Vehicle) -> Int {
//        vehicle.kilometersUntilNextService
//    }
//
//    func isMaintenanceDueSoon(_ vehicle: Vehicle) -> Bool {
//        vehicle.isMaintenanceDue ||
//        vehicle.maintenanceDaysRemaining <= maintenanceThresholdDays ||
//        vehicle.kilometersUntilNextService <= 1_000
//    }
//
//    func maintenanceServiceLabel(for vehicle: Vehicle) -> String {
//        if vehicle.isDistanceMaintenanceDue {
//            return "\(vehicle.distanceSinceLastService.formatted()) km due"
//        }
//
//        if vehicle.isTimeMaintenanceDue {
//            return "\(abs(vehicle.maintenanceDaysRemaining))d overdue"
//        }
//
//        let days = vehicle.maintenanceDaysRemaining
//        let kilometers = vehicle.kilometersUntilNextService
//        if kilometers <= 1_000 {
//            return "\(kilometers.formatted()) km left"
//        }
//        if days <= maintenanceThresholdDays {
//            return "\(days)d left"
//        }
//        return "\(kilometers.formatted()) km / \(days)d"
//    }
//
//    func maintenanceServiceTint(for vehicle: Vehicle) -> Color {
//        if vehicle.isMaintenanceDue {
//            return .red
//        }
//        if vehicle.maintenanceDaysRemaining <= maintenanceThresholdDays || vehicle.kilometersUntilNextService <= 1_000 {
//            return .orange
//        }
//        return .green
//    }
//
//    func needsAttention(_ vehicle: Vehicle) -> Bool {
//        vehicle.status == .outOfService ||
//        vehicle.fuelLevel <= 25 ||
//        activeAlertCount(for: vehicle) > 0 ||
//        unresolvedDefectCount(for: vehicle) > 0 ||
//        isMaintenanceDueSoon(vehicle)
//    }
//
//    func confirmDelete(_ vehicle: Vehicle) {
//        vehicleToDelete = vehicle
//        isPresentingDeleteConfirmation = true
//    }
//
//    func deleteConfirmed() {
//        if let vehicle = vehicleToDelete {
//            service.deleteVehicle(vehicle)
//        }
//        vehicleToDelete = nil
//        isPresentingDeleteConfirmation = false
//    }
//
//    func prepareForAdd() {
//        selectedVehicle = nil
//        activeVehicleID = UUID()
//        displayName = ""
//        plateNumber = ""
//        model = ""
//        status = .active
//        fuelLevel = 50.0
//        odometer = ""
//        assignedDriverID = nil
//        nextServiceDate = Calendar.current.date(byAdding: .month, value: Vehicle.maintenanceIntervalMonths, to: .now) ?? Date.now.addingTimeInterval(86400 * 180)
//        utilization = "0"
//        fuelConsumption = "0"
//        vehicleType = "Truck"
//        fuelType = "Diesel"
//        manufacturer = ""
//        vehicleYear = ""
//        vinNumber = ""
//        
//        // Reset all document fields
//        documentNumbers = [:]
//        documentExpiries = [:]
//        documentImageURLs = [:]
//        documentOCRStatus = [:]
//        documentResolvedTypes = [:]
//        uploadingDocuments = []
//        for type in DocumentType.allCases {
//            documentNumbers[type] = ""
//            documentExpiries[type] = Date.now.addingTimeInterval(86400 * 120)
//            documentImages[type] = nil
//            documentResolvedTypes[type] = type
//        }
//        
//        selectedFileURL = nil
//        isPresentingForm = true
//    }
//
//    func prepareForEdit(_ vehicle: Vehicle) {
//        selectedVehicle = vehicle
//        activeVehicleID = vehicle.id
//        displayName = vehicle.displayName
//        plateNumber = vehicle.plateNumber
//        model = vehicle.model
//        status = vehicle.status
//        fuelLevel = Double(vehicle.fuelLevel)
//        odometer = String(vehicle.odometer)
//        assignedDriverID = vehicle.assignedDriverID
//        nextServiceDate = vehicle.nextServiceDate
//        utilization = String(vehicle.utilization)
//        fuelConsumption = String(vehicle.fuelConsumption)
//        vehicleType = vehicle.vehicleType
//        fuelType = vehicle.fuelType
//        manufacturer = vehicle.manufacturer
//        vehicleYear = vehicle.vehicleYear
//        vinNumber = vehicle.vinNumber
//        
//        // Reset and populate document fields for editing
//        documentNumbers = [:]
//        documentExpiries = [:]
//        documentImages = [:]
//        documentImageURLs = [:]
//        documentOCRStatus = [:]
//        documentResolvedTypes = [:]
//        uploadingDocuments = []
//        
//        let existingDocs = service.documents(for: vehicle.id)
//        for doc in existingDocs {
//            documentNumbers[doc.type] = doc.documentNumber
//            documentExpiries[doc.type] = doc.expiryDate
//            documentImageURLs[doc.type] = doc.imageUrl
//        }
//        
//        for type in DocumentType.allCases {
//            if documentNumbers[type] == nil {
//                documentNumbers[type] = ""
//            }
//            if documentExpiries[type] == nil {
//                documentExpiries[type] = Date.now.addingTimeInterval(86400 * 120)
//            }
//            documentImages[type] = nil
//            documentResolvedTypes[type] = type
//        }
//        
//        selectedFileURL = nil
//        isPresentingForm = true
//    }
//
//    func saveVehicle() {
//        let cleanOdo = odometer.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
//        guard let orgID = currentOrgID, let odo = Int(cleanOdo) else { return }
//
//        let cleanFuel = fuelConsumption.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
//        let fuelCons = Double(cleanFuel) ?? 0.0
//
//        let cleanUtil = utilization.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
//        let util = Int(cleanUtil) ?? 0
//
//        let lastServiceDate = selectedVehicle?.lastServiceDate ?? Date.now
//        let nextServiceDate = Calendar.current.date(byAdding: .month, value: Vehicle.maintenanceIntervalMonths, to: lastServiceDate) ?? self.nextServiceDate
//
//        let vehicle = Vehicle(
//            id: activeVehicleID,
//            organizationID: orgID,
//            displayName: displayName,
//            plateNumber: plateNumber,
//            model: model,
//            status: status,
//            fuelLevel: Int(fuelLevel),
//            odometer: odo,
//            assignedDriverID: assignedDriverID,
//            nextServiceDate: nextServiceDate,
//            utilization: util,
//            fuelConsumption: fuelCons,
//            vehicleType: vehicleType,
//            fuelType: fuelType,
//            manufacturer: manufacturer,
//            vehicleYear: vehicleYear,
//            vinNumber: vinNumber,
//            serviceReferenceReading: selectedVehicle?.serviceReferenceReading ?? odo,
//            lastServiceDate: lastServiceDate
//        )
//
//        Task {
//            if selectedVehicle == nil {
//                await service.addVehicle(vehicle)
//            } else {
//                let previousDriverID = selectedVehicle?.assignedDriverID
//                service.updateVehicle(vehicle)
//
//                // If a new driver has been assigned, notify them personally using their UUID
//                if let newDriverID = assignedDriverID, newDriverID != previousDriverID {
//                    service.addNotification(
//                        userID: newDriverID,    // notifications.user_id = profiles.id of the driver
//                        roleTarget: nil,        // personal notification, not a role broadcast
//                        title: "Vehicle Assigned to You",
//                        message: "\(displayName) (\(plateNumber)) has been assigned to you.",
//                        category: .info
//                    )
//                }
//            }
//            
//            // Save all provided documents
//            for type in DocumentType.allCases {
//                if let number = documentNumbers[type], !number.trimmingCharacters(in: .whitespaces).isEmpty {
//                    await service.addDocument(
//                        vehicleID: vehicle.id,
//                        type: type,
//                        number: number,
//                        expiryDate: documentExpiries[type] ?? Date.now.addingTimeInterval(86400 * 120),
//                        imageUrl: documentImageURLs[type]
//                    )
//                }
//            }
//        }
//        
//        isPresentingForm = false
//    }
//
//    // Documents
//    func prepareForDocumentUpload(for vehicleID: UUID) {
//        activeVehicleID = vehicleID
//        documentNumbers = [:]
//        documentExpiries = [:]
//        documentImages = [:]
//        documentImageURLs = [:]
//        documentOCRStatus = [:]
//        documentResolvedTypes = [:]
//        uploadingDocuments = []
//        
//        let existingDocs = service.documents(for: vehicleID)
//        for doc in existingDocs {
//            documentNumbers[doc.type] = doc.documentNumber
//            documentExpiries[doc.type] = doc.expiryDate
//            documentImageURLs[doc.type] = doc.imageUrl
//        }
//        
//        for type in DocumentType.allCases {
//            if documentNumbers[type] == nil {
//                documentNumbers[type] = ""
//            }
//            if documentExpiries[type] == nil {
//                documentExpiries[type] = Date.now.addingTimeInterval(86400 * 120)
//            }
//            documentImages[type] = nil
//            documentResolvedTypes[type] = type
//        }
//        isPresentingDocumentSheet = true
//    }
//
//    func saveDocument(for vehicleID: UUID) {
//        let docsToSave = DocumentType.allCases.compactMap { type -> (DocumentType, String, Date, String?)? in
//            guard let number = documentNumbers[type], !number.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
//            return (type, number, documentExpiries[type] ?? Date.now.addingTimeInterval(86400 * 120), documentImageURLs[type])
//        }
//        
//        Task {
//            for (type, number, expiry, url) in docsToSave {
//                await service.addDocument(
//                    vehicleID: vehicleID,
//                    type: type,
//                    number: number,
//                    expiryDate: expiry,
//                    imageUrl: url
//                )
//            }
//        }
//        
//        isPresentingDocumentSheet = false
//    }
//
//    private func saveImageLocally(_ image: UIImage, vehicleID: UUID, type: DocumentType) -> URL? {
//        let fileManager = FileManager.default
//        guard let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
//        let dirURL = cachesDir.appendingPathComponent("vehicle-documents/\(vehicleID.uuidString)")
//        do {
//            try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)
//            let fileURL = dirURL.appendingPathComponent("\(type.rawValue).jpg")
//            if let data = image.jpegData(compressionQuality: 0.8) {
//                try data.write(to: fileURL)
//                print("[Local Storage] Saved image locally to: \(fileURL.path)")
//                return fileURL
//            }
//        } catch {
//            print("[Local Storage] Error saving image locally: \(error)")
//        }
//        return nil
//    }
//
//    func uploadImage(_ image: UIImage, for type: DocumentType) {
//        documentResolvedTypes[type] = type
//        documentImages[type] = image
//        documentOCRStatus[type] = "Reading document..."
//        
//        let localURL = saveImageLocally(image, vehicleID: activeVehicleID, type: type)
//
//        Task {
//            await applyOCR(from: image, sourceType: type)
//        }
//        
//        guard SupabaseConfig.isConfigured else {
//            if let localURL {
//                documentImageURLs[type] = localURL.absoluteString
//            }
//            if documentOCRStatus[type] == "Reading document..." {
//                documentOCRStatus[type] = nil
//            }
//            return
//        }
//        
//        uploadingDocuments.insert(type)
//        Task {
//            do {
//                if let data = image.jpegData(compressionQuality: 0.8) {
//                    let urlString = try await SupabaseService.shared.uploadDocumentImage(
//                        imageData: data,
//                        vehicleID: activeVehicleID,
//                        documentType: type.rawValue
//                    )
//                    await MainActor.run {
//                        // Always store the URL under the original type the user chose
//                        self.documentImageURLs[type] = urlString
//                        self.uploadingDocuments.remove(type)
//                    }
//                }
//            } catch {
//                print("Failed to upload: \(error)")
//                _ = await MainActor.run {
//                    self.uploadingDocuments.remove(type)
//                }
//            }
//        }
//    }
//
//    private func applyOCR(from image: UIImage, sourceType: DocumentType) async {
//        do {
//            let result = try await VehicleDocumentOCRService.extractDocumentData(from: image, expectedType: sourceType)
//            await MainActor.run {
//                // Keep the image in the user's chosen slot — do NOT reclassify/move images.
//                // OCR is only used to auto-fill the document number and expiry date.
//                self.documentResolvedTypes[sourceType] = sourceType
//
//                if !result.documentNumber.isEmpty {
//                    self.documentNumbers[sourceType] = result.documentNumber
//                }
//                if let expiryDate = result.expiryDate {
//                    self.documentExpiries[sourceType] = expiryDate
//                }
//
//                if result.hasUsefulData {
//                    var statusParts: [String] = []
//                    if !result.documentNumber.isEmpty {
//                        statusParts.append("Number filled")
//                    }
//                    if result.expiryDate != nil {
//                        statusParts.append("Expiry filled")
//                    }
//                    self.documentOCRStatus[sourceType] = statusParts.joined(separator: " • ")
//                } else {
//                    self.documentOCRStatus[sourceType] = "Could not auto-fill. Enter manually."
//                }
//            }
//        } catch {
//            await MainActor.run {
//                self.documentOCRStatus[sourceType] = "Could not auto-fill. Enter manually."
//            }
//        }
//    }
//
//    private func vehiclePrioritySort(lhs: Vehicle, rhs: Vehicle) -> Bool {
//        let lhsAttention = needsAttention(lhs)
//        let rhsAttention = needsAttention(rhs)
//
//        if lhsAttention != rhsAttention {
//            return lhsAttention && !rhsAttention
//        }
//
//        let lhsLive = isLiveTracked(lhs)
//        let rhsLive = isLiveTracked(rhs)
//
//        if lhsLive != rhsLive {
//            return lhsLive && !rhsLive
//        }
//
//        return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
//    }
//
//    private func averageValue(for keyPath: KeyPath<Vehicle, Int>) -> Int {
//        guard !vehicles.isEmpty else { return 0 }
//        let total = vehicles.reduce(0) { $0 + $1[keyPath: keyPath] }
//        return Int(round(Double(total) / Double(vehicles.count)))
//    }
//
//    private func ratio(_ numerator: Int, _ denominator: Int) -> Double {
//        guard denominator > 0 else { return 0 }
//        return Double(numerator) / Double(denominator)
//    }
//
//    func refresh() async {
//        await service.syncWithDatabase()
//    }
//}




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
    var utilization = ""
    var fuelConsumption = ""
    var vehicleType = "Truck"
    var fuelType = "Diesel"
    var manufacturer = ""
    var vehicleYear = ""
    var vinNumber = ""

    // Detail/Document State
    var activeVehicleID = UUID()
    var isPresentingDocumentSheet = false
    var documentNumbers: [DocumentType: String] = [:]
    var documentExpiries: [DocumentType: Date] = [:]
    var documentImages: [DocumentType: UIImage?] = [:]
    var documentImageURLs: [DocumentType: String] = [:]
    var documentOCRStatus: [DocumentType: String] = [:]
    var documentResolvedTypes: [DocumentType: DocumentType] = [:]
    var uploadingDocuments: Set<DocumentType> = []
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
        vehicles.filter { isMaintenanceDueSoon($0) }.count
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

    func driverName(for vehicle: Vehicle) -> String {
        user(for: vehicle.assignedDriverID)?.name ?? "Unassigned"
    }

    func shortDriverName(for vehicle: Vehicle) -> String {
        let name = driverName(for: vehicle)
        return name.components(separatedBy: " ").first ?? name
    }

    /// Returns the active (in-progress) trip for the driver assigned to this vehicle, if any.
    func activeTrip(for vehicle: Vehicle) -> Trip? {
        guard let driverID = vehicle.assignedDriverID else { return nil }
        return service.trips.first { $0.driverID == driverID && $0.status == .inProgress }
    }

    /// Human-readable route string from real trip data, or a status-based fallback.
    func routeText(for vehicle: Vehicle) -> String {
        if let trip = activeTrip(for: vehicle) {
            return "\(trip.origin) → \(trip.destination)"
        }
        switch vehicle.status {
        case .active, .inService: return "No active trip"
        case .idle:               return "Awaiting dispatch"
        case .outOfService:       return "In maintenance"
        }
    }

    func isLiveTracked(_ vehicle: Vehicle) -> Bool {
        vehicle.status == .active || vehicle.status == .inService
    }

    func maintenanceDaysRemaining(for vehicle: Vehicle) -> Int {
        vehicle.maintenanceDaysRemaining
    }

    func maintenanceKilometersRemaining(for vehicle: Vehicle) -> Int {
        vehicle.kilometersUntilNextService
    }

    func isMaintenanceDueSoon(_ vehicle: Vehicle) -> Bool {
        vehicle.isMaintenanceDue ||
        vehicle.maintenanceDaysRemaining <= maintenanceThresholdDays ||
        vehicle.kilometersUntilNextService <= 1_000
    }

    func maintenanceServiceLabel(for vehicle: Vehicle) -> String {
        if vehicle.isDistanceMaintenanceDue {
            return "\(vehicle.distanceSinceLastService.formatted()) km due"
        }

        if vehicle.isTimeMaintenanceDue {
            return "\(abs(vehicle.maintenanceDaysRemaining))d overdue"
        }

        let days = vehicle.maintenanceDaysRemaining
        let kilometers = vehicle.kilometersUntilNextService
        if kilometers <= 1_000 {
            return "\(kilometers.formatted()) km left"
        }
        if days <= maintenanceThresholdDays {
            return "\(days)d left"
        }
        return "\(kilometers.formatted()) km / \(days)d"
    }

    func maintenanceServiceTint(for vehicle: Vehicle) -> Color {
        if vehicle.isMaintenanceDue {
            return .red
        }
        if vehicle.maintenanceDaysRemaining <= maintenanceThresholdDays || vehicle.kilometersUntilNextService <= 1_000 {
            return .orange
        }
        return .green
    }

    func needsAttention(_ vehicle: Vehicle) -> Bool {
        vehicle.status == .outOfService ||
        vehicle.fuelLevel <= 25 ||
        activeAlertCount(for: vehicle) > 0 ||
        unresolvedDefectCount(for: vehicle) > 0 ||
        isMaintenanceDueSoon(vehicle)
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
        activeVehicleID = UUID()
        displayName = ""
        plateNumber = ""
        model = ""
        status = .active
        fuelLevel = 50.0
        odometer = ""
        assignedDriverID = nil
        nextServiceDate = Calendar.current.date(byAdding: .month, value: Vehicle.maintenanceIntervalMonths, to: .now) ?? Date.now.addingTimeInterval(86400 * 180)
        utilization = "0"
        fuelConsumption = "0"
        vehicleType = "Truck"
        fuelType = "Diesel"
        manufacturer = ""
        vehicleYear = ""
        vinNumber = ""
        
        // Reset all document fields
        documentNumbers = [:]
        documentExpiries = [:]
        documentImageURLs = [:]
        documentOCRStatus = [:]
        documentResolvedTypes = [:]
        uploadingDocuments = []
        for type in DocumentType.allCases {
            documentNumbers[type] = ""
            documentExpiries[type] = Date.now.addingTimeInterval(86400 * 120)
            documentImages[type] = nil
            documentResolvedTypes[type] = type
        }
        
        selectedFileURL = nil
        isPresentingForm = true
    }

    func prepareForEdit(_ vehicle: Vehicle) {
        selectedVehicle = vehicle
        activeVehicleID = vehicle.id
        displayName = vehicle.displayName
        plateNumber = vehicle.plateNumber
        model = vehicle.model
        status = vehicle.status
        fuelLevel = Double(vehicle.fuelLevel)
        odometer = String(vehicle.odometer)
        assignedDriverID = vehicle.assignedDriverID
        nextServiceDate = vehicle.nextServiceDate
        utilization = String(vehicle.utilization)
        fuelConsumption = String(vehicle.fuelConsumption)
        vehicleType = vehicle.vehicleType
        fuelType = vehicle.fuelType
        manufacturer = vehicle.manufacturer
        vehicleYear = vehicle.vehicleYear
        vinNumber = vehicle.vinNumber
        
        // Reset and populate document fields for editing
        documentNumbers = [:]
        documentExpiries = [:]
        documentImages = [:]
        documentImageURLs = [:]
        documentOCRStatus = [:]
        documentResolvedTypes = [:]
        uploadingDocuments = []
        
        let existingDocs = service.documents(for: vehicle.id)
        for doc in existingDocs {
            documentNumbers[doc.type] = doc.documentNumber
            documentExpiries[doc.type] = doc.expiryDate
            documentImageURLs[doc.type] = doc.imageUrl
        }
        
        for type in DocumentType.allCases {
            if documentNumbers[type] == nil {
                documentNumbers[type] = ""
            }
            if documentExpiries[type] == nil {
                documentExpiries[type] = Date.now.addingTimeInterval(86400 * 120)
            }
            documentImages[type] = nil
            documentResolvedTypes[type] = type
        }
        
        selectedFileURL = nil
        isPresentingForm = true
    }

    func saveVehicle() {
        let cleanOdo = odometer.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        guard let orgID = currentOrgID, let odo = Int(cleanOdo) else { return }

        let cleanFuel = fuelConsumption.replacingOccurrences(of: "[^0-9.]", with: "", options: .regularExpression)
        let fuelCons = Double(cleanFuel) ?? 0.0

        let cleanUtil = utilization.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        let util = Int(cleanUtil) ?? 0

        let lastServiceDate = selectedVehicle?.lastServiceDate ?? Date.now
        let nextServiceDate = Calendar.current.date(byAdding: .month, value: Vehicle.maintenanceIntervalMonths, to: lastServiceDate) ?? self.nextServiceDate

        let vehicle = Vehicle(
            id: activeVehicleID,
            organizationID: orgID,
            displayName: displayName,
            plateNumber: plateNumber,
            model: model,
            status: status,
            fuelLevel: Int(fuelLevel),
            odometer: odo,
            assignedDriverID: assignedDriverID,
            nextServiceDate: nextServiceDate,
            utilization: util,
            fuelConsumption: fuelCons,
            vehicleType: vehicleType,
            fuelType: fuelType,
            manufacturer: manufacturer,
            vehicleYear: vehicleYear,
            vinNumber: vinNumber,
            serviceReferenceReading: selectedVehicle?.serviceReferenceReading ?? odo,
            lastServiceDate: lastServiceDate
        )

        Task {
            if selectedVehicle == nil {
                await service.addVehicle(vehicle)
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
            
            // Wait for any in-progress Supabase image uploads to complete
            // before saving documents, so imageUrl is not nil.
            while !uploadingDocuments.isEmpty {
                try? await Task.sleep(for: .milliseconds(100))
            }
            
            // Save all provided documents
            for type in DocumentType.allCases {
                if let number = documentNumbers[type], !number.trimmingCharacters(in: .whitespaces).isEmpty {
                    await service.addDocument(
                        vehicleID: vehicle.id,
                        type: type,
                        number: number,
                        expiryDate: documentExpiries[type] ?? Date.now.addingTimeInterval(86400 * 120),
                        imageUrl: documentImageURLs[type]
                    )
                }
            }
        }
        
        isPresentingForm = false
    }

    // Documents
    func prepareForDocumentUpload(for vehicleID: UUID) {
        activeVehicleID = vehicleID
        documentNumbers = [:]
        documentExpiries = [:]
        documentImages = [:]
        documentImageURLs = [:]
        documentOCRStatus = [:]
        documentResolvedTypes = [:]
        uploadingDocuments = []
        
        let existingDocs = service.documents(for: vehicleID)
        for doc in existingDocs {
            documentNumbers[doc.type] = doc.documentNumber
            documentExpiries[doc.type] = doc.expiryDate
            documentImageURLs[doc.type] = doc.imageUrl
        }
        
        for type in DocumentType.allCases {
            if documentNumbers[type] == nil {
                documentNumbers[type] = ""
            }
            if documentExpiries[type] == nil {
                documentExpiries[type] = Date.now.addingTimeInterval(86400 * 120)
            }
            documentImages[type] = nil
            documentResolvedTypes[type] = type
        }
        isPresentingDocumentSheet = true
    }

    func saveDocument(for vehicleID: UUID) {
        let docsToSave = DocumentType.allCases.compactMap { type -> (DocumentType, String, Date)? in
            guard let number = documentNumbers[type], !number.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
            return (type, number, documentExpiries[type] ?? Date.now.addingTimeInterval(86400 * 120))
        }
        
        Task {
            // Wait for any in-progress Supabase image uploads to complete
            // before saving documents, so imageUrl is not nil.
            while !uploadingDocuments.isEmpty {
                try? await Task.sleep(for: .milliseconds(100))
            }
            
            for (type, number, expiry) in docsToSave {
                await service.addDocument(
                    vehicleID: vehicleID,
                    type: type,
                    number: number,
                    expiryDate: expiry,
                    imageUrl: documentImageURLs[type]
                )
            }
        }
        
        isPresentingDocumentSheet = false
    }

    private func saveImageLocally(_ image: UIImage, vehicleID: UUID, type: DocumentType) -> URL? {
        let fileManager = FileManager.default
        guard let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        let dirURL = cachesDir.appendingPathComponent("vehicle-documents/\(vehicleID.uuidString)")
        do {
            try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)
            let fileURL = dirURL.appendingPathComponent("\(type.rawValue).jpg")
            if let data = image.jpegData(compressionQuality: 0.8) {
                try data.write(to: fileURL)
                print("[Local Storage] Saved image locally to: \(fileURL.path)")
                return fileURL
            }
        } catch {
            print("[Local Storage] Error saving image locally: \(error)")
        }
        return nil
    }

    func uploadImage(_ image: UIImage, for type: DocumentType) {
        documentResolvedTypes[type] = type
        documentImages[type] = image
        documentOCRStatus[type] = "Reading document..."
        
        let localURL = saveImageLocally(image, vehicleID: activeVehicleID, type: type)

        Task {
            await applyOCR(from: image, sourceType: type)
        }
        
        guard SupabaseConfig.isConfigured else {
            if let localURL {
                documentImageURLs[type] = localURL.absoluteString
            }
            if documentOCRStatus[type] == "Reading document..." {
                documentOCRStatus[type] = nil
            }
            return
        }
        
        uploadingDocuments.insert(type)
        Task {
            do {
                if let data = image.jpegData(compressionQuality: 0.8) {
                    let urlString = try await SupabaseService.shared.uploadDocumentImage(
                        imageData: data,
                        vehicleID: activeVehicleID,
                        documentType: type.rawValue
                    )
                    await MainActor.run {
                        // Always store the URL under the original type the user chose
                        self.documentImageURLs[type] = urlString
                        self.uploadingDocuments.remove(type)
                    }
                }
            } catch {
                print("Failed to upload to Supabase: \(error)")
                await MainActor.run {
                    // Fall back to the locally cached file so the photo is not lost
                    if self.documentImageURLs[type] == nil, let localURL = localURL {
                        self.documentImageURLs[type] = localURL.absoluteString
                    }
                    self.uploadingDocuments.remove(type)
                }
            }
        }
    }

    private func applyOCR(from image: UIImage, sourceType: DocumentType) async {
        do {
            let result = try await VehicleDocumentOCRService.extractDocumentData(from: image, expectedType: sourceType)
            await MainActor.run {
                // Keep the image in the user's chosen slot — do NOT reclassify/move images.
                // OCR is only used to auto-fill the document number and expiry date.
                self.documentResolvedTypes[sourceType] = sourceType

                if !result.documentNumber.isEmpty {
                    self.documentNumbers[sourceType] = result.documentNumber
                }
                if let expiryDate = result.expiryDate {
                    self.documentExpiries[sourceType] = expiryDate
                }

                if result.hasUsefulData {
                    var statusParts: [String] = []
                    if !result.documentNumber.isEmpty {
                        statusParts.append("Number filled")
                    }
                    if result.expiryDate != nil {
                        statusParts.append("Expiry filled")
                    }
                    self.documentOCRStatus[sourceType] = statusParts.joined(separator: " • ")
                } else {
                    self.documentOCRStatus[sourceType] = "Could not auto-fill. Enter manually."
                }
            }
        } catch {
            await MainActor.run {
                self.documentOCRStatus[sourceType] = "Could not auto-fill. Enter manually."
            }
        }
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

    func refresh() async {
        await service.syncWithDatabase()
    }
}
