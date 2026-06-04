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

        TabView {
            NavigationStack {
                FleetManagerDashboardView()
            }
            .tabItem {
                Label("Dashboard", systemImage: "square.grid.2x2.fill")
            }

            NavigationStack {
                FleetManagerTripsView()
            }
            .tabItem {
                Label("Trips", systemImage: "truck.box.fill")
            }

            NavigationStack {
                VehicleManagementView(
                    service: appViewModel.service,
                    currentOrgID: appViewModel.currentOrganization?.id
                )
            }
            .tabItem {
                Label("Vehicles", systemImage: "car.2.fill")
            }

            NavigationStack {
                TeamView(
                    service: appViewModel.service,
                    currentOrgID: appViewModel.currentOrganization?.id
                )
            }
            .tabItem {
                Label("Crew", systemImage: "person.2.fill")
            }
        }
        .tint(Color("AccentColor"))
        .toolbar(sheetPresentationDepth > 0 ? .hidden : .automatic, for: .tabBar)
        .tabBarSheetDepthTracking($sheetPresentationDepth)
    }
}


private struct DriverTabView: View {

    @Environment(AppViewModel.self)
    private var appViewModel
    @State private var sheetPresentationDepth = 0
    @State private var showVoiceTripInspectionSheet = false
    @State private var voiceTripToStart: Trip?
    @State private var showVoiceTripEndInspectionSheet = false
    @State private var voiceTripToEnd: Trip?
    @State private var showVoiceRefuelSheet = false

    @State
    private var driverVM = DriverViewModel()

    private var currentUser: User? { appViewModel.currentUser }

    var body: some View {

        ZStack(alignment: .bottomTrailing) {
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
                        "truck.box.fill"
                    )
                }
                .tag(1)
            }

            if driverVM.selectedTab == 0 && !driverVM.hideVoiceLogger {
                DriverVoiceLoggerView(
                    onStartTripRequested: handleVoiceStartTrip,
                    onEndTripRequested: handleVoiceEndTrip,
                    onRefuelRequested: handleVoiceRefuel,
                    onLiveMapRequested: showTripsTab,
                    onDashboardRequested: showDashboardTab,
                    onTripsRequested: showTripsTab
                )
                .padding(.trailing, 20)
                .padding(.bottom, 96)
            }
        }
        .sheet(isPresented: $showVoiceRefuelSheet) {
            if let user = currentUser, let vehicle = voiceCommandVehicle(for: user) {
                RefuelVehicleView(
                    vehicleID: vehicle.id,
                    driverID: user.id,
                    tripID: appViewModel.service.activeTrip(for: user.id)?.id,
                    repo: FuelRepository(
                        service: FuelService(
                            client: SupabaseService.shared.client
                        )
                    )
                )
                .environment(appViewModel)
                .registersSheetPresentation()
            } else {
                EmptyStateView(
                    icon: "fuelpump",
                    title: "No vehicle found",
                    message: "A vehicle assignment or active trip is required to log refuel."
                )
                .registersSheetPresentation()
            }
        }
        .sheet(isPresented: $showVoiceTripInspectionSheet) {
            TripStartInspectionSheet(trip: voiceTripToStart) {
                driverVM.showToastMessage("Trip started. Have a safe journey.")
            }
            .environment(appViewModel)
            .environment(driverVM)
            .registersSheetPresentation()
        }
        .sheet(isPresented: $showVoiceTripEndInspectionSheet) {
            TripStartInspectionSheet(trip: voiceTripToEnd, inspectionType: .postTrip) {
                driverVM.showToastMessage("Trip ended successfully.")
            }
            .environment(appViewModel)
            .environment(driverVM)
            .registersSheetPresentation()
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
        .task {
            driverVM.enableBackgroundGeofenceMonitoring(
                service: appViewModel.service,
                user: appViewModel.currentUser
            )
            driverVM.startLiveTracking()
            await appViewModel.service.prefetchRoutePlansForActiveTrips()
        }
        .onDisappear {
            driverVM.stopLiveTracking()
            driverVM.disableBackgroundGeofenceMonitoring()
        }
    }

    private func handleVoiceStartTrip() {
        guard let user = currentUser else { return }
        if let activeTrip = appViewModel.service.activeTrip(for: user.id) {
            driverVM.showToastMessage("Trip already in progress to \(activeTrip.destination).")
            showTripsTab()
            return
        }
        guard let nextTrip = appViewModel.service.upcomingTrips(for: user.id).first else {
            driverVM.showToastMessage("No scheduled trip found.")
            showTripsTab()
            return
        }
        voiceTripToStart = nextTrip
        showVoiceTripInspectionSheet = true
    }

    private func handleVoiceEndTrip() {
        guard let user = currentUser else { return }
        guard let activeTrip = appViewModel.service.activeTrip(for: user.id) else {
            driverVM.showToastMessage("No active trip found.")
            showTripsTab()
            return
        }
        voiceTripToEnd = activeTrip
        showVoiceTripEndInspectionSheet = true
    }

    private func handleVoiceRefuel() {
        guard let user = currentUser, voiceCommandVehicle(for: user) != nil else {
            driverVM.showToastMessage("No assigned vehicle found for refuel.")
            return
        }
        showVoiceRefuelSheet = true
    }

    private func showDashboardTab() {
        driverVM.selectedTab = 0
    }

    private func showTripsTab() {
        driverVM.selectedTab = 1
    }

    private func voiceCommandVehicle(for user: User) -> Vehicle? {
        if let assignedVehicle = appViewModel.assignedVehicle {
            return assignedVehicle
        }
        if let activeTrip = appViewModel.service.activeTrip(for: user.id) {
            return appViewModel.service.vehicle(for: activeTrip.vehicleID)
        }
        return nil
    }
}


private struct MaintenanceTabView: View {

    @State
    private var selectedTab = 0
    @State private var sheetPresentationDepth = 0

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

            NavigationStack {
                MaintenanceReportsView()
            }
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
            Color(hex: "#FF9500")
        )
        .toolbar(sheetPresentationDepth > 0 ? .hidden : .automatic, for: .tabBar)
        .tabBarSheetDepthTracking($sheetPresentationDepth)
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
