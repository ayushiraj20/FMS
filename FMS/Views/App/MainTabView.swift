import SwiftUI

struct MainTabView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        Group {
            switch appViewModel.currentRole {
            case .fleetManager:
                FleetManagerTabView()
            case .driver:
                DriverTabView()
            case .maintenance:
                MaintenanceTabView()
            case .none:
                EmptyStateView(icon: "person.crop.circle.badge.exclamationmark", title: "No active session", message: "Select a demo role or sign in again.")
            }
        }
    }
}

private struct FleetManagerTabView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        TabView {
            NavigationStack { FleetManagerDashboardView() }
                .tabItem { Label("Dashboard", systemImage: "square.grid.2x2.fill") }

            NavigationStack { VehicleManagementView(service: appViewModel.service, currentOrgID: appViewModel.currentOrganization?.id) }
                .tabItem { Label("Vehicles", systemImage: "truck.box.fill") }

            NavigationStack { TeamView(service: appViewModel.service, currentOrgID: appViewModel.currentOrganization?.id) }
                .tabItem { Label("Team", systemImage: "person.2.fill") }

            NavigationStack { MaintenanceTabContentView() }
                .tabItem { Label("Maintenance", systemImage: "wrench.and.screwdriver.fill") }
        }
        .tint(Color("AccentColor"))
    }
}

private struct DriverTabView: View {
    var body: some View {
        TabView {
            NavigationStack { DriverDashboardView() }
                .tabItem { Label("Dashboard", systemImage: "steeringwheel") }

            NavigationStack { InspectionsView() }
                .tabItem { Label("Inspections", systemImage: "checklist") }

            NavigationStack { DriverTripsView() }
                .tabItem { Label("Trips", systemImage: "map.fill") }

            NavigationStack { ProfileSettingsView() }
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
        }
        .tint(Color("AccentColor"))
    }
}

private struct MaintenanceTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack { MaintenanceDashboardView() }
                .tabItem { Label("Dashboard", systemImage: "wrench.adjustable.fill") }
                .tag(0)

            NavigationStack { MaintenanceWorkOrdersView() }
                .tabItem { Label("Orders", systemImage: "list.clipboard.fill") }
                .tag(1)

            // Previous third tab kept for rollback:
            // NavigationStack { MaintenanceScheduleView() }
            //     .tabItem { Label("Schedules", systemImage: "calendar") }
            NavigationStack { MaintenanceInventoryView() }
                .tabItem { Label("Inventory", systemImage: "shippingbox.fill") }
                .tag(2)

            NavigationStack { ProfileSettingsView() }
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
                .tag(3)
        }
        .onReceive(NotificationCenter.default.publisher(for: .maintenanceDashboardRequested)) { _ in
            selectedTab = 0
        }
        .tint(Color("AccentColor"))
    }
}

extension Notification.Name {
    static let maintenanceDashboardRequested = Notification.Name("maintenanceDashboardRequested")
}

#Preview {
    MainTabView()
        .environment(AppViewModel())
}
