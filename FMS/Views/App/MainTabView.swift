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
                EmptyStateView(
                    icon: "person.crop.circle.badge.exclamationmark",
                    title: "No active session",
                    message: "Sign in to \(AppBranding.name) to continue."
                )
            }
        }
    }
}

private struct FleetManagerTabView: View {

    @Environment(AppViewModel.self)
    private var appViewModel
    @State private var sheetPresentationDepth = 0

    var body: some View {
        NavigationStack {
            TabView {
                FleetManagerDashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "square.grid.2x2.fill")
                    }

                FleetManagerTripsView()
                    .tabItem {
                        Label("Trips", systemImage: "truck.box.fill")
                    }

                VehicleManagementView(
                    service: appViewModel.service,
                    currentOrgID: appViewModel.currentOrganization?.id
                )
                .tabItem {
                    Label("Vehicles", systemImage: "car.2.fill")
                }

                TeamView(
                    service: appViewModel.service,
                    currentOrgID: appViewModel.currentOrganization?.id
                )
                .tabItem {
                    Label("Crew", systemImage: "person.2.fill")
                }
            }
            .tint(Color("AccentColor"))
            .toolbar(sheetPresentationDepth > 0 ? .hidden : .automatic, for: .tabBar)
            .tabBarSheetDepthTracking($sheetPresentationDepth)
        }
    }
}


private struct DriverTabView: View {

    @Environment(AppViewModel.self)
    private var appViewModel
    @State private var sheetPresentationDepth = 0

    @State
    private var driverVM = DriverViewModel()

    var body: some View {
        NavigationStack {
            TabView(
                selection:
                $driverVM.selectedTab
            ) {

                DriverDashboardView()
                    .tabItem {
                        Label(
                            "Dashboard",
                            systemImage:
                            "house.fill"
                        )
                    }
                    .tag(0)

                DriverTripTabView()
                    .tabItem {
                        Label(
                            "Trip",
                            systemImage:
                            "truck.box.fill"
                        )
                    }
                    .tag(1)

            }
            .tint(
                DriverTheme.accent
            )
            .environment(
                driverVM
            )
            .fullScreenCover(
                isPresented:
                $driverVM.showSOSSheet
            ) {

                SOSSheetView()
                    .environment(
                        appViewModel
                    )
                    .environment(
                        driverVM
                    )
                    .registersSheetPresentation()
            }
            .toolbar(sheetPresentationDepth > 0 ? .hidden : .automatic, for: .tabBar)
            .tabBarSheetDepthTracking($sheetPresentationDepth)
        }
    }
}


private struct MaintenanceTabView: View {

    @State
    private var selectedTab = 0
    @State private var sheetPresentationDepth = 0

    var body: some View {
        NavigationStack {
            TabView(
                selection:
                $selectedTab
            ) {

                MaintenanceDashboardView()
                    .tabItem {
                        Label(
                            "Dashboard",
                            systemImage:
                            "wrench.adjustable.fill"
                        )
                    }
                    .tag(0)

                MaintenanceWorkOrdersView()
                    .tabItem {
                        Label(
                            "Orders",
                            systemImage:
                            "list.clipboard.fill"
                        )
                    }
                    .tag(1)

                MaintenanceInventoryView()
                    .tabItem {
                        Label(
                            "Inventory",
                            systemImage:
                            "shippingbox.fill"
                        )
                    }
                    .tag(2)

                MaintenanceReportsView()
                    .tabItem {
                        Label(
                            "Reports",
                            systemImage:
                            "doc.text.fill"
                        )
                    }
                    .tag(3)
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for:
                    .maintenanceDashboardRequested
                )
            ) { _ in

                selectedTab = 0
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for:
                    .maintenanceOrdersRequested
                )
            ) { _ in

                selectedTab = 1
            }
            .tint(
                Color(hex: "#FF5A1F")
            )
            .toolbar(sheetPresentationDepth > 0 ? .hidden : .automatic, for: .tabBar)
            .tabBarSheetDepthTracking($sheetPresentationDepth)
        }
    }
}

extension Notification.Name {

    static let maintenanceDashboardRequested =
    Notification.Name(
        "maintenanceDashboardRequested"
    )

    static let maintenanceOrdersRequested =
    Notification.Name(
        "maintenanceOrdersRequested"
    )

    static let inventoryNeedsRefresh =
    Notification.Name(
        "inventoryNeedsRefresh"
    )
}

#Preview {

    MainTabView()
        .environment(
            AppViewModel()
        )
}
