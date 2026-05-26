import Foundation

import Observation

@Observable
@MainActor
final class FleetManagerDashboardViewModel {
    var isLoading = true

    func load() async {
        guard isLoading else { return }
        try? await Task.sleep(for: .seconds(0.5))
        isLoading = false
    }

    func stats(service: MockDataService) -> [KPIStat] {
        let activeVehicles = service.vehicles.filter { $0.status == .active }.count
        let openOrders = service.workOrders.filter { $0.status != .completed }.count
        let criticalOrders = service.workOrders.filter { $0.priority == .critical }.count
        let expiringDocs = service.documents.filter { $0.expiryDate < .now.addingTimeInterval(86400 * 90) }.count
        let totalFuelSpend = service.vehicles.reduce(0) { $0 + (100 - $1.fuelLevel) * 52 }

        return [
            KPIStat(
                title: "Active Vehicles",
                value: "\(activeVehicles)",
                detail: "Vehicles currently dispatch-ready",
                trend: "+4% vs last week",
                iconName: "truck.box.fill"
            ),
            KPIStat(
                title: "Fuel Spend",
                value: "₹\(formattedNumber(totalFuelSpend))",
                detail: "Estimated monthly fuel expenditure",
                trend: "Within budget",
                iconName: "fuelpump.fill"
            ),
            KPIStat(
                title: "Open Work Orders",
                value: "\(openOrders)",
                detail: "Issues needing maintenance follow-up",
                trend: "\(criticalOrders) critical",
                iconName: "wrench.and.screwdriver.fill",
                badgeText: criticalOrders > 0 ? "CRITICAL" : nil,
                badgeColor: .critical
            ),
            KPIStat(
                title: "Expiring Documents",
                value: "\(expiringDocs)",
                detail: "Policies and permits due within 90 days",
                trend: "Action recommended",
                iconName: "doc.text.fill",
                badgeText: expiringDocs > 0 ? "ACTION" : nil,
                badgeColor: .action
            )
        ]
    }

    private func formattedNumber(_ value: Int) -> String {
        if value >= 1000 {
            let k = Double(value) / 1000.0
            return String(format: "%.1fk", k)
        }
        return "\(value)"
    }
}

@Observable
@MainActor
final class DriverDashboardViewModel {
    var isLoading = true

    func load() async {
        guard isLoading else { return }
        try? await Task.sleep(for: .seconds(0.35))
        isLoading = false
    }
}

@Observable
@MainActor
final class MaintenanceDashboardViewModel {
    var isLoading = true

    func load() async {
        guard isLoading else { return }
        try? await Task.sleep(for: .seconds(0.35))
        isLoading = false
    }
}
