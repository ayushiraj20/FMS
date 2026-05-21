import Foundation
import Combine

@MainActor
final class FleetManagerDashboardViewModel: ObservableObject {
    @Published var isLoading = true

    func load() async {
        guard isLoading else { return }
        try? await Task.sleep(for: .seconds(0.5))
        isLoading = false
    }

    func stats(service: MockDataService) -> [KPIStat] {
        let activeVehicles = service.vehicles.filter { $0.status == .active }.count
        let openOrders = service.workOrders.filter { $0.status != .completed }.count
        let activeDrivers = service.users.filter { $0.role == .driver && $0.assignedVehicleID != nil }.count
        let expiringDocs = service.documents.filter { $0.expiryDate < .now.addingTimeInterval(86400 * 90) }.count
        return [
            KPIStat(title: "Fleet Availability", value: "\(activeVehicles)/\(service.vehicles.count)", detail: "Vehicles currently dispatch-ready", trend: "+4% vs last week"),
            KPIStat(title: "Open Work Orders", value: "\(openOrders)", detail: "Issues needing maintenance follow-up", trend: "\(service.workOrders.filter { $0.priority == .critical }.count) critical"),
            KPIStat(title: "Drivers Assigned", value: "\(activeDrivers)", detail: "Drivers currently mapped to vehicles", trend: "Coverage aligned"),
            KPIStat(title: "Expiring Documents", value: "\(expiringDocs)", detail: "Policies and permits due within 90 days", trend: "Action recommended")
        ]
    }
}

@MainActor
final class DriverDashboardViewModel: ObservableObject {
    @Published var isLoading = true

    func load() async {
        guard isLoading else { return }
        try? await Task.sleep(for: .seconds(0.35))
        isLoading = false
    }
}

@MainActor
final class MaintenanceDashboardViewModel: ObservableObject {
    @Published var isLoading = true

    func load() async {
        guard isLoading else { return }
        try? await Task.sleep(for: .seconds(0.35))
        isLoading = false
    }
}
