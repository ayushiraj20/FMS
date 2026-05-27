import SwiftUI

struct FleetManagerDashboardView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var viewModel = FleetManagerDashboardViewModel()
    @State private var selectedStat: KPIStat?
    @State private var showBroadcast = false
    @State private var isFlashingSOS = false
    
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
            appViewModel.refreshSOSAlerts()
        }
        .onAppear {
            appViewModel.refreshSOSAlerts()
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
                    NavigationLink(destination: PriorityAlertsListView()) {
                        Text("See All")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.brand)
                    }
                    .buttonStyle(.plain)
                }
                
                HStack {
                    NavigationLink(destination: PriorityAlertDetailView(category: "SOS Alerts", count: sosCount)) {
                        alertIconItem(icon: "exclamationmark.triangle.fill", categoryColor: Color(red: 1, green: 0.25, blue: 0.3), count: sosCount, label: "SOS Alerts")
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    NavigationLink(destination: PriorityAlertDetailView(category: "Critical", count: criticalCount)) {
                        alertIconItem(icon: "bell.badge.fill", categoryColor: Color(red: 1, green: 0.45, blue: 0.1), count: criticalCount, label: "Critical")
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    NavigationLink(destination: PriorityAlertDetailView(category: "Maintenance", count: maintenanceCount)) {
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Live Fleet Map")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                NavigationLink(destination: FleetMapFullView(service: appViewModel.service)) {
                    Text("See All")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.brand)
                }
            }
            
            FleetMapPreview(locations: appViewModel.service.nearbyFleetLocations())
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
        // Compute values here, outside @ViewBuilder, so all child views can see them
        let total     = appViewModel.service.vehicles.count
        let activeCount = appViewModel.service.vehicles.filter { $0.status == .active }.count
        let idleCount   = appViewModel.service.vehicles.filter { $0.status == .idle }.count
        let maintCount  = appViewModel.service.vehicles.filter { $0.status == .inService }.count
        let activePct = total > 0 ? Int(Double(activeCount) / Double(total) * 100) : 0
        let idlePct   = total > 0 ? Int(Double(idleCount)   / Double(total) * 100) : 0
        let maintPct  = total > 0 ? Int(Double(maintCount)  / Double(total) * 100) : 0
        let fillTo    = total > 0 ? 0.1 + 0.8 * Double(activePct) / 100.0 : 0.1

        return GlassCard {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text("Fleet Utilization")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
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
                                .trim(from: 0.1, to: fillTo)
                                .stroke(AngularGradient(gradient: Gradient(colors: [.green, .orange]), center: .center, startAngle: .degrees(90), endAngle: .degrees(90 + 360)), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                .rotationEffect(.degrees(90))
                                .frame(width: 90, height: 90)
                            
                            Text("\(activePct)%")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        
                        Text("Fleet Utilization")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    
                    // Stats
                    VStack(spacing: 12) {
                        utilizationRow(color: .green, label: "Active",      value: activePct)
                        utilizationRow(color: .orange, label: "Idle",       value: idlePct)
                        utilizationRow(color: .red,    label: "Maintenance", value: maintPct)
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
            
            Text("\(value)")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
                .frame(width: 35, alignment: .trailing)
        }
    }
    
    // MARK: - Needs Attention
    private var needsAttentionSection: some View {
        let maintenanceDue = appViewModel.service.maintenanceSchedules
            .filter { $0.status == .upcoming && $0.dueDate < Date().addingTimeInterval(86400 * 7) }.count
        let overdueServices = appViewModel.service.maintenanceSchedules
            .filter { $0.status == .overdue }.count
        let lostGPS = appViewModel.service.vehicles
            .filter { $0.status == .active }.count  // placeholder – replace with real GPS-loss logic
        
        return GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Needs Attention")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                HStack(spacing: 12) {
                    needsAttentionCard(count: maintenanceDue, label: "Maintenance\nDue", color: Color("AccentColor"))
                    needsAttentionCard(count: overdueServices, label: "Overdue\nServices", color: Color("AccentColor"))
                    needsAttentionCard(count: lostGPS, label: "Lost\nGPS Feed", color: Color("AccentColor"))
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

    // MARK: - Premium SOS Overlay Banner Helper
    private func emergencyAlertBanner(for alert: SOSAlert) -> some View {
        return GlassCard {
            HStack(spacing: 16) {
                // Pulsing red danger indicator
                Circle()
                    .fill(Color.red)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(Color.red, lineWidth: 4)
                            .scaleEffect(isFlashingSOS ? 2.0 : 1.0)
                            .opacity(isFlashingSOS ? 0.0 : 1.0)
                    )
                    .onAppear {
                        withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) {
                            isFlashingSOS = true
                        }
                    }
                
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text("🚨 ACTIVE EMERGENCY")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.red, in: Capsule())
                        
                        Text(alert.emergencyType.uppercased())
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.red)
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text("Driver:")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.textSecondary)
                            Text(alert.driverName)
                                .font(.subheadline.bold())
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        
                        HStack(spacing: 4) {
                            Text("Vehicle:")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.textSecondary)
                            Text(alert.vehicleNumber)
                                .font(.subheadline.bold())
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        
                        HStack(spacing: 4) {
                            Text("Location:")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.textSecondary)
                            Text("Live GPS (\(alert.latitude), \(alert.longitude))")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.brand)
                        }
                        
                        HStack(spacing: 4) {
                            Text("Time:")
                                .font(.caption.bold())
                                .foregroundStyle(AppTheme.textSecondary)
                            Text(alert.createdAt, style: .time)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    NavigationLink(destination: PriorityAlertDetailView(category: "SOS Alerts", count: 1)) {
                        Text("Show Location")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.red, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    
                    Button {
                        // Persist dismissal – this ID will never trigger the banner again,
                        // even after app restart or re-login.
                        appViewModel.dismissSOSAlert(alert.id)
                    } label: {
                        Text("Resolve")
                            .font(.caption.bold())
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.green, in: RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
        }
        .transition(.asymmetric(insertion: .move(edge: .top).combined(with: .opacity), removal: .opacity))
    }
}

#Preview {
    NavigationStack {
        FleetManagerDashboardView()
            .environment(AppViewModel())
    }
}
