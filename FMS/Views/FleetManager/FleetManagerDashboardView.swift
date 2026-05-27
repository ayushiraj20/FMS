
import SwiftUI

struct FleetManagerDashboardView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var viewModel = FleetManagerDashboardViewModel()
    @State private var selectedStat: KPIStat?
    @State private var showBroadcast = false
    @State private var geofenceBreaches: [FleetGeofenceBreach] = []
    @State private var openedPriorityAlertCategories: Set<String> = []
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if viewModel.isLoading {
                        LoadingStateView(title: "Loading live fleet KPIs...")
                            .frame(height: 280)
                    } else {
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
            NavigationLink(destination: AIPredictionDashboardView()) {
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
                NavigationLink(destination: ProfileSettingsView()) {
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
                NavigationLink(destination: NotificationsView()) {
                    Image(systemName: "bell.fill")
                }
                .buttonStyle(.plain)
                .glassEffect(.identity)
            }
        }
        .task {
            await viewModel.load()
            refreshGeofenceMonitoring()
        }
        .onAppear {
            refreshGeofenceMonitoring()
        }
        .sheet(
            isPresented:
            $showBroadcast
        ) {

            BroadcastComposeView()
        }
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
                NavigationLink(destination: destinationView(for: stat)) {
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
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Priority Alerts")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    NavigationLink(destination: PriorityAlertsListView()) {
                        Text("See All")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.brand)
                    }
                    .buttonStyle(.plain)
                }
                
                HStack {
                    NavigationLink(destination: priorityAlertDestination(category: "SOS Alerts", count: 5)) {
                        alertIconItem(
                            icon: "exclamationmark.triangle.fill",
                            categoryColor: Color(red: 1, green: 0.25, blue: 0.3),
                            count: priorityAlertBadgeCount(for: "SOS Alerts", count: 5),
                            label: "SOS Alerts"
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    NavigationLink(destination: priorityAlertDestination(category: "Critical", count: 3)) {
                        alertIconItem(
                            icon: "bell.badge.fill",
                            categoryColor: Color(red: 1, green: 0.45, blue: 0.1),
                            count: priorityAlertBadgeCount(for: "Critical", count: 3),
                            label: "Critical"
                        )
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    NavigationLink(destination: priorityAlertDestination(category: "Maintenance", count: 2)) {
                        alertIconItem(
                            icon: "wrench.and.screwdriver.fill",
                            categoryColor: Color(red: 0.35, green: 0.6, blue: 1),
                            count: priorityAlertBadgeCount(for: "Maintenance", count: 2),
                            label: "Maintenance"
                        )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
            }
        }
    }

    private func priorityAlertBadgeCount(for category: String, count: Int) -> Int {
        openedPriorityAlertCategories.contains(category) ? 0 : count
    }

    private func priorityAlertDestination(category: String, count: Int) -> some View {
        PriorityAlertDetailView(category: category, count: count)
            .onAppear {
                openedPriorityAlertCategories.insert(category)
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
    @ViewBuilder
    private var liveFleetMapSection: some View {
        let geofence = appViewModel.service.fleetGeofence(for: appViewModel.currentUser)
        let previewLocations = appViewModel.service.fleetMapPreviewLocations(for: appViewModel.currentUser)

        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Live Fleet Map")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                NavigationLink(destination: FleetMapFullView(service: appViewModel.service, manager: appViewModel.currentUser)) {
                    Text("See All")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.brand)
                }
            }

            FleetGeofenceStatusBanner(geofence: geofence, breaches: geofenceBreaches)
            
            FleetMapPreview(
                locations: previewLocations,
                initialRegion: FleetMapRegion.region(for: geofence),
                geofence: geofence,
                geofenceBreaches: geofenceBreaches
            )
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 0.5)
                )

            if let breach = geofenceBreaches.first {
                geofenceBreachSummary(breach)
            }
        }
    }

    private func geofenceBreachSummary(_ breach: FleetGeofenceBreach) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.error)
                .frame(width: 32, height: 32)
                .background(AppTheme.error.opacity(0.12), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("\(breach.location.vehicle.displayName) · \(breach.location.vehicle.plateNumber)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text("\(breach.location.driverText) · \(breach.location.locality) · \(breach.distanceText)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(12)
        .background(AppTheme.error.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(AppTheme.error.opacity(0.25), lineWidth: 1)
        )
    }
    
    // MARK: - Fleet Utilization
    private var fleetUtilizationSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Fleet Utilization")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
//                    Button { } label: {
//                        Text("See All")
//                            .font(.subheadline.weight(.medium))
//                            .foregroundStyle(AppTheme.brand)
//                    }
                    NavigationLink(destination: FleetUtilizationDetailView()) {
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
                                .trim(from: 0.1, to: 0.1 + (0.8 * CGFloat(appViewModel.service.overallUtilization) / 100.0))
                                .stroke(AngularGradient(gradient: Gradient(colors: [.green, .orange]), center: .center, startAngle: .degrees(90), endAngle: .degrees(90 + 360)), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                .rotationEffect(.degrees(90))
                                .frame(width: 90, height: 90)
                            
                            Text("\(appViewModel.service.overallUtilization)%")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        
                        Text("Fleet Utilization")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    
                    // Stats
                    VStack(spacing: 12) {
                        utilizationRow(color: .green, label: "Active", value: appViewModel.service.utilizationActivePercentage)
                        utilizationRow(color: .orange, label: "Idle", value: appViewModel.service.utilizationIdlePercentage)
                        utilizationRow(color: .red, label: "Maintenance", value: appViewModel.service.utilizationMaintenancePercentage)
                    }
                }
            }
        }
    }
    
    private func utilizationRow(color: Color, label: String, value: Int) -> some View {
        HStack(spacing: 8) {
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
                        .frame(width: geometry.size.width * CGFloat(value) / 100.0, height: 6)
                }
            }
            .frame(height: 6)
            
            Text("\(value)%")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 45, alignment: .trailing)
        }
    }
    
    // MARK: - Needs Attention
    private var needsAttentionSection: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Needs Attention")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                HStack(spacing: 12) {
                    needsAttentionCard(count: appViewModel.service.maintenanceDueCount, label: "Maintenance\nDue", color: Color("AccentColor"))
                    needsAttentionCard(count: appViewModel.service.overdueServicesCount, label: "Overdue\nServices", color: Color("AccentColor"))
                    needsAttentionCard(count: appViewModel.service.lostGPSCount, label: "Lost\nGPS Feed", color: Color("AccentColor"))
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
            
            NavigationLink(destination: AssignDriverView(service: appViewModel.service)) {
                quickLink(title: "Assign Driver", subtitle: "Pair available vehicles & drivers", icon: "person.badge.key.fill")
            }
            
            NavigationLink(destination: DefectReportsListView().environment(appViewModel)) {
                quickLink(title: "Defect Reports", subtitle: "Review & approve driver defect reports", icon: "exclamationmark.triangle.fill")
            }
        }
    }
    
    // MARK: - Pending Defect Banner
    @ViewBuilder
    private var pendingDefectBanner: some View {
        let pendingCount = appViewModel.service.defects.filter { $0.status == .pending }.count
        if pendingCount > 0 {
            NavigationLink(destination: DefectReportsListView().environment(appViewModel)) {
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
    private func refreshGeofenceMonitoring() {
        let breaches = appViewModel.service.geofenceBreaches(for: appViewModel.currentUser)
        geofenceBreaches = breaches
        appViewModel.service.sendGeofenceBreachAlerts(breaches, manager: appViewModel.currentUser)
        appViewModel.notifications = appViewModel.service.notifications(for: appViewModel.currentUser)
    }

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
    
    private var notificationBadge: some View {
        ZStack {
            Image(systemName: "bell.fill")
                .font(.title3)
                .foregroundStyle(AppTheme.textPrimary)
                
            if appViewModel.unreadNotificationsCount > 0 {
                Text(appViewModel.unreadNotificationsCount > 10 ? "10+" : "\(appViewModel.unreadNotificationsCount)")
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, appViewModel.unreadNotificationsCount > 10 ? 4 : 0)
                    .frame(minWidth: 18, minHeight: 18)
                    .background(AppTheme.error)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule().stroke(Color.white, lineWidth: 1.5)
                    )
                    .offset(x: 10, y: -10)
                    .zIndex(1)
            }
        }
        .frame(width: 44, height: 44)
    }
}

#Preview {
    NavigationStack {
        FleetManagerDashboardView()
            .environment(AppViewModel())
    }
}
