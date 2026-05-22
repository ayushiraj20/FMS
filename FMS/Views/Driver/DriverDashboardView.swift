import SwiftUI

struct DriverDashboardView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @EnvironmentObject private var driverVM: DriverViewModel

    private var currentUser: User? { appViewModel.currentUser }
    private var assignedVehicle: Vehicle? { appViewModel.service.vehicle(for: currentUser?.assignedVehicleID) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
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
                    inspectionStatusSection
                    fuelReceiptSection
                    upcomingTripsSection
                }
            }
            .padding(20)
        }
        .background(DriverTheme.background.ignoresSafeArea())
        .refreshable {
            driverVM.isLoading = true
            await driverVM.load()
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await driverVM.load()
        }
        .sheet(isPresented: $driverVM.showProfileSheet) {
            DriverProfileView()
                .environmentObject(appViewModel)
                .environmentObject(driverVM)
        }
        .sheet(isPresented: $driverVM.showFuelReceiptSheet) {
            FuelReceiptView()
                .environmentObject(appViewModel)
                .environmentObject(driverVM)
        }
        .sheet(isPresented: $driverVM.showBreakLogSheet) {
            BreakLogSheet()
                .environmentObject(appViewModel)
        }
        .sheet(item: $driverVM.showAlertDetail) { alert in
            VehicleAlertDetailSheet(alert: alert)
                .environmentObject(appViewModel)
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
            // Profile Avatar Button
            Button {
                driverVM.showProfileSheet = true
            } label: {
                ZStack {
                    Circle()
                        .fill(DriverTheme.accent)
                        .frame(width: 44, height: 44)
                    Text(driverVM.driverInitials(currentUser))
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .accessibilityIdentifier("PROFILE_BUTTON")

            Spacer()

            // Bell Button
            NavigationLink(destination: NotificationsView()) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(DriverTheme.elevatedCard)
                        .overlay(Circle().stroke(DriverTheme.cardBorder, lineWidth: 0.5))
                        .shadow(color: DriverTheme.cardShadow, radius: 4)
                        .frame(width: 44, height: 44)

                    Image(systemName: "bell.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(DriverTheme.accent)
                        .frame(width: 44, height: 44)

                    if appViewModel.unreadNotificationsCount > 0 {
                        Circle()
                            .fill(DriverTheme.criticalRed)
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

    private var greetingRow: some View {
        HStack(alignment: .top) {
            Text("Hello, \(driverVM.driverFirstName(currentUser))")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(DriverTheme.textPrimary)

            Spacer()

            if let user = currentUser {
                let isOnDuty = appViewModel.service.dutyStatus(for: user.id) == .onDuty
                Button {
                    driverVM.showDutyToggleAlert = true
                } label: {
                    StatusBadge(
                        title: isOnDuty ? "On Duty" : "Off Duty",
                        color: isOnDuty ? DriverTheme.successGreen : Color.gray,
                        icon: isOnDuty ? "circle.fill" : "moon.fill"
                    )
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
                            .fill(firstAlert.severity == .critical ? DriverTheme.criticalRed : DriverTheme.warningAmber)
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
            DriverGlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    // Vehicle image placeholder
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DriverTheme.cardFill)
                        .frame(height: 90)
                        .overlay(
                            Image(systemName: "truck.box.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(DriverTheme.accent.opacity(0.6))
                        )

                    if let vehicle = assignedVehicle {
                        HStack(spacing: 6) {
                            Text(vehicle.plateNumber)
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(DriverTheme.textPrimary)

                            Circle()
                                .fill(vehicle.status == .active ? DriverTheme.successGreen : Color.gray)
                                .frame(width: 8, height: 8)
                        }

                        Text(vehicle.displayName)
                            .font(.system(size: 13))
                            .foregroundStyle(DriverTheme.textSecondary)
                    } else {
                        Text("No Vehicle")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                }
            }
            .accessibilityIdentifier("VEHICLE_CARD")

            // Shift Card
            DriverGlassCard {
                VStack(spacing: 8) {
                    Text("Today's Shift")
                        .font(.system(size: 13))
                        .foregroundStyle(DriverTheme.textSecondary)

                    if let user = currentUser, let shift = appViewModel.service.currentShift(for: user.id) {
                        Text("\(shift.startTime.formatted(date: .omitted, time: .shortened)) - \(shift.endTime.formatted(date: .omitted, time: .shortened))")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DriverTheme.textPrimary)

                        ZStack {
                            CircularProgressRing(
                                progress: shift.progress,
                                size: 80,
                                strokeWidth: 8
                            )

                            VStack(spacing: 2) {
                                Text("\(Int(shift.progress * 100))%")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(DriverTheme.textPrimary)
                            }
                        }

                        Text("\(String(format: "%.1f", shift.remainingHours))h remaining")
                            .font(.system(size: 13))
                            .foregroundStyle(DriverTheme.textSecondary)
                    } else {
                        Text("No shift today")
                            .font(.system(size: 13))
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .accessibilityIdentifier("SHIFT_CARD")
        }
    }

    // MARK: - Active Trip Card

    private var activeTripCard: some View {
        DriverGlassCard {
            if let user = currentUser, let trip = appViewModel.service.activeTrip(for: user.id) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Trip")
                        .font(.system(size: 13))
                        .foregroundStyle(DriverTheme.textSecondary)

                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trip.destination)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(DriverTheme.textPrimary)

                            Text("ETA")
                                .font(.system(size: 13))
                                .foregroundStyle(DriverTheme.textSecondary)

                            Text("2:15 PM")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(DriverTheme.textPrimary)
                        }

                        Spacer()

                        NavigationLink(destination: TripDetailView(trip: trip)) {
                            Text("Resume Trip")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(DriverTheme.accent))
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Active Trip")
                        .font(.system(size: 13))
                        .foregroundStyle(DriverTheme.textSecondary)

                    HStack {
                        Text("No active trip")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(DriverTheme.textPrimary)

                        Spacer()

                        let inspectionDone = currentUser.flatMap { appViewModel.service.todayInspection(for: $0.id) } != nil

                        Button("Start Trip") {
                            if inspectionDone {
                                if let user = currentUser {
                                    let scheduled = appViewModel.service.upcomingTrips(for: user.id)
                                    if let firstScheduled = scheduled.first {
                                        appViewModel.service.startScheduledTrip(id: firstScheduled.id)
                                        driverVM.showToastMessage("Trip started successfully")
                                    } else if let vehicleID = user.assignedVehicleID {
                                        appViewModel.service.startTrip(driverID: user.id, vehicleID: vehicleID, origin: "Mumbai", destination: "Pune Warehouse")
                                        driverVM.showToastMessage("Trip started successfully")
                                    } else {
                                        driverVM.showToastMessage("No vehicle assigned to start trip")
                                    }
                                }
                            } else {
                                driverVM.showToastMessage("Complete inspection first")
                            }
                        }
                        .buttonStyle(DriverPillButtonStyle(fillColor: inspectionDone ? DriverTheme.accent : Color.gray))
                        .disabled(!inspectionDone)
                    }
                }
            }
        }
        .accessibilityIdentifier("ACTIVE_TRIP_CARD")
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DriverTheme.textPrimary)

            HStack(spacing: 12) {
                // Break Log
                Button {
                    driverVM.showBreakLogSheet = true
                } label: {
                    quickActionButton(icon: "cup.and.saucer.fill", label: "Break Log", isSpecial: false)
                }

                // SOS
                Button {
                    driverVM.startSOSCountdown(service: appViewModel.service, user: currentUser)
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.shield.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white)
                        Text("SOS")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 72)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(DriverTheme.criticalRed)
                    )
                }
            }
        }
        .accessibilityIdentifier("QUICK_ACTION_BUTTON")
    }

    private func quickActionButton(icon: String, label: String, isSpecial: Bool) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(DriverTheme.accent)

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(DriverTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 72)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DriverTheme.elevatedCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(DriverTheme.cardBorder, lineWidth: 0.5)
                )
                .shadow(color: DriverTheme.cardShadow, radius: 4)
        )
    }

    // MARK: - Inspection Status

    private var inspectionStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pre-Trip Inspection")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DriverTheme.textPrimary)

                Spacer()

                if let user = currentUser {
                    let done = appViewModel.service.todayInspection(for: user.id) != nil
                    StatusBadge(
                        title: done ? "Completed" : "Pending",
                        color: done ? DriverTheme.successGreen : DriverTheme.warningAmber,
                        icon: done ? "checkmark.circle.fill" : "clock.fill"
                    )
                }
            }

            DriverGlassCard {
                if let user = currentUser, let inspection = appViewModel.service.todayInspection(for: user.id) {
                    // Completed
                    NavigationLink(destination: InspectionsView()) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(DriverTheme.successGreen)

                            VStack(alignment: .leading, spacing: 4) {
                                let passedCount = inspection.items.filter(\.isChecked).count
                                let failedCount = inspection.items.count - passedCount
                                Text("\(passedCount) passed, \(failedCount) failed")
                                    .font(.system(size: 15))
                                    .foregroundStyle(DriverTheme.textPrimary)

                                Text("View Report")
                                    .font(.system(size: 13))
                                    .foregroundStyle(DriverTheme.textSecondary)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DriverTheme.textSecondary)
                        }
                    }
                    .buttonStyle(.plain)
                } else {
                    // Not done
                    VStack(spacing: 12) {
                        Image(systemName: "clipboard.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(DriverTheme.accent)

                        NavigationLink(destination: PreTripInspectionView()) {
                            Text("Start Inspection")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Capsule().fill(DriverTheme.accent))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .accessibilityIdentifier("INSPECTION_STATUS_CARD")
    }

    // MARK: - Fuel Receipt

    private var fuelReceiptSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Fuel Receipts")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DriverTheme.textPrimary)

                Spacer()

                Button("See All") { }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(DriverTheme.accent)

                Button {
                    driverVM.showFuelReceiptSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(DriverTheme.accent)
                }
            }

            if let user = currentUser, let receipt = appViewModel.service.fuelReceipts(for: user.id).first {
                DriverGlassCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(receipt.date.formatted(date: .abbreviated, time: .omitted))
                                .font(.system(size: 13))
                                .foregroundStyle(DriverTheme.textSecondary)
                            Text(receipt.stationName)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(DriverTheme.textPrimary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(String(format: "%.1f", receipt.litres)) L")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(DriverTheme.textPrimary)
                            Text("₹\(String(format: "%.0f", receipt.amount))")
                                .font(.system(size: 13))
                                .foregroundStyle(DriverTheme.textSecondary)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier("FUEL_RECEIPT_CARD")
    }

    // MARK: - Upcoming Trips

    private var upcomingTripsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Upcoming Trips")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DriverTheme.textPrimary)

            if let user = currentUser {
                let upcoming = appViewModel.service.upcomingTrips(for: user.id)
                if upcoming.isEmpty {
                    DriverGlassCard {
                        Text("No upcoming trips scheduled")
                            .font(.system(size: 15))
                            .foregroundStyle(DriverTheme.textSecondary)
                            .frame(maxWidth: .infinity)
                    }
                } else {
                    ForEach(upcoming) { trip in
                        NavigationLink(destination: TripDetailView(trip: trip)) {
                            upcomingTripCard(trip)
                        }
                    }
                }
            }
        }
    }

    private func upcomingTripCard(_ trip: Trip) -> some View {
        DriverGlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Trip")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DriverTheme.accent)

                    Spacer()

                    StatusBadge(
                        title: trip.status.rawValue,
                        color: trip.status == .scheduled ? Color.gray : DriverTheme.accent,
                        icon: "circle.fill"
                    )
                }

                Text(trip.destination)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DriverTheme.textPrimary)

                HStack(spacing: 4) {
                    Text(trip.origin)
                        .foregroundStyle(DriverTheme.textSecondary)
                    Image(systemName: "arrow.right")
                        .font(.system(size: 10))
                        .foregroundStyle(DriverTheme.textSecondary)
                    Text(trip.destination)
                        .foregroundStyle(DriverTheme.textSecondary)
                }
                .font(.system(size: 13))

                HStack(spacing: 16) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                        Text(trip.startDate.formatted(date: .abbreviated, time: .shortened))
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(DriverTheme.textSecondary)

                    HStack(spacing: 4) {
                        Image(systemName: "road.lanes")
                            .font(.system(size: 12))
                        Text("\(Int(trip.distanceKM)) km")
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(DriverTheme.textSecondary)
                }
            }
        }
        .accessibilityIdentifier("UPCOMING_TRIP_CARD")
    }

    // MARK: - Toast

    private func toastBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(DriverTheme.successGreen)
            Text(message)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DriverTheme.textPrimary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(DriverTheme.elevatedCard)
                .shadow(color: DriverTheme.cardShadow, radius: 8)
        )
        .padding(.top, 8)
    }
}

// MARK: - Break Log Sheet

struct BreakLogSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel
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
    @EnvironmentObject private var appViewModel: AppViewModel
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
                    // Navigate to chat
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
            .environmentObject(AppViewModel())
            .environmentObject(DriverViewModel())
    }
}
