import SwiftUI
import MapKit

struct FleetManagerDashboardView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var viewModel = FleetManagerDashboardViewModel()
    @State private var selectedStat: KPIStat?
    @State private var showBroadcast = false
    @State private var isFlashingSOS = false
    @State private var showResolveConfirmation = false
    @State private var pendingResolveAlertID: UUID?
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if viewModel.isLoading {
                        LoadingStateView(title: "Loading live fleet KPIs...")
                            .frame(height: 280)
                    } else {
                        if let activeSOS = appViewModel.activeEmergencyAlert {
                            emergencyAlertBanner(for: activeSOS)
                        }
                        
                        // MARK: - KPI Grid
                        kpiGrid
                        

                        // MARK: - Priority Alerts
                        alertsSection
                        
                        // MARK: - Live Fleet Map
                        liveFleetMapSection
                        
                        // MARK: - Fleet Utilization
                        fleetUtilizationSection
                        
                        // MARK: - Needs Attention
                        needsAttentionSection
                        
                        // MARK: - Quick Access
                        quickAccessSection
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 80)
            }
            
            // MARK: - FAB
            NavigationLink(destination: AIPredictionDashboardView().hideTabBarOnPush()) {
                Image(systemName: "sparkles")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(
                        Circle()
                            .fill(AppTheme.brand)
                            .shadow(color: AppTheme.brand.opacity(0.4), radius: 12, x: 0, y: 6)
                    )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 20)
            .padding(.bottom, 24)
        }
        .background(AppTheme.background)
        .navigationTitle("Fleet Manager")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink(destination: ProfileSettingsView().hideTabBarOnPush()) {
                    AvatarView(name: appViewModel.currentUser?.name ?? "FM", size: 36)
                }
                .buttonStyle(.plain)
                .glassEffect(.identity)
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showBroadcast = true
                } label: {
                    Image(systemName: "megaphone.fill")
                }
                .buttonStyle(.plain)
                .glassEffect(.identity)
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: NotificationsView().hideTabBarOnPush()) {
                    NotificationToolbarIcon()
                }
                .buttonStyle(.plain)
                .glassEffect(.identity)
            }
        }
        .task {
            await appViewModel.service.syncWithDatabase()
            await viewModel.load()
            await appViewModel.loadNotifications()
            sendRouteGeofenceAlertsIfNeeded()
            appViewModel.refreshSOSAlerts()
        }
        .onAppear {
            appViewModel.refreshSOSAlerts()
            Task {
                await appViewModel.service.syncWithDatabase()
                await appViewModel.loadNotifications()
                sendRouteGeofenceAlertsIfNeeded()
            }
        }
        .refreshable {
            await appViewModel.service.syncWithDatabase()
            await appViewModel.loadNotifications()
            sendRouteGeofenceAlertsIfNeeded()
            appViewModel.refreshSOSAlerts()
        }
        .sheet(isPresented: $showBroadcast) {
            BroadcastComposeView()
                .registersSheetPresentation()
        }
        .hidesTabBarWhileSheet(isPresented: showBroadcast)
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Operations Overview")
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
            }
        .padding(.top, 8)
    }
    
    // MARK: - KPI Grid
    private var kpiGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            ForEach(viewModel.stats(service: appViewModel.service)) { stat in
                NavigationLink(destination: destinationView(for: stat).hideTabBarOnPush()) {
                    StatCardView(stat: stat)
                }
                .buttonStyle(.plain)
//                Button {
//                    selectedStat = stat
//                } label: {
//                    StatCardView(stat: stat)
//                }
//                .buttonStyle(.plain)
            }
        }
//        .sheet(item: $selectedStat) { stat in
//            NavigationStack {
//                destinationView(for: stat)
//                    .toolbar {
//                        ToolbarItem(placement: .topBarTrailing) {
//                            Button("Close") {
//                                selectedStat = nil
//                            }
//                        }
//                    }
//            }
//            .presentationDetents([.medium, .large])
//        }
    }
    
    
    @ViewBuilder
    private func destinationView(for stat: KPIStat) -> some View {
        switch stat.title {

        case "Active Vehicles":
            ActiveVehiclesDetailView(
                vehicles: appViewModel.service.vehicles
            )

        case "Fuel Spend":
            FuelTransactionsListView(
                repo: FuelRepository(
                    service: FuelService(
                        client: SupabaseService.shared.client
                    )
                )
            )

        case "Open Work Orders":
            WorkOrderManagementView(
                service: appViewModel.service,
                currentOrgID: appViewModel.currentOrganization?.id
            )

        case "Expiring Documents":
            ExpiringDocumentsDetailView()

        default:
            EmptyView()
        }
    }
    
    
    // MARK: - Priority Alerts
    private var alertsSection: some View {
        let sosCount = appViewModel.service.sosAlerts.filter { $0.status == "ACTIVE" }.count
        let criticalCount = appViewModel.service.workOrders.filter { $0.priority == .critical && $0.status != .completed }.count
        let maintenanceCount = appViewModel.service.maintenanceSchedules.filter { $0.status == .overdue }.count

        return GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Priority Alerts")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    NavigationLink(destination: PriorityAlertsListView().hideTabBarOnPush()) {
                        Text("See All")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.brand)
                    }
                    .buttonStyle(.plain)
                }
                
                HStack {
                    NavigationLink(destination: PriorityAlertDetailView(category: "SOS Alerts", count: sosCount).hideTabBarOnPush()) {
                        alertIconItem(icon: "exclamationmark.triangle.fill", categoryColor: Color(red: 1, green: 0.25, blue: 0.3), count: sosCount, label: "SOS Alerts")
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    NavigationLink(destination: PriorityAlertDetailView(category: "Critical", count: criticalCount).hideTabBarOnPush()) {
                        alertIconItem(icon: "bell.badge.fill", categoryColor: Color(red: 1, green: 0.45, blue: 0.1), count: criticalCount, label: "Critical")
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    NavigationLink(destination: PriorityAlertDetailView(category: "Maintenance", count: maintenanceCount).hideTabBarOnPush()) {
                        alertIconItem(icon: "wrench.and.screwdriver.fill", categoryColor: Color(red: 0.35, green: 0.6, blue: 1), count: maintenanceCount, label: "Maintenance")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
            }
        }
    }
    
    private func alertIconItem(icon: String, categoryColor: Color, count: Int, label: String) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(categoryColor.opacity(0.12))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(categoryColor)
                    )
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 18, height: 18)
                        .background(Circle().fill(categoryColor))
                        .overlay(
                            Circle()
                                .stroke(AppTheme.cardBackground, lineWidth: 1.5)
                        )
                        .offset(x: 4, y: -4)
                }
            }
            
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .multilineTextAlignment(.center)
        }
        .frame(width: 84)
        .padding(.vertical, 8)
    }
    
    // MARK: - Live Fleet Map
    private var liveFleetMapSection: some View {
        let locations = appViewModel.service.fleetMapPreviewLocations(for: appViewModel.currentUser)
        let breaches = appViewModel.service.routeGeofenceBreaches(for: appViewModel.currentUser, locations: locations)
        var mapCoordinates = locations.map(\.coordinate)
        for tripID in locations.compactMap(\.activeTrip?.id) {
            if let plan = appViewModel.service.tripRoutePlansByTripID[tripID] {
                mapCoordinates.append(contentsOf: plan.allRoutes.flatMap { $0 })
            }
        }

        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Live Fleet Map")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                NavigationLink(destination: FleetMapFullView(service: appViewModel.service, manager: appViewModel.currentUser).hideTabBarOnPush()) {
                    Text("See All")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.brand)
                }
            }
            
            FleetMapPreview(
                locations: locations,
                service: appViewModel.service,
                initialRegion: FleetMapRegion.region(for: mapCoordinates),
                routeBreaches: breaches
            )
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 0.5)
                )
        }
    }
    
    // MARK: - Fleet Utilization
    private var fleetUtilizationSection: some View {
        let summary = appViewModel.service.fleetUtilizationSummary()
        let fillTo = summary.totalVehicles > 0
            ? 0.1 + 0.8 * Double(summary.averageUtilization) / 100.0
            : 0.1

        return GlassCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Fleet Utilization")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    NavigationLink(destination: FleetUtilizationDetailView().hideTabBarOnPush()) {
                        Text("See All")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.brand)
                    }
                }
                
                HStack(spacing: 24) {
                    // Gauge
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .trim(from: 0.1, to: 0.9)
                                .stroke(AppTheme.surfaceSecondary, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                .rotationEffect(.degrees(90))
                                .frame(width: 90, height: 90)
                            
                            Circle()
                                .trim(from: 0.1, to: fillTo)
                                .stroke(AppTheme.success, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                .rotationEffect(.degrees(90))
                                .frame(width: 90, height: 90)
                            
                            Text("\(summary.averageUtilization)%")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        
                        Text("Fleet Utilization")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    
                    // Stats
                    VStack(spacing: 12) {
                        utilizationRow(color: AppTheme.success, label: "Active", count: summary.activeVehicles, total: summary.totalVehicles)
                        utilizationRow(color: AppTheme.warning, label: "Idle", count: summary.idleVehicles, total: summary.totalVehicles)
                        utilizationRow(color: Color(UIColor.systemBlue), label: "Mainte-\nnance", count: summary.maintenanceVehicles, total: summary.totalVehicles)
                    }
                }
            }
        }
    }
    
    private func utilizationRow(color: Color, label: String, count: Int, total: Int) -> some View {
        let barFraction: CGFloat = total > 0 ? CGFloat(count) / CGFloat(total) : 0

        return HStack(spacing: 8) {
            Circle()
                .fill(color)
                .frame(width: 6, height: 6)
            
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 85, alignment: .leading)
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.surfaceSecondary)
                        .frame(height: 6)
                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * barFraction, height: 6)
                }
            }
            .frame(height: 6)
            
            Text("\(count)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
                .frame(width: 35, alignment: .trailing)
        }
    }
    
    // MARK: - Needs Attention
    private var needsAttentionSection: some View {
        let vehicleIDsWithOpenWork = Set(appViewModel.service.workOrders
            .filter { $0.status != .completed }
            .map(\.vehicleID))
        let vehiclesInMaintenance = appViewModel.service.vehicles
            .filter { $0.status == .inService || vehicleIDsWithOpenWork.contains($0.id) }
            .count
        let overdueServices = appViewModel.service.maintenanceSchedules
            .filter { $0.status == .overdue }.count
        let lostOrOffline = appViewModel.service.vehicles
            .filter { $0.status == .outOfService }.count
        
        return GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Needs Attention")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                HStack(spacing: 12) {
                    needsAttentionCard(count: vehiclesInMaintenance, label: "In\nMaintenance", color: AppTheme.warning)
                    needsAttentionCard(count: overdueServices, label: "Overdue\nServices", color: AppTheme.error)
                    needsAttentionCard(count: lostOrOffline, label: "Lost /\nOffline", color: Color(UIColor.systemBlue))
                }
            }
        }
    }
    
    private func needsAttentionCard(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 6) {
            Text("\(count)")
                .font(.title.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(color.opacity(0.1))
        )
    }
    
    // MARK: - Quick Access
    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Quick Access", subtitle: "Navigate to key management modules")
            
            NavigationLink(destination: AssignDriverView(service: appViewModel.service, organizationID: appViewModel.currentOrganization?.id).hideTabBarOnPush()) {
                quickLink(title: "Assign Driver", subtitle: "Pair available vehicles & drivers", icon: "person.badge.key.fill")
            }
            
            NavigationLink(destination: DefectReportsListView().environment(appViewModel).hideTabBarOnPush()) {
                quickLink(title: "Defect Reports", subtitle: "Review & approve driver defect reports", icon: "exclamationmark.triangle.fill")
            }

            NavigationLink(destination: FleetReportsAnalyticsView().hideTabBarOnPush()) {
                quickLink(title: "Reports & Analytics", subtitle: "Generate maintenance, fuel, inventory, compliance, and routing reports", icon: "doc.text.fill")
            }
        }
    }
    
    // MARK: - Pending Defect Banner
    @ViewBuilder
    private var pendingDefectBanner: some View {
        let pendingCount = appViewModel.service.defects.filter { $0.status == .pending }.count
        if pendingCount > 0 {
            NavigationLink(destination: DefectReportsListView().environment(appViewModel).hideTabBarOnPush()) {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.warning.opacity(0.18))
                            .frame(width: 44, height: 44)
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(AppTheme.warning)
                            .font(.system(size: 20))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(pendingCount) Pending Defect Report\(pendingCount == 1 ? "" : "s")")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Tap to review and approve driver reports")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.warning)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.warning.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(AppTheme.warning.opacity(0.25), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Helpers
    private var priorityAlerts: [AppNotification] {
        appViewModel.service.notifications(for: appViewModel.currentUser).prefix(3).map { $0 }
    }
    
    private func alertColor(_ category: NotificationCategory) -> Color {
        switch category {

        case .critical:
            return AppTheme.error

        case .warning:
            return AppTheme.warning

        case .success:
            return AppTheme.success

        case .info:
            return AppTheme.brand

        case .maintenance:
            return Color.orange
        }
    }

    private func sendRouteGeofenceAlertsIfNeeded() {
        Task {
            await appViewModel.service.prefetchRoutePlansForActiveTrips()
            let locations = appViewModel.service.allFleetLocations()
            await appViewModel.service.sendRouteGeofenceMonitoringAlerts(
                for: appViewModel.currentUser,
                locations: locations
            )
        }
    }

    private func quickLink(title: String, subtitle: String, icon: String) -> some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(Color("AccentColor"))
                    .frame(width: 42, height: 42)
                    .background(Color("AccentColor").opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .foregroundStyle(AppTheme.textPrimary)
                        .font(.subheadline.weight(.semibold))
                    Text(subtitle)
                        .foregroundStyle(AppTheme.textSecondary)
                        .font(.caption)
                }
                
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
    
    // MARK: - SOS Emergency Banner
    private func emergencyAlertBanner(for alert: SOSAlert) -> some View {
        EmergencyAlertBanner(
            alert: alert,
            driverPhone: appViewModel.service.users.first { $0.id == alert.driverID }?.phone,
            isFlashing: isFlashingSOS,
            onResolve: {
                pendingResolveAlertID = alert.id
                showResolveConfirmation = true
            }
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
                isFlashingSOS = true
            }
        }
        .confirmationDialog(
            "Mark this emergency as resolved?",
            isPresented: $showResolveConfirmation,
            titleVisibility: .visible
        ) {
            Button("Mark Resolved", role: .destructive) {
                if let id = pendingResolveAlertID {
                    appViewModel.dismissSOSAlert(id)
                }
                pendingResolveAlertID = nil
            }
            Button("Keep Active", role: .cancel) {
                pendingResolveAlertID = nil
            }
        } message: {
            Text("The alarm will stop and the banner will be dismissed. The alert will be marked CLOSED.")
        }
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .opacity
        ))
    }
}

// MARK: - Emergency Alert Banner Component

private struct EmergencyAlertBanner: View {
    let alert: SOSAlert
    let driverPhone: String?
    let isFlashing: Bool
    let onResolve: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    private var hasValidGPS: Bool {
        !(alert.latitude == 0 && alert.longitude == 0) &&
        alert.latitude.isFinite && alert.longitude.isFinite
    }

    private var elapsedText: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: alert.createdAt, relativeTo: Date())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            driverBlock
            if let description = alert.description, !description.isEmpty {
                Text(description)
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            actionRow
            footer
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.red.opacity(0.95), Color(red: 0.65, green: 0.05, blue: 0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(isFlashing ? 0.55 : 0.2), lineWidth: 1.5)
        )
        .shadow(color: Color.red.opacity(isFlashing ? 0.55 : 0.25), radius: isFlashing ? 22 : 10, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Active emergency from \(alert.driverName), vehicle \(alert.vehicleNumber), \(alert.emergencyType), \(elapsedText)")
    }

    private var header: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.6), lineWidth: 2)
                    .frame(width: 26, height: 26)
                    .scaleEffect(isFlashing ? 1.8 : 1.0)
                    .opacity(isFlashing ? 0.0 : 0.9)
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(6)
                    .background(Color.white.opacity(0.15), in: Circle())
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("ACTIVE EMERGENCY")
                    .font(.caption.weight(.heavy))
                    .tracking(0.8)
                    .foregroundStyle(.white)
                Text(alert.emergencyType.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Spacer()

            Label(elapsedText, systemImage: "clock.fill")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.15), in: Capsule())
        }
    }

    private var driverBlock: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(alert.driverName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Image(systemName: "truck.box.fill")
                        .font(.caption)
                    Text(alert.vehicleNumber)
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white.opacity(0.9))
            }
            Spacer()
        }
    }

    private var actionRow: some View {
        HStack(spacing: 8) {
            actionButton(
                title: "Call",
                systemImage: "phone.fill",
                isEnabled: driverPhone != nil
            ) {
                guard let phone = driverPhone,
                      let url = URL(string: "tel://\(phone.filter { "0123456789+".contains($0) })") else { return }
                UIApplication.shared.open(url)
            }

            actionButton(
                title: "Text",
                systemImage: "message.fill",
                isEnabled: driverPhone != nil
            ) {
                guard let phone = driverPhone,
                      let url = URL(string: "sms:\(phone.filter { "0123456789+".contains($0) })") else { return }
                UIApplication.shared.open(url)
            }

            actionButton(
                title: "Map",
                systemImage: "map.fill",
                isEnabled: hasValidGPS
            ) {
                openInMaps()
            }
        }
    }

    private func actionButton(
        title: String,
        systemImage: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                Color.white.opacity(isEnabled ? 0.18 : 0.08),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(isEnabled ? 0.3 : 0.1), lineWidth: 1)
            )
            .opacity(isEnabled ? 1 : 0.5)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel("\(title) driver")
    }

    private var footer: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: hasValidGPS ? "location.fill" : "location.slash.fill")
                Text(hasValidGPS
                     ? String(format: "%.4f, %.4f", alert.latitude, alert.longitude)
                     : "Location unavailable")
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
            }
            .foregroundStyle(.white.opacity(0.85))

            Spacer()

            Button(action: onResolve) {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Resolve")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.18), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Mark emergency as resolved")
        }
    }

    private func openInMaps() {
        guard hasValidGPS else { return }
        let location = CLLocation(latitude: alert.latitude, longitude: alert.longitude)
        let item = MKMapItem(location: location, address: nil as MKAddress?)
        item.name = "🚨 \(alert.driverName) — \(alert.vehicleNumber)"
        item.openInMaps(launchOptions: [
            MKLaunchOptionsMapTypeKey: NSNumber(value: MKMapType.standard.rawValue)
        ])
    }
}

#Preview {
    NavigationStack {
        FleetManagerDashboardView()
            .environment(AppViewModel())
    }
}
