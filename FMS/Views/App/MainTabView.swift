import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

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
    @EnvironmentObject private var appViewModel: AppViewModel

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
    }
}

private struct MaintenanceTabView: View {
    var body: some View {
        TabView {
            NavigationStack { MaintenanceDashboardView() }
                .tabItem { Label("Dashboard", systemImage: "wrench.adjustable.fill") }

            NavigationStack { MaintenanceWorkOrdersView() }
                .tabItem { Label("Orders", systemImage: "list.clipboard.fill") }

            NavigationStack { MaintenanceScheduleView() }
                .tabItem { Label("Schedules", systemImage: "calendar") }

            NavigationStack { ProfileSettingsView() }
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppViewModel())
}
