import SwiftUI
import MapKit

struct FleetManagerDashboardView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var viewModel = FleetManagerDashboardViewModel()
    @State private var selectedStat: KPIStat?
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // MARK: - Header
                    headerSection
                    
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
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink(destination: ProfileSettingsView()) {
                    AvatarView(name: appViewModel.currentUser?.name ?? "FM", size: 36)
                }
                .buttonStyle(.plain)
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: NotificationsView()) {
                    ZStack {
                        
                        notificationBadge
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            await viewModel.load()
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
            FuelSpendDetailView()

        case "Open Work Orders":
//            WorkOrdersDetailView(
//                service: appViewModel.service,
//                currentOrgID: appViewModel.currentOrganization?.id
//            )
            EmptyView()

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
//                    NavigationLink(destination: NotificationsView()) {
//                        Text("See All")
//                            .font(.subheadline.weight(.semibold))
//                            .foregroundStyle(AppTheme.brand)
//                    }
//                    .buttonStyle(.plain)
                }
                
                HStack(alignment: .top, spacing: 0) {
                    NavigationLink(destination: PriorityAlertDetailView(category: "SOS Alerts", count: 5)) {
                        alertIconItem(icon: "exclamationmark.triangle.fill", color: Color("AccentColor"), count: 5, label: "SOS Alerts")
                    }
                    .buttonStyle(.plain)
                    
                    NavigationLink(destination: PriorityAlertDetailView(category: "Critical", count: 3)) {
                        alertIconItem(icon: "bell.fill", color: Color("AccentColor"), count: 3, label: "Critical")
                    }
                    .buttonStyle(.plain)
                    
                    NavigationLink(destination: PriorityAlertDetailView(category: "Maintenance", count: 2)) {
                        alertIconItem(icon: "wrench.and.screwdriver.fill", color: Color("AccentColor"), count: 2, label: "Maintenance")
                    }
                    .buttonStyle(.plain)
                    
                    NavigationLink(destination: PriorityAlertDetailView(category: "Off-Route", count: 4)) {
                        alertIconItem(icon: "location.slash.fill", color: Color("AccentColor"), count: 4, label: "Off-Route")
                    }
                    .buttonStyle(.plain)
                    
                    NavigationLink(destination: PriorityAlertDetailView(category: "Geofence", count: 1)) {
                        alertIconItem(icon: "mappin.and.ellipse", color: Color("AccentColor"), count: 1, label: "Geofence")
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func alertIconItem(icon: String, color: Color, count: Int, label: String) -> some View {
        VStack(spacing: 8) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(color)
                    .frame(width: 40, height: 40)
                
                if count > 0 {
                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Circle().fill(color))
                        .overlay(
                            Circle()
                                .stroke(AppTheme.cardBackground, lineWidth: 2)
                        )
                        .offset(x: 6, y: -6)
                }
            }
            
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(AppTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Live Fleet Map
    private var liveFleetMapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Live Fleet Map")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                NavigationLink(destination: FleetMapFullView(vehicles: appViewModel.service.vehicles)) {
                    Text("See All")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.brand)
                }
            }
            
            FleetMapPreview(vehicles: appViewModel.service.vehicles)
                .frame(height: 240)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(AppTheme.border, lineWidth: 0.5)
                )
        }
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
                                .trim(from: 0.1, to: 0.1 + (0.8 * 0.78))
                                .stroke(AngularGradient(gradient: Gradient(colors: [.green, .orange]), center: .center, startAngle: .degrees(90), endAngle: .degrees(90 + 360)), style: StrokeStyle(lineWidth: 12, lineCap: .round))
                                .rotationEffect(.degrees(90))
                                .frame(width: 90, height: 90)
                            
                            Text("78%")
                                .font(.title2.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        
                        Text("Fleet Utilization")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    
                    // Stats
                    VStack(spacing: 12) {
                        utilizationRow(color: .green, label: "Active", value: 78)
                        utilizationRow(color: .orange, label: "Idle", value: 15)
                        utilizationRow(color: .red, label: "Maintenance", value: 7)
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
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Needs Attention")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                HStack(spacing: 12) {
                    needsAttentionCard(count: 2, label: "Maintenance\nDue", color: .orange)
                    needsAttentionCard(count: 3, label: "Overdue\nServices", color: .red)
                    needsAttentionCard(count: 4, label: "Lost\nGPS Feed", color: .blue)
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
            
            NavigationLink(destination: UserManagementView(service: appViewModel.service, currentOrgID: appViewModel.currentOrganization?.id)) {
                quickLink(title: "User Management", subtitle: "Create and manage accounts", icon: "person.2.fill")
            }
            
            NavigationLink(destination: VehicleManagementView(service: appViewModel.service, currentOrgID: appViewModel.currentOrganization?.id)) {
                quickLink(title: "Vehicle Management", subtitle: "Track assets and assignments", icon: "truck.box.fill")
            }
            
            NavigationLink(destination: WorkOrderManagementView(service: appViewModel.service, currentOrgID: appViewModel.currentOrganization?.id)) {
                quickLink(title: "Work Orders", subtitle: "Create and monitor tasks", icon: "wrench.and.screwdriver.fill")
            }
        }
    }
    
    // MARK: - Helpers
    private var priorityAlerts: [AppNotification] {
        appViewModel.service.notifications(for: appViewModel.currentUser).prefix(3).map { $0 }
    }
    
    private func alertColor(_ category: NotificationCategory) -> Color {
        switch category {
        case .critical: return AppTheme.error
        case .warning: return AppTheme.warning
        case .success: return AppTheme.success
        case .info: return AppTheme.brand
        }
    }
    
    private func quickLink(title: String, subtitle: String, icon: String) -> some View {
        GlassCard {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(AppTheme.brand)
                    .frame(width: 42, height: 42)
                    .background(AppTheme.brand.opacity(0.12))
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
        ZStack(alignment: .topTrailing) {
            Image(systemName: "bell")
                .foregroundStyle(AppTheme.textPrimary)
            if appViewModel.unreadNotificationsCount > 0 {
                
                
            }
        }
    }
}

// MARK: - Fleet Map Data

struct VehicleMapPin: Identifiable {
    let id: UUID
    let name: String
    let plateNumber: String
    let coordinate: CLLocationCoordinate2D
    let status: VehicleStatus
}

private func mockVehiclePins(for vehicles: [Vehicle]) -> [VehicleMapPin] {
    let mockCoordinates: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 12.3050, longitude: 76.6450),    // Mysuru
        CLLocationCoordinate2D(latitude: 12.2900, longitude: 76.6300),    // Mysuru
        CLLocationCoordinate2D(latitude: 12.3100, longitude: 76.6500),    // Mysuru
        CLLocationCoordinate2D(latitude: 12.2800, longitude: 76.6200),    // Mysuru
        CLLocationCoordinate2D(latitude: 12.3150, longitude: 76.6600),    // Mysuru
        CLLocationCoordinate2D(latitude: 12.2700, longitude: 76.6100),    // Mysuru
    ]
    
    return vehicles.enumerated().map { index, vehicle in
        let coord = mockCoordinates[index % mockCoordinates.count]
        return VehicleMapPin(
            id: vehicle.id,
            name: vehicle.displayName,
            plateNumber: vehicle.plateNumber,
            coordinate: coord,
            status: vehicle.status
        )
    }
}

// MARK: - Fleet Map Preview (Dashboard Card)

struct FleetMapPreview: View {
    let vehicles: [Vehicle]
    
    var body: some View {
        let pins = mockVehiclePins(for: vehicles)
        let region = mapRegion(for: pins)
        
        Map(initialPosition: .region(region), interactionModes: []) {
            ForEach(pins) { pin in
                Annotation("", coordinate: pin.coordinate) {
                    VehiclePinView(pin: pin, isCompact: true)
                }
            }
            
            // Route polyline connecting all pins
            let allCoords = pins.map(\.coordinate)
            if allCoords.count >= 2 {
                MapPolyline(coordinates: allCoords)
                    .stroke(AppTheme.brand, lineWidth: 4)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
        .colorScheme(.light)
        .allowsHitTesting(false)
    }
    
    private func mapRegion(for pins: [VehicleMapPin]) -> MKCoordinateRegion {
        guard !pins.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 22.5, longitude: 78.9),
                span: MKCoordinateSpan(latitudeDelta: 20.0, longitudeDelta: 20.0)
            )
        }
        let lats = pins.map(\.coordinate.latitude)
        let lons = pins.map(\.coordinate.longitude)
        let center = CLLocationCoordinate2D(
            latitude: (lats.min()! + lats.max()!) / 2,
            longitude: (lons.min()! + lons.max()!) / 2
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((lats.max()! - lats.min()!) * 1.5, 0.5),
            longitudeDelta: max((lons.max()! - lons.min()!) * 1.5, 0.5)
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}

// MARK: - Vehicle Pin View

struct VehiclePinView: View {
    let pin: VehicleMapPin
    var isCompact: Bool = false
    
    private var rotation: Double {
        // Vary tilt per pin for a natural look
        let hash = abs(pin.id.hashValue)
        let angles: [Double] = [-35, -20, 15, -40, 25, -10]
        return angles[hash % angles.count]
    }
    
    var body: some View {
        Image(systemName: "car.fill")
            .font(.system(size: isCompact ? 24 : 32))
            .foregroundStyle(pin.status == .active || pin.status == .inService ? Color(hex: "#FF6B8B") : Color(hex: "#A0A0A0"))
            .shadow(color: pin.status == .active || pin.status == .inService ? Color(hex: "#FF6B8B").opacity(0.6) : Color.black.opacity(0.2), radius: 4, y: 2)
            .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Full Screen Fleet Map

struct FleetMapFullView: View {
    let vehicles: [Vehicle]
    @State private var selectedPin: VehicleMapPin?
    @State private var mapPosition: MapCameraPosition
    
    init(vehicles: [Vehicle]) {
        self.vehicles = vehicles
        let pins = mockVehiclePins(for: vehicles)
        let lats = pins.map(\.coordinate.latitude)
        let lons = pins.map(\.coordinate.longitude)
        if let minLat = lats.min(), let maxLat = lats.max(),
           let minLon = lons.min(), let maxLon = lons.max() {
            let center = CLLocationCoordinate2D(
                latitude: (minLat + maxLat) / 2,
                longitude: (minLon + maxLon) / 2
            )
            let span = MKCoordinateSpan(
                latitudeDelta: max((maxLat - minLat) * 1.5, 0.5),
                longitudeDelta: max((maxLon - minLon) * 1.5, 0.5)
            )
            _mapPosition = State(initialValue: .region(MKCoordinateRegion(center: center, span: span)))
        } else {
            _mapPosition = State(initialValue: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 22.5, longitude: 78.9),
                span: MKCoordinateSpan(latitudeDelta: 20.0, longitudeDelta: 20.0)
            )))
        }
    }
    
    var body: some View {
        let pins = mockVehiclePins(for: vehicles)
        
        ZStack(alignment: .bottom) {
            Map(position: $mapPosition) {
                ForEach(pins) { pin in
                    Annotation("", coordinate: pin.coordinate) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                selectedPin = selectedPin?.id == pin.id ? nil : pin
                            }
                        } label: {
                            VehiclePinView(pin: pin)
                        }
                    }
                }
                
                // Route connecting all vehicles
                let allCoords = pins.map(\.coordinate)
                if allCoords.count >= 2 {
                    MapPolyline(coordinates: allCoords)
                        .stroke(AppTheme.brand, lineWidth: 4)
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
            .colorScheme(.light)
            
            // Vehicle detail card
            if let pin = selectedPin {
                vehicleDetailCard(pin)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .navigationTitle("Live Fleet Map")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func vehicleDetailCard(_ pin: VehicleMapPin) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(statusColor(pin.status).opacity(0.15))
                    .frame(width: 48, height: 48)
                Image(systemName: "truck.box.fill")
                    .font(.title3)
                    .foregroundStyle(statusColor(pin.status))
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(pin.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(pin.plateNumber)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                StatusBadgeView(text: pin.status.rawValue, color: statusColor(pin.status))
            }
            
            Spacer()
            
            Button {
                withAnimation { selectedPin = nil }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 0.5)
        )
    }
    
    private func statusColor(_ status: VehicleStatus) -> Color {
        switch status {
        case .active: return AppTheme.brand
        case .inService: return AppTheme.warning
        case .idle: return AppTheme.textSecondary
        case .outOfService: return AppTheme.error
        }
    }
}

#Preview {
    NavigationStack {
        FleetManagerDashboardView()
            .environment(AppViewModel())
    }
}
