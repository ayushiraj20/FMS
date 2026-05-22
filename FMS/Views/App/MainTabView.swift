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
                .tabItem { Label("Dashboard", systemImage: "chart.pie.fill") }

            NavigationStack { VehicleManagementView(service: appViewModel.service, currentOrgID: appViewModel.currentOrganization?.id) }
                .tabItem { Label("Vehicles", systemImage: "car.side.fill") }

            NavigationStack { WorkOrderManagementView(service: appViewModel.service, currentOrgID: appViewModel.currentOrganization?.id) }
                .tabItem { Label("Work Orders", systemImage: "wrench.and.screwdriver.fill") }

            NavigationStack { ProfileSettingsView() }
                .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
        }
    }
}

private struct DriverTabView: View {
    var body: some View {
        TabView {
            NavigationStack { DriverDashboardView() }
                .tabItem { Label("Dashboard", systemImage: "steeringwheel") }

            NavigationStack { AssignedRoutesView() }
                .tabItem { Label("Routes", systemImage: "map.fill") }

            NavigationStack { InspectionsView() }
                .tabItem { Label("Inspections", systemImage: "checklist") }

            NavigationStack { DriverTripsView() }
                .tabItem { Label("Trips", systemImage: "point.topleft.down.to.point.bottomright.curvepath.fill") }

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
