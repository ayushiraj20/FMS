import SwiftUI

// MARK: - iOS 26 Native Design Overhaul
struct DriverDashboardView: View {
    @Environment(AppViewModel.self) private var appViewModel: AppViewModel
    @Environment(DriverViewModel.self) private var driverVM: DriverViewModel

    // Pre-trip inspection gate
    @State private var showTripInspectionSheet = false
    @State private var tripToStart: Trip? = nil
    @State private var showTripEndInspectionSheet = false
    @State private var tripToEnd: Trip? = nil
    @State private var defectChatID: UUID? = nil
    @State private var fuelTransactions: [FuelTransaction] = []

    private var currentUser: User? { appViewModel.currentUser }
    private var assignedVehicle: Vehicle? { appViewModel.assignedVehicle }

    var body: some View {
        @Bindable var driverVM = driverVM
        
        ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    if driverVM.isLoading {
                        ProgressView("Loading iOS 26 Dashboard...")
                            .frame(maxWidth: .infinity, minHeight: 300)
                    } else {
                        greetingRow
                        vehicleAlertBanner
                        vehicleAndShiftRow
                        activeTripWidget
                        quickActionsSection
                        carbonScoreSection
                        todayStatsSection
                        reportedDefectsSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .background(DriverTheme.background.ignoresSafeArea())
            .refreshable {
                driverVM.isLoading = true
                await appViewModel.service.syncWithDatabase()
                await driverVM.load()
                await appViewModel.loadNotifications()
                await loadFuelTransactions()
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        DriverProfileView()
                            .environment(appViewModel)
                            .environment(driverVM)
                    } label: {
                        AvatarView(
                            name: currentUser?.name ?? "Driver",
                            size: 36,
                            customColor: DriverTheme.accent
                        )
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.identity)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 8) {
                        NavigationLink(destination: BroadcastInboxView()) {
                            Image(systemName: "megaphone.fill")
                                .imageScale(.large)
                                .frame(width: 32, height: 32)
                        }
                        .buttonStyle(.plain)
                        
                        NavigationLink(destination: NotificationsView()) {
                            NotificationToolbarIcon()
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .foregroundStyle(DriverTheme.accent)
                    .glassEffect(.identity)
                }
            }

            .task {
                await appViewModel.service.syncWithDatabase()
                await driverVM.load()
                await appViewModel.loadNotifications()
                await loadFuelTransactions()
            }
            .sheet(isPresented: $driverVM.showFuelReceiptSheet) {
                FuelReceiptView()
                    .environment(appViewModel)
                    .environment(driverVM)
                    .registersSheetPresentation()
            }
            .sheet(isPresented: $driverVM.showBreakLogSheet) {
                TripBreakLogSheet(trip: currentUser.flatMap { appViewModel.service.activeTrip(for: $0.id) })
                    .environment(appViewModel)
                    .registersSheetPresentation()
            }
            .sheet(item: $driverVM.showAlertDetail) { alert in
                VehicleAlertDetailSheet(alert: alert)
                    .environment(appViewModel)
                    .registersSheetPresentation()
            }
            .sheet(isPresented: $showTripInspectionSheet) {
                TripStartInspectionSheet(trip: tripToStart) {
                    driverVM.showToastMessage("Trip started. Have a safe journey.")
                }
                .environment(appViewModel)
                .environment(driverVM)
                .registersSheetPresentation()
            }
            .sheet(isPresented: $showTripEndInspectionSheet) {
                TripStartInspectionSheet(trip: tripToEnd, inspectionType: .postTrip) {
                    driverVM.showToastMessage("Trip ended successfully.")
                }
                .environment(appViewModel)
                .environment(driverVM)
                .registersSheetPresentation()
            }
            .overlay(alignment: .top) {
                if driverVM.showToast, let message = driverVM.toastMessage {
                    toastBanner(message)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: driverVM.showToast)
                }
        }
    }

    // MARK: - Greeting Row
    @ViewBuilder
    private var greetingRow: some View {
        @Bindable var driverVM = driverVM
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date().formatted(date: .complete, time: .omitted).uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(DriverTheme.textSecondary)
                Text("Hello, \(driverVM.driverFirstName(currentUser))")
                    .font(.system(.largeTitle, design: .rounded).bold())
                    .foregroundStyle(DriverTheme.textPrimary)
            }
            Spacer()

            if let user = currentUser {
                let isOnDuty = appViewModel.service.dutyStatus(for: user.id) == .onDuty
                Button {
                    driverVM.showDutyToggleAlert = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: isOnDuty ? "record.circle" : "moon.zzz.fill")
                            .foregroundStyle(isOnDuty ? DriverTheme.successGreen : .gray)
                            .symbolEffect(.pulse, isActive: isOnDuty)
                        Text(isOnDuty ? "On Duty" : "Off Duty")
                            .font(.system(.caption, design: .rounded).bold())
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial, in: Capsule())
                }
                .alert("Change Duty Status", isPresented: $driverVM.showDutyToggleAlert) {
                    Button("Confirm") {
                        appViewModel.service.toggleDutyStatus(for: user.id)
                        appViewModel.refreshCurrentUser()
                    }
                    Button("Cancel", role: .cancel) { }
                } message: {
                    let newStatus = appViewModel.service.dutyStatus(for: user.id) == .onDuty ? "Off Duty" : "On Duty"
                    Text("Switch to \(newStatus)?")
                }
            }
        }
    }

    // MARK: - Vehicle Alert Banner
    @ViewBuilder
    private var vehicleAlertBanner: some View {
        if let vehicleID = assignedVehicle?.id, let firstAlert = appViewModel.service.alerts(for: vehicleID).first {
            Button {
                driverVM.showAlertDetail = firstAlert
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(firstAlert.severity == .critical ? DriverTheme.criticalRed : DriverTheme.warningAmber)
                        .symbolEffect(.bounce, options: .repeating)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(firstAlert.alertType.rawValue)
                            .font(.system(.callout, design: .rounded).bold())
                            .foregroundStyle(DriverTheme.textPrimary)
                        Text(firstAlert.recommendedAction)
                            .font(.caption)
                            .foregroundStyle(DriverTheme.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(firstAlert.severity == .critical ? DriverTheme.criticalRed.opacity(0.5) : DriverTheme.warningAmber.opacity(0.5), lineWidth: 1))
            }
        }
    }

    // MARK: - Vehicle & Shift Cards
    private var vehicleAndShiftRow: some View {
        HStack(spacing: 16) {
            // Vehicle Card
            NavigationLink {
                if assignedVehicle != nil {
                    DriverVehicleTripDetailView()
                        .environment(appViewModel)
                        .environment(driverVM)
                }
            } label: {
                VStack(alignment: .leading, spacing: 8) {
                    ZStack(alignment: .center) {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(DriverTheme.accent.opacity(0.1))
                            .frame(height: 56)
                        Image(systemName: "truck.box.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(DriverTheme.accent)
                            .opacity(0.6)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(assignedVehicle?.plateNumber ?? "No Vehicle")
                                .font(.system(.headline, design: .rounded))
                            if let vehicle = assignedVehicle {
                                Circle().fill(vehicle.status == .active ? DriverTheme.successGreen : .gray).frame(width: 8, height: 8)
                            }
                        }
                        Text(assignedVehicle?.displayName ?? "Requires Assignment")
                            .font(.caption)
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(assignedVehicle == nil)

            // Shift Card
            NavigationLink {
                DriverShiftDetailView()
                    .environment(appViewModel)
                    .environment(driverVM)
            } label: {
                VStack(spacing: 12) {
                    Text("Shift Progress")
                        .font(.system(.caption, design: .rounded).bold())
                        .foregroundStyle(DriverTheme.textSecondary)
                    
                    let shift = currentUser.flatMap { appViewModel.service.currentShift(for: $0.id) }
                    let shiftProgress = shift?.progress ?? 0.0
                    
                    ZStack {
                        CircularProgressRing(progress: shiftProgress, size: 70, strokeWidth: 8)
                        Text(shift != nil ? "\(Int(shiftProgress * 100))%" : "--")
                            .font(.system(.title3, design: .rounded).bold())
                    }
                    
                    Text(shift != nil ? "\(String(format: "%.1f", shift!.remainingHours))h left" : "No active shift")
                        .font(.caption2)
                        .foregroundStyle(DriverTheme.textSecondary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Active Trip Widget (iOS 26 Style)
    private var activeTripWidget: some View {
        Group {
            if let user = currentUser, let activeTrip = appViewModel.service.activeTrip(for: user.id) {
                NavigationLink(destination: TripDetailView(trip: activeTrip).environment(appViewModel)) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Label("Active Trip", systemImage: "map.fill")
                                .font(.system(.subheadline, design: .rounded).bold())
                                .foregroundStyle(DriverTheme.accent)
                            Spacer()
                            Text("IN PROGRESS")
                                .font(.system(.caption2, design: .rounded).bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(DriverTheme.successGreen.opacity(0.2), in: Capsule())
                                .foregroundStyle(DriverTheme.successGreen)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(activeTrip.origin) → \(activeTrip.destination)")
                                .font(.system(.title3, design: .rounded).bold())
                        }
                        
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Started").font(.caption2).foregroundStyle(DriverTheme.textSecondary)
                                Text(activeTrip.startDate.formatted(date: .omitted, time: .shortened)).font(.subheadline.bold())
                            }
                            Spacer()
                            VStack(alignment: .leading) {
                                Text("Est. End").font(.caption2).foregroundStyle(DriverTheme.textSecondary)
                                Text(activeTrip.endDate?.formatted(date: .omitted, time: .shortened) ?? "--:--").font(.subheadline.bold())
                            }
                            Spacer()
                            VStack(alignment: .leading) {
                                Text("Distance").font(.caption2).foregroundStyle(DriverTheme.textSecondary)
                                Text("\(Int(activeTrip.distanceKM)) km").font(.subheadline.bold())
                            }
                        }
                        
                        HStack {
                            Spacer()
                            Text("View Live Map")
                                .font(.system(.subheadline, design: .rounded).bold())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(DriverTheme.accent, in: Capsule())
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .fill(.ultraThinMaterial)
                            .shadow(color: DriverTheme.accent.opacity(0.1), radius: 12, x: 0, y: 8)
                    )
                }
                .buttonStyle(.plain)
            } else if let user = currentUser, let nextTrip = appViewModel.service.upcomingTrips(for: user.id).first {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label("Upcoming Trip", systemImage: "calendar.badge.clock")
                            .font(.system(.subheadline, design: .rounded).bold())
                            .foregroundStyle(DriverTheme.textSecondary)
                        Spacer()
                    }
                    
                    Text("\(nextTrip.origin) → \(nextTrip.destination)")
                        .font(.system(.title3, design: .rounded).bold())
                    
                    HStack(spacing: 12) {
                        NavigationLink(destination: TripDetailView(trip: nextTrip).environment(appViewModel)) {
                            Text("Details")
                                .font(.system(.subheadline, design: .rounded).bold())
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        
                        Button {
                            let inspDone = appViewModel.service.todayInspection(for: user.id) != nil
                            if inspDone {
                                appViewModel.service.startScheduledTrip(id: nextTrip.id)
                                driverVM.showToastMessage("Trip started! Have a safe journey 🚛")
                            } else {
                                tripToStart = nextTrip
                                showTripInspectionSheet = true
                            }
                        } label: {
                            Text("Start Trip")
                                .font(.system(.subheadline, design: .rounded).bold())
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(DriverTheme.accent, in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    let inspDone = appViewModel.service.todayInspection(for: user.id) != nil
                    Label(inspDone ? "Pre-trip inspection complete" : "Pre-trip inspection required", systemImage: inspDone ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .font(.caption.bold())
                        .foregroundStyle(inspDone ? DriverTheme.successGreen : DriverTheme.warningAmber)
                }
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Button { driverVM.startSOSCountdown(service: appViewModel.service, user: currentUser) } label: {
                HStack(spacing: 8) {
                    Image(systemName: "light.beacon.max.fill")
                        .font(.title2)
                    Text("SOS Emergency")
                        .font(.system(.headline, design: .rounded).bold())
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(DriverTheme.criticalRed, in: Capsule())
            }
            .buttonStyle(.plain)

            NavigationLink {
                DriverManagerChatView()
                    .environment(appViewModel)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "message.fill")
                        .font(.title3)
                    Text("Message Fleet Manager")
                        .font(.system(.headline, design: .rounded).bold())
                }
                .foregroundStyle(DriverTheme.accent)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(DriverTheme.accent.opacity(0.22), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    private func quickActionTile(icon: String, label: String, color: Color) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.2))
                    .frame(width: 60, height: 60)
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
            }
            Text(label)
                .font(.system(.caption, design: .rounded).bold())
        }
        .frame(width: 90)
        .padding(.vertical, 16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .scrollTransition { content, phase in
            content
                .scaleEffect(phase.isIdentity ? 1 : 0.9)
                .opacity(phase.isIdentity ? 1 : 0.7)
        }
    }

    // MARK: - Carbon Score Section
    @ViewBuilder
    private var carbonScoreSection: some View {
        if let user = currentUser {
            let summary = CarbonEfficiencyAnalytics.driverSummary(
                driverID: user.id,
                trips: appViewModel.service.trips,
                fuelReceipts: appViewModel.service.fuelReceipts,
                fuelTransactions: fuelTransactions
            )

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Eco Score", systemImage: "leaf.fill")
                            .font(.system(.title2, design: .rounded).bold())
                            .foregroundStyle(DriverTheme.textPrimary)
                        Text("Monthly fuel efficiency and carbon impact")
                            .font(.caption)
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                    Spacer()
                    Text(summary.grade.rawValue)
                        .font(.system(size: 34, weight: .black, design: .rounded))
                        .foregroundStyle(gradeTint(summary.grade))
                        .frame(width: 58, height: 58)
                        .background(gradeTint(summary.grade).opacity(0.14), in: Circle())
                }

                HStack(spacing: 10) {
                    ecoMetric(title: "Efficiency", value: efficiencyText(summary.efficiencyKMPerLitre), icon: "speedometer", tint: DriverTheme.successGreen)
                    ecoMetric(title: "CO₂", value: carbonText(summary.carbonKG), icon: "cloud.fill", tint: Color(UIColor.systemBlue))
                    ecoMetric(title: "Distance", value: "\(Int(summary.distanceKM.rounded())) km", icon: "road.lanes", tint: DriverTheme.accent)
                }

                if let lastTrip = summary.lastTrip {
                    HStack(spacing: 12) {
                        Image(systemName: "flag.checkered")
                            .foregroundStyle(DriverTheme.accent)
                            .frame(width: 34, height: 34)
                            .background(DriverTheme.accent.opacity(0.14), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Last trip")
                                .font(.caption.bold())
                                .foregroundStyle(DriverTheme.textSecondary)
                            Text(lastTrip.route)
                                .font(.system(.subheadline, design: .rounded).bold())
                                .foregroundStyle(DriverTheme.textPrimary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(efficiencyText(lastTrip.efficiencyKMPerLitre))
                            .font(.system(.subheadline, design: .rounded).bold())
                            .foregroundStyle(DriverTheme.successGreen)
                    }
                    .padding(12)
                    .background(DriverTheme.cardFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Text("Log fuel against trips to unlock last-trip efficiency.")
                        .font(.caption)
                        .foregroundStyle(DriverTheme.textSecondary)
                }
            }
            .padding(16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(DriverTheme.successGreen.opacity(0.22), lineWidth: 1)
            )
        }
    }

    private func ecoMetric(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(tint)
            Text(value)
                .font(.system(.headline, design: .rounded).bold())
                .foregroundStyle(DriverTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            Text(title)
                .font(.caption)
                .foregroundStyle(DriverTheme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(DriverTheme.cardFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func loadFuelTransactions() async {
        guard let user = currentUser, SupabaseConfig.isConfigured else {
            fuelTransactions = []
            return
        }
        do {
            let repo = FuelRepository(service: FuelService(client: SupabaseService.shared.client))
            fuelTransactions = try await repo.transactionsForDriver(user.id)
        } catch {
            fuelTransactions = []
            print("[Carbon] Driver fuel transactions unavailable: \(error)")
        }
    }

    private func efficiencyText(_ value: Double?) -> String {
        guard let value else { return "-- km/L" }
        return "\(String(format: "%.1f", value)) km/L"
    }

    private func carbonText(_ kg: Double) -> String {
        if kg >= 1000 {
            return "\(String(format: "%.1f", kg / 1000)) t"
        }
        return "\(Int(kg.rounded())) kg"
    }

    private func gradeTint(_ grade: CarbonGrade) -> Color {
        switch grade {
        case .a: return DriverTheme.successGreen
        case .b: return DriverTheme.accent
        case .c: return DriverTheme.warningAmber
        case .d: return DriverTheme.criticalRed
        }
    }

    // MARK: - Today's Stats Section
    private var todayStatsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Today's Overview")
                .font(.system(.title2, design: .rounded).bold())
            
            HStack(spacing: 12) {
                statBox(title: "Distance", value: "\(todayDistanceValue)", unit: "km")
                statBox(title: "Fuel", value: "₹\(todayFuelAmountValue)", unit: "")
                statBox(title: "Trips", value: "\(todayTripsCountValue)", unit: "")
            }
        }
    }
    
    private func statBox(title: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DriverTheme.textSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(.title2, design: .rounded).bold())
                if !unit.isEmpty {
                    Text(unit).font(.caption.bold()).foregroundStyle(DriverTheme.textSecondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }

    private var todayDistanceValue: Int {
        guard let user = currentUser else { return 0 }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let trips = appViewModel.service.trips.filter {
            guard $0.driverID == user.id else { return false }
            if $0.startDate >= today { return true }
            if $0.status == .completed, let endDate = $0.endDate {
                return calendar.isDate(endDate, inSameDayAs: .now)
            }
            return false
        }
        return Int(trips.reduce(0.0) { $0 + $1.distanceKM })
    }

    private var todayFuelAmountValue: Int {
        guard let user = currentUser else { return 0 }
        let today = Calendar.current.startOfDay(for: .now)
        let receipts = appViewModel.service.fuelReceipts(for: user.id).filter {
            $0.date >= today
        }
        return Int(receipts.reduce(0.0) { $0 + $1.amount })
    }

    private var todayTripsCountValue: Int {
        guard let user = currentUser else { return 0 }
        let today = Calendar.current.startOfDay(for: .now)
        let trips = appViewModel.service.trips.filter {
            $0.driverID == user.id && $0.startDate >= today
        }
        return trips.count
    }

    // MARK: - Reported Defects Section
    private var reportedDefectsSection: some View {
        let driverDefects = appViewModel.service.defects.filter { $0.driverID == currentUser?.id }
        
        return VStack(alignment: .leading, spacing: 16) {
            if !driverDefects.isEmpty {
                Text("Reported Issues")
                    .font(.system(.title2, design: .rounded).bold())
                
                ForEach(driverDefects) { defect in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(defect.title ?? "Issue Report")
                                    .font(.headline)
                                Text(defect.reportedDate.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(DriverTheme.textSecondary)
                            }
                            Spacer()
                            defectStatusTag(defect.status)
                        }
                        
                        Text(defect.description)
                            .font(.subheadline)
                            .foregroundStyle(DriverTheme.textSecondary)
                            .lineLimit(2)
                        
                        // Chat button
                        Button {
                            defectChatID = defect.id
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "bubble.left.and.bubble.right.fill")
                                    .font(.caption)
                                Text("Chat with Manager")
                                    .font(.caption.bold())
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(DriverTheme.accent, in: Capsule())
                        }
                    }
                    .padding()
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { defectChatID != nil },
            set: { if !$0 { defectChatID = nil } }
        )) {
            if let chatDefectID = defectChatID {
                NavigationStack {
                    WorkOrderChatView(defectReportID: chatDefectID)
                        .environment(appViewModel)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { defectChatID = nil }
                            }
                        }
                }
            }
        }
    }
    
    private func defectStatusTag(_ status: DefectStatus) -> some View {
        let (text, color): (String, Color) = {
            switch status {
            case .pending: return ("Pending", .gray)
            case .approved: return ("Approved", .blue)
            case .inRepair: return ("In Repair", DriverTheme.accent)
            case .completed: return ("Completed", DriverTheme.successGreen)
            }
        }()
        
        return Text(text)
            .font(.caption.bold())
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.15), in: Capsule())
    }

    private func toastBanner(_ message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .foregroundStyle(DriverTheme.successGreen)
                .symbolEffect(.bounce)
            Text(message)
                .font(.system(.subheadline, design: .rounded).bold())
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial, in: Capsule())
        .shadow(radius: 10)
        .padding(.top, 16)
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
            VStack(spacing: 30) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(DriverTheme.accent)
                    .symbolEffect(.bounce, options: .repeating)

                Text("Log a Break")
                    .font(.system(.largeTitle, design: .rounded).bold())

                Picker("Break Type", selection: $breakType) {
                    ForEach(breakTypes, id: \.self) { Text($0).tag($0) }
                }
                .pickerStyle(.wheel)
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))

                Button("Start Break") {
                    if let user = appViewModel.currentUser {
                        appViewModel.service.addBreakLog(driverID: user.id, breakType: breakType)
                    }
                    dismiss()
                }
                .buttonStyle(DriverAccentButtonStyle())

                Spacer()
            }
            .padding(24)
            .background(DriverTheme.background.ignoresSafeArea())
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
            VStack(alignment: .leading, spacing: 24) {
                HStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(alert.severity == .critical ? DriverTheme.criticalRed : DriverTheme.warningAmber)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(alert.alertType.rawValue)
                            .font(.system(.title, design: .rounded).bold())
                        Text(alert.severity.rawValue.uppercased())
                            .font(.caption.bold())
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Description").font(.headline)
                    Text(alert.alertDescription).foregroundStyle(DriverTheme.textSecondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Action Required").font(.headline)
                    Text(alert.recommendedAction).foregroundStyle(DriverTheme.textSecondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))

                Spacer()

                Button("Acknowledge") {
                    appViewModel.service.acknowledgeAlert(alert)
                    dismiss()
                }
                .buttonStyle(DriverAccentButtonStyle())
            }
            .padding(24)
            .background(DriverTheme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
