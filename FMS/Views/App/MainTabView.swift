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
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var driverVM = DriverViewModel()

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView(selection: $driverVM.selectedTab) {
                NavigationStack { DriverDashboardView() }
                    .tabItem { Label("Dashboard", systemImage: "house.fill") }
                    .tag(0)

                NavigationStack { DriverTripTabView() }
                    .tabItem { Label("Trip", systemImage: "map.fill") }
                    .tag(1)
            }
            .tint(DriverTheme.accent)

            // Persistent SOS button when active trip exists
            if let user = appViewModel.currentUser,
               appViewModel.service.activeTrip(for: user.id) != nil {
                Button {
                    driverVM.startSOSCountdown(service: appViewModel.service, user: appViewModel.currentUser)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sos")
                            .font(.system(size: 14, weight: .bold))
                        Text("SOS")
                            .font(.system(size: 14, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(DriverTheme.criticalRed))
                }
                .padding(.bottom, 60)
            }
        }
        .environmentObject(driverVM)
        .fullScreenCover(isPresented: $driverVM.showSOSSheet) {
            SOSSheetView()
                .environmentObject(appViewModel)
                .environmentObject(driverVM)
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
