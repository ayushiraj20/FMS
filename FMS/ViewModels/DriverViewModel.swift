import Foundation
import SwiftUI
import CoreLocation
import Combine

@MainActor
final class DriverViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var selectedTab = 0
    @Published var showSOSSheet = false
    @Published var showProfileSheet = false
    @Published var showDefectSheet = false
    @Published var showChatSheet = false
    @Published var showFuelReceiptSheet = false
    @Published var showBreakLogSheet = false
    @Published var showInspection = false
    @Published var showDutyToggleAlert = false
    @Published var showAlertDetail: VehicleAlert?

    // SOS
    @Published var sosCountdown: Int = 10
    @Published var sosTriggered = false
    @Published var sosConfirmed = false
    private var sosTimer: Timer?

    // Inspection
    @Published var inspectionItems: [DriverInspectionItem] = DriverViewModel.defaultInspectionItems()
    @Published var inspectionType: InspectionType = .preTrip
    @Published var inspectionSubmitted = false
    @Published var showInspectionCriticalAlert = false

    // Toast
    @Published var toastMessage: String?
    @Published var showToast = false

    // Trip map
    @Published var currentSpeed: Double = 72.0
    @Published var speedLimit: Double = 80.0

    func load() async {
        guard isLoading else { return }
        try? await Task.sleep(for: .seconds(0.35))
        isLoading = false
    }

    // MARK: - SOS

    func startSOSCountdown(service: MockDataService, user: User?) {
        sosCountdown = 10
        sosTriggered = false
        sosConfirmed = false
        showSOSSheet = true

        sosTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else { timer.invalidate(); return }
                if self.sosCountdown > 1 {
                    self.sosCountdown -= 1
                } else {
                    timer.invalidate()
                    self.triggerSOS(service: service, user: user)
                }
            }
        }
    }

    func cancelSOS() {
        sosTimer?.invalidate()
        sosTimer = nil
        showSOSSheet = false
        sosTriggered = false
        sosConfirmed = false
    }

    func triggerSOS(service: MockDataService, user: User?) {
        sosTimer?.invalidate()
        sosTimer = nil
        sosTriggered = true

        guard let user, let vehicleID = user.assignedVehicleID else {
            sosConfirmed = true
            return
        }

        // Use a default location (Mumbai) for demo
        service.triggerSOS(
            driverID: user.id,
            vehicleID: vehicleID,
            latitude: 19.0760,
            longitude: 72.8777
        )

        // Show confirmed after brief delay
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            sosConfirmed = true
        }
    }

    // MARK: - Inspection

    static func defaultInspectionItems() -> [DriverInspectionItem] {
        [
            DriverInspectionItem(title: "Tires", iconName: "circle.circle.fill", isCritical: true),
            DriverInspectionItem(title: "Brakes", iconName: "brakesignal", isCritical: true),
            DriverInspectionItem(title: "Lights", iconName: "headlight.high.beam.fill"),
            DriverInspectionItem(title: "Mirrors", iconName: "rectangle.on.rectangle.angled"),
            DriverInspectionItem(title: "Horn", iconName: "speaker.wave.3.fill"),
            DriverInspectionItem(title: "Fluid Levels", iconName: "drop.fill"),
            DriverInspectionItem(title: "Body Damage", iconName: "car.side.fill"),
            DriverInspectionItem(title: "Seat Belts", iconName: "figure.seated.seatbelt"),
            DriverInspectionItem(title: "Wipers", iconName: "windshield.front.and.wiper"),
            DriverInspectionItem(title: "Engine Oil", iconName: "oilcan.fill"),
            DriverInspectionItem(title: "Fuel Level", iconName: "fuelpump.fill"),
            DriverInspectionItem(title: "Fire Extinguisher", iconName: "fire.extinguisher.fill")
        ]
    }

    var inspectionCheckedCount: Int {
        inspectionItems.filter { $0.status != .unchecked }.count
    }

    var inspectionProgress: Double {
        guard !inspectionItems.isEmpty else { return 0 }
        return Double(inspectionCheckedCount) / Double(inspectionItems.count)
    }

    var allItemsChecked: Bool {
        inspectionItems.allSatisfy { $0.status != .unchecked }
    }

    var hasCriticalFailures: Bool {
        inspectionItems.contains { $0.isCritical && $0.status == .failed }
    }

    func toggleInspectionItem(at index: Int) {
        switch inspectionItems[index].status {
        case .unchecked:
            inspectionItems[index].status = .passed
        case .passed:
            inspectionItems[index].status = .failed
        case .failed:
            inspectionItems[index].status = .unchecked
            inspectionItems[index].failureDescription = ""
        }
    }

    func submitInspection(service: MockDataService, user: User?) {
        guard let user, let vehicleID = user.assignedVehicleID else { return }

        if hasCriticalFailures {
            showInspectionCriticalAlert = true
        }

        let items = inspectionItems.map {
            InspectionItem(id: UUID(), title: $0.title, isChecked: $0.status != .failed)
        }

        let notes = inspectionItems
            .filter { $0.status == .failed }
            .map { "\($0.title): \($0.failureDescription)" }
            .joined(separator: ". ")

        service.addInspection(
            driverID: user.id,
            vehicleID: vehicleID,
            type: inspectionType,
            notes: notes.isEmpty ? "All items passed." : notes,
            items: items
        )

        inspectionSubmitted = true
        showToastMessage("Inspection submitted")
    }

    func resetInspection() {
        inspectionItems = DriverViewModel.defaultInspectionItems()
        inspectionSubmitted = false
        inspectionType = .preTrip
    }

    // MARK: - Toast

    func showToastMessage(_ message: String) {
        toastMessage = message
        showToast = true

        Task {
            try? await Task.sleep(for: .seconds(2.5))
            showToast = false
        }
    }

    // MARK: - Helpers

    func driverFirstName(_ user: User?) -> String {
        user?.name.components(separatedBy: " ").first ?? "Driver"
    }

    func driverInitials(_ user: User?) -> String {
        guard let name = user?.name else { return "?" }
        let parts = name.components(separatedBy: " ")
        let initials = parts.prefix(2).compactMap { $0.first }.map(String.init).joined()
        return initials.isEmpty ? "?" : initials
    }
}
