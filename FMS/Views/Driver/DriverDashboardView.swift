import SwiftUI

struct DriverDashboardView: View {
    @Environment(AppViewModel.self) private var appViewModel: AppViewModel
    @Environment(DriverViewModel.self) private var driverVM: DriverViewModel

    // Pre-trip inspection gate
    @State private var showTripInspectionSheet = false
    @State private var tripToStart: Trip? = nil

    private var currentUser: User? { appViewModel.currentUser }
    private var assignedVehicle: Vehicle? { appViewModel.assignedVehicle }

    // MARK: - Adaptive Theme Palette (light & dark)
    private enum LocalTheme {
        // Backgrounds: deep dark in dark mode, system white in light mode
        static let background = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.071, green: 0.071, blue: 0.090, alpha: 1) // #121217
                : UIColor.systemBackground
        })
        static let cardBackground = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.110, green: 0.110, blue: 0.129, alpha: 1) // #1C1C21
                : UIColor.secondarySystemBackground
        })
        // Text: white in dark, system label (near-black) in light
        static let textPrimary = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor.white : UIColor.label
        })
        static let textSecondary = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.557, green: 0.557, blue: 0.576, alpha: 1)
                : UIColor.secondaryLabel
        })
        // Accent & status — same in both modes
        static let accent = Color(hex: "FD5D23")
        static let successGreen = Color(hex: "34C759")
        static let criticalRed = Color(hex: "FF3B30")
        // Duty pill: adaptive green background
        static let dutyGreenBg = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.122, green: 0.243, blue: 0.169, alpha: 1) // #1F3E2B
                : UIColor(red: 0.204, green: 0.780, blue: 0.349, alpha: 0.15)
        })
        static let dutyGreenText = Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.290, green: 0.871, blue: 0.502, alpha: 1) // #4ADE80
                : UIColor(red: 0.106, green: 0.502, blue: 0.224, alpha: 1)
        })
    }

    var body: some View {
        @Bindable var driverVM = driverVM
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                if driverVM.isLoading {
                    LoadingStateView(title: "Loading dashboard...")
                        .frame(height: 320)
                } else {
                    topBar
                    greetingRow
                    vehicleAlertBanner
                    vehicleAndShiftRow
                    activeTripCard
                    quickActionsSection
                    todayStatsSection
                    reportedDefectsSection
                }
            }
            .padding(20)
        }
        .background(LocalTheme.background.ignoresSafeArea())
        .refreshable {
            driverVM.isLoading = true
            await appViewModel.service.syncWithDatabase()
            await driverVM.load()
            await appViewModel.loadNotifications()
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await appViewModel.service.syncWithDatabase()
            await driverVM.load()
            await appViewModel.loadNotifications()
        }
        .sheet(isPresented: $driverVM.showFuelReceiptSheet) {
            FuelReceiptView()
                .environment(appViewModel)
                .environment(driverVM)
        }
        .sheet(isPresented: $driverVM.showBreakLogSheet) {
            BreakLogSheet()
                .environment(appViewModel)
        }
        .sheet(item: $driverVM.showAlertDetail) { alert in
            VehicleAlertDetailSheet(alert: alert)
                .environment(appViewModel)
        }
        .sheet(isPresented: $showTripInspectionSheet) {
            TripStartInspectionSheet(trip: tripToStart) {
                driverVM.showToastMessage("Trip started! Have a safe journey 🚛")
            }
            .environment(appViewModel)
            .environment(driverVM)
        }
        .overlay(alignment: .top) {
            if driverVM.showToast, let message = driverVM.toastMessage {
                toastBanner(message)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.4), value: driverVM.showToast)
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            // FIX: Profile Avatar Button moved to LEFT
            NavigationLink {
                DriverProfileView()
                    .environment(appViewModel)
                    .environment(driverVM)
            } label: {
                ZStack {
                    Circle()
                        .fill(LocalTheme.accent)
                        .frame(width: 44, height: 44)
                    Text(driverVM.driverInitials(currentUser))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .accessibilityIdentifier("PROFILE_BUTTON")

            Spacer()

            // Bell Button stays on RIGHT
            NavigationLink(destination: NotificationsView()) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(LocalTheme.cardBackground)
                        .frame(width: 44, height: 44)

                    Image(systemName: "bell.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(LocalTheme.accent)
                        .frame(width: 44, height: 44)

                    if appViewModel.unreadNotificationsCount > 0 {
                        Circle()
                            .fill(LocalTheme.criticalRed)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Text("\(appViewModel.unreadNotificationsCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .accessibilityIdentifier("BELL_BUTTON")
        }
    }

    // MARK: - Greeting Row

    @ViewBuilder
    private var greetingRow: some View {
        @Bindable var driverVM = driverVM
        HStack(alignment: .center) {
            Text("Hello, \(driverVM.driverFirstName(currentUser))")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(LocalTheme.textPrimary)

            Spacer()

            if let user = currentUser {
                let isOnDuty = appViewModel.service.dutyStatus(for: user.id) == .onDuty
                Button {
                    driverVM.showDutyToggleAlert = true
                } label: {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(isOnDuty ? LocalTheme.successGreen : Color.gray)
                            .frame(width: 8, height: 8)
                        Text(isOnDuty ? "On Duty" : "Off Duty")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(isOnDuty ? LocalTheme.dutyGreenText : Color.gray)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(isOnDuty ? LocalTheme.dutyGreenBg : Color(UIColor { trait in
                        trait.userInterfaceStyle == .dark
                            ? UIColor.white.withAlphaComponent(0.08)
                            : UIColor.black.withAlphaComponent(0.06)
                    })))
                }
                .alert("Change Duty Status", isPresented: $driverVM.showDutyToggleAlert) {
                    Button("Confirm") {
                        appViewModel.service.toggleDutyStatus(for: user.id)
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    let newStatus = appViewModel.service.dutyStatus(for: user.id) == .onDuty ? "Off Duty" : "On Duty"
                    Text("Switch to \(newStatus)?")
                }
            }
        }
        .accessibilityIdentifier("STATUS_BADGE")
    }

    // MARK: - Vehicle Alert Banner

    @ViewBuilder
    private var vehicleAlertBanner: some View {
        if let vehicleID = assignedVehicle?.id {
            let alerts = appViewModel.service.alerts(for: vehicleID)
            if let firstAlert = alerts.first {
                Button {
                    driverVM.showAlertDetail = firstAlert
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(.white)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(firstAlert.alertType.rawValue)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                            Text(firstAlert.recommendedAction)
                                .font(.system(size: 13))
                                .foregroundStyle(.white.opacity(0.85))
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(firstAlert.severity == .critical ? LocalTheme.criticalRed : LocalTheme.accent)
                    )
                }
                .accessibilityIdentifier("VEHICLE_ALERT_BANNER")
            }
        }
    }

    // MARK: - Vehicle & Shift Cards

    private var vehicleAndShiftRow: some View {
        HStack(spacing: 12) {
            // Vehicle Card
            NavigationLink {
                DriverVehicleTripDetailView()
                    .environment(appViewModel)
                    .environment(driverVM)
            } label: {
                CustomDarkCard {
                    VStack(alignment: .leading, spacing: 8) {
                        // Vehicle image — uses asset if available, SF Symbol fallback otherwise
                        Group {
                            if UIImage(named: "truck_placeholder") != nil {
                                Image("truck_placeholder")
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(LocalTheme.cardBackground)
                                    Image(systemName: "truck.box.fill")
                                        .font(.system(size: 40))
                                        .foregroundStyle(LocalTheme.accent.opacity(0.9))
                                }
                            }
                        }
                        .frame(height: 90)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        let plateNumber = assignedVehicle?.plateNumber ?? "TRK-2847"
                        let displayName = assignedVehicle?.displayName ?? "Tata Ace"

                        HStack(spacing: 6) {
                            Text(plateNumber)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(LocalTheme.textPrimary)

                            Circle()
                                .fill(assignedVehicle?.status == .active ? LocalTheme.successGreen : Color.gray)
                                .frame(width: 8, height: 8)
                        }

                        Text(displayName)
                            .font(.system(size: 13))
                            .foregroundStyle(LocalTheme.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("VEHICLE_CARD")

            // Shift Card
            NavigationLink {
                DriverShiftDetailView()
                    .environment(appViewModel)
                    .environment(driverVM)
            } label: {
                CustomDarkCard {
                    VStack(spacing: 8) {
                        Text("Today's Shift")
                            .font(.system(size: 13))
                            .foregroundStyle(LocalTheme.textSecondary)

                        let shift = currentUser.flatMap { appViewModel.service.currentShift(for: $0.id) }
                        let shiftStartTime = shift?.startTime.formatted(date: .omitted, time: .shortened) ?? "6:00 AM"
                        let shiftEndTime = shift?.endTime.formatted(date: .omitted, time: .shortened) ?? "6:00 PM"
                        let shiftProgress = shift?.progress ?? 0.65
                        let shiftRemaining = shift != nil ? "\(String(format: "%.1f", shift!.remainingHours))h remaining" : "6.5h remaining"

                        Text("\(shiftStartTime) - \(shiftEndTime)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(LocalTheme.textSecondary)

                        ZStack {
                            ShiftProgressRing(
                                progress: shiftProgress,
                                size: 75,
                                strokeWidth: 8
                            )

                            Text("\(Int(shiftProgress * 100))%")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(LocalTheme.textPrimary)
                        }
                        .padding(.vertical, 2)

                        Text(shiftRemaining)
                            .font(.system(size: 13))
                            .foregroundStyle(LocalTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("SHIFT_CARD")
        }
    }

    // MARK: - Active Trip Card

    private var activeTripCard: some View {
        Group {
            if let user = currentUser {
                if let activeTrip = appViewModel.service.activeTrip(for: user.id) {
                    NavigationLink(destination: TripDetailView(trip: activeTrip).environment(appViewModel)) {
                        CustomDarkCard {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("Active Trip")
                                        .font(.system(size: 12, weight: .bold))
                                        .tracking(1)
                                        .foregroundStyle(LocalTheme.accent)
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(LocalTheme.successGreen)
                                            .frame(width: 6, height: 6)
                                        Text("IN PROGRESS")
                                            .font(.system(size: 10, weight: .black))
                                            .foregroundStyle(LocalTheme.successGreen)
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Route")
                                        .font(.caption)
                                        .foregroundStyle(LocalTheme.textSecondary)
                                    Text("\(activeTrip.origin) → \(activeTrip.destination)")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(LocalTheme.textPrimary)
                                }
                                
                                HStack(spacing: 24) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Start Time")
                                            .font(.system(size: 11))
                                            .foregroundStyle(LocalTheme.textSecondary)
                                        Text(activeTrip.startDate.formatted(date: .abbreviated, time: .shortened))
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(LocalTheme.textPrimary)
                                    }
                                    
                                    if let endDate = activeTrip.endDate {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("End Time")
                                                .font(.system(size: 11))
                                                .foregroundStyle(LocalTheme.textSecondary)
                                            Text(endDate.formatted(date: .abbreviated, time: .shortened))
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(LocalTheme.textPrimary)
                                        }
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Distance")
                                            .font(.system(size: 11))
                                            .foregroundStyle(LocalTheme.textSecondary)
                                        Text("\(Int(activeTrip.distanceKM)) km")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(LocalTheme.textPrimary)
                                    }
                                }
                                
                                if let route = activeTrip.routeDetails {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Route Details")
                                            .font(.system(size: 11))
                                            .foregroundStyle(LocalTheme.textSecondary)
                                        Text(route)
                                            .font(.system(size: 12))
                                            .foregroundStyle(LocalTheme.textPrimary)
                                            .lineLimit(2)
                                    }
                                    .padding(.top, 2)
                                }
                                
                                if let note = activeTrip.notes {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Instructions")
                                            .font(.system(size: 11))
                                            .foregroundStyle(LocalTheme.textSecondary)
                                        Text(note)
                                            .font(.system(size: 12))
                                            .foregroundStyle(LocalTheme.textPrimary)
                                            .lineLimit(2)
                                    }
                                    .padding(.top, 2)
                                }
                                
                                HStack {
                                    if let vehicle = assignedVehicle {
                                        HStack(spacing: 8) {
                                            Image(systemName: "truck.box.fill")
                                                .foregroundStyle(LocalTheme.accent)
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(vehicle.displayName)
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(LocalTheme.textPrimary)
                                                Text(vehicle.plateNumber)
                                                    .font(.system(size: 10))
                                                    .foregroundStyle(LocalTheme.textSecondary)
                                            }
                                        }
                                    }
                                    Spacer()
                                    Text("Resume Trip")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Capsule().fill(LocalTheme.accent))
                                }
                                .padding(.top, 6)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    let upcoming = appViewModel.service.upcomingTrips(for: user.id)
                    if let nextTrip = upcoming.first {
                        // NOT wrapped in NavigationLink — has separate buttons inside
                        CustomDarkCard {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack {
                                    Text("Upcoming Trip")
                                        .font(.system(size: 12, weight: .bold))
                                        .tracking(1)
                                        .foregroundStyle(LocalTheme.textSecondary)
                                    Spacer()
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Color.gray)
                                            .frame(width: 6, height: 6)
                                        Text("SCHEDULED")
                                            .font(.system(size: 10, weight: .black))
                                            .foregroundStyle(Color.gray)
                                    }
                                }

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Route")
                                        .font(.caption)
                                        .foregroundStyle(LocalTheme.textSecondary)
                                    Text("\(nextTrip.origin) → \(nextTrip.destination)")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundStyle(LocalTheme.textPrimary)
                                }

                                HStack(spacing: 24) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Start Time")
                                            .font(.system(size: 11))
                                            .foregroundStyle(LocalTheme.textSecondary)
                                        Text(nextTrip.startDate.formatted(date: .abbreviated, time: .shortened))
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(LocalTheme.textPrimary)
                                    }

                                    if let endDate = nextTrip.endDate {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("End Time")
                                                .font(.system(size: 11))
                                                .foregroundStyle(LocalTheme.textSecondary)
                                            Text(endDate.formatted(date: .abbreviated, time: .shortened))
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundStyle(LocalTheme.textPrimary)
                                        }
                                    }

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Distance")
                                            .font(.system(size: 11))
                                            .foregroundStyle(LocalTheme.textSecondary)
                                        Text("\(Int(nextTrip.distanceKM)) km")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(LocalTheme.textPrimary)
                                    }
                                }

                                if let route = nextTrip.routeDetails {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Route Details")
                                            .font(.system(size: 11))
                                            .foregroundStyle(LocalTheme.textSecondary)
                                        Text(route)
                                            .font(.system(size: 12))
                                            .foregroundStyle(LocalTheme.textPrimary)
                                            .lineLimit(2)
                                    }
                                    .padding(.top, 2)
                                }

                                if let note = nextTrip.notes {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("Instructions")
                                            .font(.system(size: 11))
                                            .foregroundStyle(LocalTheme.textSecondary)
                                        Text(note)
                                            .font(.system(size: 12))
                                            .foregroundStyle(LocalTheme.textPrimary)
                                            .lineLimit(2)
                                    }
                                    .padding(.top, 2)
                                }

                                // Vehicle info row
                                if let vehicle = assignedVehicle {
                                    HStack(spacing: 8) {
                                        Image(systemName: "truck.box.fill")
                                            .foregroundStyle(LocalTheme.accent)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(vehicle.displayName)
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(LocalTheme.textPrimary)
                                            Text(vehicle.plateNumber)
                                                .font(.system(size: 10))
                                                .foregroundStyle(LocalTheme.textSecondary)
                                        }
                                    }
                                }

                                // Action buttons row
                                HStack(spacing: 10) {
                                    // View Route button
                                    NavigationLink(destination: TripDetailView(trip: nextTrip).environment(appViewModel)) {
                                        HStack(spacing: 5) {
                                            Image(systemName: "map")
                                                .font(.system(size: 11, weight: .semibold))
                                            Text("View Route")
                                                .font(.system(size: 13, weight: .semibold))
                                        }
                                        .foregroundStyle(LocalTheme.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 9)
                                        .background(
                                            RoundedRectangle(cornerRadius: 10)
                                                .fill(LocalTheme.cardBackground)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(LocalTheme.textSecondary.opacity(0.3), lineWidth: 1)
                                                )
                                        )
                                    }
                                    .buttonStyle(.plain)

                                    // Start Trip button (gate: inspect first)
                                    Button {
                                        let inspDone = currentUser.flatMap {
                                            appViewModel.service.todayInspection(for: $0.id)
                                        } != nil
                                        if inspDone {
                                            appViewModel.service.startScheduledTrip(id: nextTrip.id)
                                            driverVM.showToastMessage("Trip started! Have a safe journey 🚛")
                                        } else {
                                            tripToStart = nextTrip
                                            showTripInspectionSheet = true
                                        }
                                    } label: {
                                        Text("Start Trip")
                                            .font(.system(size: 13, weight: .bold))
                                            .foregroundStyle(.white)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 9)
                                            .background(
                                                RoundedRectangle(cornerRadius: 10)
                                                    .fill(LocalTheme.accent)
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.top, 4)

                                // Inspection status pill
                                let inspDone = currentUser.flatMap {
                                    appViewModel.service.todayInspection(for: $0.id)
                                } != nil
                                HStack(spacing: 5) {
                                    Image(systemName: inspDone ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(inspDone ? LocalTheme.successGreen : .orange)
                                    Text(inspDone ? "Pre-trip inspection complete ✓" : "Pre-trip inspection required — tap Start Trip")
                                        .font(.system(size: 10))
                                        .foregroundStyle(inspDone ? LocalTheme.successGreen : .orange)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(
                                    Capsule().fill(inspDone ? LocalTheme.successGreen.opacity(0.1) : Color.orange.opacity(0.1))
                                )
                            }
                        }
                    } else {
                        CustomDarkCard {
                            Text("No upcoming trips assigned")
                                .font(.system(size: 15))
                                .foregroundStyle(LocalTheme.textSecondary)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("ACTIVE_TRIP_CARD")
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick actions")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(LocalTheme.textPrimary)

            HStack(spacing: 12) {
                // Action 1: Inspection — FIX: use "clipboard.fill" (available iOS 14+)
                /*
                let inspectionDone = currentUser.flatMap { appViewModel.service.todayInspection(for: $0.id) } != nil
                if inspectionDone {
                    NavigationLink(destination: InspectionsView()) {
                        quickActionItem(icon: "clipboard.fill", label: "Inspection", isSOS: false)
                    }
                    .buttonStyle(.plain)
                } else {
                    NavigationLink(destination: PreTripInspectionView()) {
                        quickActionItem(icon: "clipboard.fill", label: "Inspection", isSOS: false)
                    }
                    .buttonStyle(.plain)
                }
                */

                // Action 2: Start/Resume Trip
                if let user = currentUser, let activeTrip = appViewModel.service.activeTrip(for: user.id) {
                    NavigationLink(destination: TripDetailView(trip: activeTrip)) {
                        quickActionItem(icon: "map.fill", label: "Resume Trip", isSOS: false)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        let inspectionDone = currentUser.flatMap { appViewModel.service.todayInspection(for: $0.id) } != nil
                        if inspectionDone {
                            if let user = currentUser {
                                let scheduled = appViewModel.service.upcomingTrips(for: user.id)
                                if let firstScheduled = scheduled.first {
                                    appViewModel.service.startScheduledTrip(id: firstScheduled.id)
                                    driverVM.showToastMessage("Trip started! Have a safe journey 🚛")
                                } else if let vehicle = assignedVehicle {
                                    appViewModel.service.startTrip(driverID: user.id, vehicleID: vehicle.id, origin: "Current Location", destination: "Destination")
                                    driverVM.showToastMessage("Trip started! Have a safe journey 🚛")
                                } else {
                                    driverVM.showToastMessage("No vehicle assigned")
                                }
                            }
                        } else {
                            // Show inspection sheet — not just a toast
                            if let user = currentUser {
                                tripToStart = appViewModel.service.upcomingTrips(for: user.id).first
                            }
                            showTripInspectionSheet = true
                        }
                    } label: {
                        quickActionItem(icon: "map.fill", label: "Start Trip", isSOS: false)
                    }
                    .buttonStyle(.plain)
                }

                // Action 3: Break Log
                Button {
                    driverVM.showBreakLogSheet = true
                } label: {
                    quickActionItem(icon: "cup.and.saucer.fill", label: "Break Log", isSOS: false)
                }
                .buttonStyle(.plain)

                // Action 4: SOS
                Button {
                    driverVM.startSOSCountdown(service: appViewModel.service, user: currentUser)
                } label: {
                    quickActionItem(icon: "", label: "SOS", isSOS: true)
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityIdentifier("QUICK_ACTION_BUTTON")
    }

    private func quickActionItem(icon: String, label: String, isSOS: Bool) -> some View {
        VStack(spacing: 8) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LocalTheme.cardBackground)
                    .frame(height: 72)

                if isSOS {
                    Text("SOS")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(LocalTheme.criticalRed)
                        )
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundStyle(LocalTheme.textPrimary.opacity(0.85))
                }
            }

            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(LocalTheme.textSecondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Today's Stats Section

    private var todayDistanceValue: Int {
        guard let user = currentUser else { return 148 }
        let trips = appViewModel.service.trips.filter { $0.driverID == user.id }
        let total = trips.reduce(0.0) { $0 + $1.distanceKM }
        return total > 0 ? Int(total) : 148
    }

    private var todayFuelAmountValue: Int {
        guard let user = currentUser else { return 2400 }
        let receipts = appViewModel.service.fuelReceipts(for: user.id)
        let total = receipts.reduce(0.0) { $0 + $1.amount }
        return total > 0 ? Int(total) : 2400
    }

    private var todayTripsCountValue: Int {
        guard let user = currentUser else { return 2 }
        let trips = appViewModel.service.trips.filter { $0.driverID == user.id }
        return trips.isEmpty ? 2 : trips.count
    }

    private var todayStatsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's stats")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(LocalTheme.textPrimary)

            // FIX: wrap in card with dividers for clear separation
            HStack(spacing: 0) {
                // Column 1: Distance
                VStack(alignment: .center, spacing: 4) {
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("\(todayDistanceValue)")
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(LocalTheme.textPrimary)
                        Text("km")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(LocalTheme.textSecondary)
                    }
                    Text("Distance")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(LocalTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color(UIColor { t in
                        t.userInterfaceStyle == .dark
                            ? UIColor.white.withAlphaComponent(0.12)
                            : UIColor.separator
                    }))
                    .frame(width: 1, height: 40)

                // Column 2: Fuel
                VStack(alignment: .center, spacing: 4) {
                    Text("₹\(todayFuelAmountValue)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(LocalTheme.textPrimary)
                    Text("Fuel")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(LocalTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color(UIColor { t in
                        t.userInterfaceStyle == .dark
                            ? UIColor.white.withAlphaComponent(0.12)
                            : UIColor.separator
                    }))
                    .frame(width: 1, height: 40)

                // Column 3: Trips
                VStack(alignment: .center, spacing: 4) {
                    Text("\(todayTripsCountValue)")
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(LocalTheme.textPrimary)
                    Text("Trips")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(LocalTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.vertical, 18)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(LocalTheme.cardBackground)
            )
        }
    }

    // MARK: - Toast Banner

    private func toastBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(LocalTheme.successGreen)
            Text(message)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(LocalTheme.textPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(LocalTheme.cardBackground)
                .shadow(color: Color.black.opacity(0.15), radius: 8)
        )
        .padding(.top, 8)
    }

    // MARK: - Reported Defects Section

    private var reportedDefectsSection: some View {
        let driverDefects = appViewModel.service.defects.filter { $0.driverID == currentUser?.id }
        
        return VStack(alignment: .leading, spacing: 12) {
            if !driverDefects.isEmpty {
                Text("Reported Issues & Repairs")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(LocalTheme.textPrimary)
                
                VStack(spacing: 12) {
                    ForEach(driverDefects) { defect in
                        CustomDarkCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(defect.title ?? "Issue Report")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundStyle(LocalTheme.textPrimary)
                                        
                                        Text(defect.reportedDate.formatted(date: .abbreviated, time: .shortened))
                                            .font(.system(size: 11))
                                            .foregroundStyle(LocalTheme.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    // Status tag
                                    defectStatusTag(defect.status)
                                }
                                
                                Text(defect.description)
                                    .font(.system(size: 13))
                                    .foregroundStyle(LocalTheme.textSecondary)
                                    .lineLimit(2)
                                
                                // Show assigned maintenance technician if approved / inRepair
                                if let linkedWO = appViewModel.service.workOrders.first(where: { $0.defectReportID == defect.id }) {
                                    HStack {
                                        if let tech = appViewModel.service.users(for: .maintenance).first(where: { $0.id == linkedWO.assignedMaintenanceID }) {
                                            Label("Tech: \(tech.name)", systemImage: "wrench.and.screwdriver")
                                                .font(.system(size: 12, weight: .semibold))
                                                .foregroundStyle(LocalTheme.accent)
                                        }
                                        
                                        Spacer()
                                        
                                        // Open chat coordination thread shortcut
                                        NavigationLink(destination: WorkOrderChatView(workOrderID: linkedWO.id).environment(appViewModel)) {
                                            HStack(spacing: 4) {
                                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                                Text("Open Chat")
                                            }
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(Capsule().fill(LocalTheme.accent))
                                        }
                                        .buttonStyle(.plain)
                                    }
                                    .padding(.top, 4)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func defectStatusTag(_ status: DefectStatus) -> some View {
        let (text, bgColor, textColor): (String, Color, Color) = {
            switch status {
            case .pending:
                return ("Pending Review", Color.gray.opacity(0.15), Color.gray)
            case .approved:
                return ("Approved", Color.blue.opacity(0.15), Color.blue)
            case .inRepair:
                return ("In Repair", LocalTheme.accent.opacity(0.15), LocalTheme.accent)
            case .completed:
                return ("Completed", LocalTheme.successGreen.opacity(0.15), LocalTheme.successGreen)
            }
        }()
        
        return Text(text)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(RoundedRectangle(cornerRadius: 6).fill(bgColor))
    }
}

// MARK: - Custom Card View (adaptive light/dark)

struct CustomDarkCard<Content: View>: View {
    let content: Content

    private static var adaptiveCardFill: Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: 0.110, green: 0.110, blue: 0.129, alpha: 1) // #1C1C21
                : UIColor.secondarySystemBackground
        })
    }

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Self.adaptiveCardFill)
            )
    }
}

// MARK: - Shift Progress Ring

private struct ShiftProgressRing: View {
    let progress: Double
    let size: CGFloat
    let strokeWidth: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            // Track — subtle in both modes
            Circle()
                .stroke(
                    colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.10),
                    lineWidth: strokeWidth
                )

            // Progress Arc
            Circle()
                .trim(from: 0, to: CGFloat(min(progress, 1.0)))
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "FD5D23"), Color(hex: "FF7A45")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Thumb indicator at the end of the progress arc
            GeometryReader { geometry in
                let radius = geometry.size.width / 2
                let angle = Angle(degrees: (progress * 360) - 90)
                let x = radius + radius * cos(CGFloat(angle.radians))
                let y = radius + radius * sin(CGFloat(angle.radians))

                Circle()
                    .fill(Color.white)
                    .frame(width: strokeWidth * 1.5, height: strokeWidth * 1.5)
                    .overlay(
                        Circle()
                            .stroke(Color(hex: "FD5D23"), lineWidth: 2)
                    )
                    .position(x: x, y: y)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Break Log Sheet

struct BreakLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel: AppViewModel
    @State private var breakType = "Tea Break"
    let breakTypes = ["Tea Break", "Lunch Break", "Rest Break", "Personal Break"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(DriverTheme.accent)

                Text("Log a Break")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(DriverTheme.textPrimary)

                Picker("Break Type", selection: $breakType) {
                    ForEach(breakTypes, id: \.self) { type in
                        Text(type).tag(type)
                    }
                }
                .pickerStyle(.wheel)

                Button("Start Break") {
                    if let user = appViewModel.currentUser {
                        appViewModel.service.addBreakLog(driverID: user.id, breakType: breakType)
                    }
                    dismiss()
                }
                .buttonStyle(DriverAccentButtonStyle())
                .padding(.horizontal, 20)

                Spacer()
            }
            .padding(.top, 40)
            .navigationTitle("Break Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Vehicle Alert Detail Sheet

struct VehicleAlertDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel: AppViewModel
    let alert: VehicleAlert

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(alert.severity == .critical ? DriverTheme.criticalRed : DriverTheme.warningAmber)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(alert.alertType.rawValue)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(DriverTheme.textPrimary)
                        Text(alert.severity.rawValue)
                            .font(.system(size: 13))
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                }

                DriverGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Issue Description")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DriverTheme.textPrimary)
                        Text(alert.alertDescription)
                            .font(.system(size: 15))
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                }

                DriverGlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recommended Action")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DriverTheme.textPrimary)
                        Text(alert.recommendedAction)
                            .font(.system(size: 15))
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                }

                Button("Contact Maintenance") {
                    dismiss()
                }
                .buttonStyle(DriverAccentButtonStyle())

                Button("Acknowledge") {
                    appViewModel.service.acknowledgeAlert(alert)
                    dismiss()
                }
                .buttonStyle(DriverAccentButtonStyle(isDestructive: false))

                Spacer()
            }
            .padding(20)
            .navigationTitle("Vehicle Alert")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DriverDashboardView()
            .environment(AppViewModel())
            .environment(DriverViewModel())
    }
}
