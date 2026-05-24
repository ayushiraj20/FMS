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
                    message: "Select a demo role or sign in again."
                )
            }
        }
    }
}

private struct FleetManagerTabView: View {

    @Environment(AppViewModel.self)
    private var appViewModel

    var body: some View {

        TabView {

            NavigationStack {
                FleetManagerDashboardView()
            }
            .tabItem {
                Label(
                    "Dashboard",
                    systemImage: "square.grid.2x2.fill"
                )
            }

            NavigationStack {
                VehicleManagementView(
                    service: appViewModel.service,
                    currentOrgID:
                    appViewModel.currentOrganization?.id
                )
            }
            .tabItem {
                Label(
                    "Vehicles",
                    systemImage: "truck.box.fill"
                )
            }

            NavigationStack {
                DriverAssignmentManagementView(service: appViewModel.service)
            }
            .tabItem {
                Label(
                    "Driver",
                    systemImage: "person.2.fill"
                )
            }

            NavigationStack {
                TeamView(
                    service: appViewModel.service,
                    currentOrgID:
                    appViewModel.currentOrganization?.id
                )
            }
            .tabItem {
                Label(
                    "Team",
                    systemImage: "person.3.fill"
                )
            }

            NavigationStack {
                MaintenanceTabContentView()
            }
            .tabItem {
                Label(
                    "Maintenance",
                    systemImage:
                    "wrench.and.screwdriver.fill"
                )
            }
        }
        .tint(Color("AccentColor"))
    }
}


private struct DriverTabView: View {

    @Environment(AppViewModel.self)
    private var appViewModel

    @State
    private var driverVM = DriverViewModel()

    var body: some View {

        ZStack(alignment: .bottom) {

            TabView(
                selection:
                $driverVM.selectedTab
            ) {

                NavigationStack {
                    DriverDashboardView()
                }
                .tabItem {
                    Label(
                        "Dashboard",
                        systemImage:
                        "house.fill"
                    )
                }
                .tag(0)

                NavigationStack {
                    DriverTripTabView()
                }
                .tabItem {
                    Label(
                        "Trip",
                        systemImage:
                        "map.fill"
                    )
                }
                .tag(1)

                // NEW TAB

                NavigationStack {
                    BroadcastInboxView()
                }
                .tabItem {
                    Label(
                        "Broadcasts",
                        systemImage:
                        "megaphone.fill"
                    )
                }
                .tag(2)

            }
            .tint(
                DriverTheme.accent
            )

            // Persistent SOS button

            if let user =
                appViewModel.currentUser,

               appViewModel.service
                .activeTrip(
                    for: user.id
                ) != nil {

                Button {

                    driverVM
                        .startSOSCountdown(
                            service:
                            appViewModel.service,

                            user:
                            appViewModel.currentUser
                        )

                } label: {

                    HStack(
                        spacing: 6
                    ) {

                        Image(
                            systemName:
                            "sos"
                        )
                        .font(
                            .system(
                                size: 14,
                                weight:
                                .bold
                            )
                        )

                        Text(
                            "SOS"
                        )
                        .font(
                            .system(
                                size: 14,
                                weight:
                                .bold
                            )
                        )
                    }
                    .foregroundStyle(
                        .white
                    )
                    .padding(
                        .horizontal,
                        20
                    )
                    .padding(
                        .vertical,
                        10
                    )
                    .background(
                        Capsule()
                            .fill(
                                DriverTheme
                                    .criticalRed
                            )
                    )
                }
                .padding(
                    .bottom,
                    60
                )
            }
        }
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
        }
        .tint(
            Color(
                "AccentColor"
            )
        )
    }
}


private struct MaintenanceTabView: View {

    @State
    private var selectedTab = 0

    var body: some View {

        TabView(
            selection:
            $selectedTab
        ) {

            NavigationStack {
                MaintenanceDashboardView()
            }
            .tabItem {
                Label(
                    "Dashboard",
                    systemImage:
                    "wrench.adjustable.fill"
                )
            }
            .tag(0)

            NavigationStack {
                MaintenanceWorkOrdersView()
            }
            .tabItem {
                Label(
                    "Orders",
                    systemImage:
                    "list.clipboard.fill"
                )
            }
            .tag(1)

            NavigationStack {
                MaintenanceInventoryView()
            }
            .tabItem {
                Label(
                    "Inventory",
                    systemImage:
                    "shippingbox.fill"
                )
            }
            .tag(2)
        }

        .onReceive(
            NotificationCenter.default.publisher(
                for:
                .maintenanceDashboardRequested
            )
        ) { _ in

            selectedTab = 0
        }

        .tint(
            Color(
                "AccentColor"
            )
        )
    }
}

extension Notification.Name {

    static let maintenanceDashboardRequested =
    Notification.Name(
        "maintenanceDashboardRequested"
    )
}

#Preview {

    MainTabView()
        .environment(
            AppViewModel()
        )
}
