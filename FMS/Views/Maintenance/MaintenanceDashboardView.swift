//Created by Mayurakshi Das

import SwiftUI

struct MaintenanceDashboardView: View {
    @Environment(AppViewModel.self) private var appViewModel
    // Previous state owner kept for rollback:
    // @StateObject private var viewModel = MaintenanceDashboardViewModel()
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if isLoading {
                    LoadingStateView(title: "Loading workshop queue...")
                        .frame(height: 240)
                } else {
                    metricsGrid
                    priorityQueue
                    maintenanceScheduleStrip
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .refreshable {
            await appViewModel.service.syncWithDatabase()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink(destination: ProfileSettingsView()) {
                    ZStack {
                        Circle()
                            .fill(maintenanceAccent)
                            .frame(width: 30, height: 30)
                        Text(userInitials)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .buttonStyle(.plain)
                .buttonBorderShape(.circle)
                .accessibilityIdentifier("PROFILE_BUTTON")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: BroadcastInboxView()) {
                    Image(systemName: "megaphone.fill")
                }
                .accessibilityIdentifier("BROADCAST_BUTTON")
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: NotificationsView()) {
                    Image(systemName: "bell.fill")
                }
                .accessibilityIdentifier("BELL_BUTTON")
            }
        }
        .task {
            await appViewModel.loadNotifications()
            guard isLoading else { return }
            try? await Task.sleep(for: .seconds(0.35))
            isLoading = false
        }
    }

    private var currentUser: User? { appViewModel.currentUser }
    private var userFirstName: String { currentUser?.name.components(separatedBy: " ").first ?? "User" }
    private var assignedOrders: [WorkOrder] { appViewModel.service.workOrders(for: currentUser?.id) }
    private var activeAssignedOrders: [WorkOrder] { assignedOrders.filter { $0.status != .completed } }
    private var priorityOrders: [WorkOrder] {
        activeAssignedOrders.sorted {
            if priorityRank($0.priority) == priorityRank($1.priority) {
                return $0.scheduledDate < $1.scheduledDate
            }
            return priorityRank($0.priority) > priorityRank($1.priority)
        }
    }
    private var assignedVehicleIDs: Set<UUID> { Set(assignedOrders.map(\.vehicleID)) }
    private var upcomingSchedules: [MaintenanceSchedule] {
        let schedules = appViewModel.service.schedules(for: assignedVehicleIDs.isEmpty ? nil : assignedVehicleIDs)
        return schedules.filter { $0.status != .completed }
    }
    private var criticalOrders: [WorkOrder] {
        assignedOrders.filter { $0.priority == .critical && $0.status != .completed }
    }
    private var inProgressOrders: [WorkOrder] {
        assignedOrders.filter { $0.status == .inProgress }
    }
    private var pendingVehicleCount: Int {
        let allOrders = appViewModel.service.workOrders(for: nil)
        let openOrWaiting = allOrders.filter { $0.status == .open || $0.status == .waitingParts }
        return Set(openOrWaiting.map(\.vehicleID)).count
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ], spacing: 10) {
            // 1st Card: Critical
            NavigationLink(destination: MaintenanceWorkOrdersView(showOnlyCritical: true)) {
                MaintenanceMetricCard(
                    icon: "exclamationmark.triangle.fill",
                    title: "Critical",
                    value: "\(criticalOrders.count)",
                    tint: maintenanceAccent
                )
            }
            .buttonStyle(.plain)
            
            // 2nd Card: Work In Progress
            NavigationLink(destination: MaintenanceWorkOrdersView(initialFilter: .inProgress, isLockedFilter: true)) {
                MaintenanceMetricCard(
                    icon: "wrench.and.screwdriver.fill",
                    title: "In Progress",
                    value: "\(inProgressOrders.count)",
                    tint: maintenanceAccent
                )
            }
            .buttonStyle(.plain)
            
            // 3rd Card: Pending Vehicles needing maintenance
            NavigationLink(destination: PendingVehiclesView()) {
                MaintenanceMetricCard(
                    icon: "car.side.fill",
                    title: "Pending Vehicles",
                    value: "\(pendingVehicleCount)",
                    tint: maintenanceAccent
                )
            }
            .buttonStyle(.plain)
            
            // 4th Card: Past Part Orders (shortage parts ordered)
            NavigationLink(destination: PastPartOrdersView()) {
                MaintenanceMetricCard(
                    icon: "clock.arrow.circlepath",
                    title: "Past Orders",
                    value: "\(PastPartOrdersView.shortageOrders.count)",
                    tint: maintenanceAccent
                )
            }
            .buttonStyle(.plain)
        }
    }

    private var priorityQueue: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Priority Queue")
                .font(.headline)
                .foregroundStyle(warmPrimaryText)

            if priorityOrders.isEmpty {
                EmptyStateView(icon: "checkmark.circle.fill", title: "No active assignments", message: "New admin-assigned work orders will appear here.")
            } else {
                ForEach(priorityOrders.prefix(4)) { order in
                    MaintenancePriorityOrderCard(
                        order: order,
                        vehicle: appViewModel.service.vehicle(for: order.vehicleID),
                        tint: priorityColor(order.priority)
                    )
                }
            }
        }
        .padding(.top, 4)
    }

    private var maintenanceScheduleStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scheduled Maintenance")
                .font(.headline)
                .foregroundStyle(warmPrimaryText)

            if upcomingSchedules.isEmpty {
                EmptyStateView(icon: "calendar.badge.checkmark", title: "No scheduled maintenance", message: "Upcoming service jobs will appear here.")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(upcomingSchedules.prefix(6)) { schedule in
                            MaintenanceSchedulePreviewCard(
                                schedule: schedule,
                                vehicle: appViewModel.service.vehicle(for: schedule.vehicleID)
                            )
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .padding(.top, 4)
    }


    private var userInitials: String {
        guard let name = currentUser?.name else { return "MS" }
        let initials = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
        return initials.isEmpty ? "MS" : initials.uppercased()
    }

    private var maintenanceAccent: Color { Color(hex: "#FF5A1F") }
    private var warmPrimaryText: Color { Color.dynamic(light: "#1F2024", dark: "#F2E8E4") }
    private var warmSecondaryText: Color { Color.dynamic(light: "#715B54", dark: "#D7B8AC") }
    private var noticeColor: Color { activeAssignedOrders.isEmpty ? AppTheme.success : maintenanceAccent.opacity(0.9) }

    private func priorityRank(_ priority: WorkOrderPriority) -> Int {
        switch priority {
        case .low: 1
        case .medium: 2
        case .high: 3
        case .critical: 4
        }
    }

    private func priorityColor(_ priority: WorkOrderPriority) -> Color {
        switch priority {
        case .low: AppTheme.success
        case .medium: AppTheme.brand
        case .high: maintenanceAccent
        case .critical: Color(hex: "#FF9C8C")
        }
    }
}

private struct MaintenanceMetricCard: View {
    let icon: String
    let title: String
    let subtitle: String?
    let value: String
    let tint: Color

    init(icon: String, title: String, subtitle: String? = nil, value: String, tint: Color) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.value = value
        self.tint = tint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.callout.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 20, height: 20, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct MaintenancePriorityOrderCard: View {
    let order: WorkOrder
    let vehicle: Vehicle?
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text("WO #\(String(order.id.uuidString.prefix(8)))")
                    .font(.caption2.monospaced().weight(.semibold))
                    .foregroundStyle(Color.dynamic(light: "#8A7066", dark: "#C8A99D"))

                Spacer()

                Text(order.priority.rawValue.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(Color.dynamic(light: "#7A2618", dark: "#FFD1C6"))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(tint.opacity(0.18), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("\(vehicle?.displayName ?? "Assigned Vehicle") • \(vehicle?.plateNumber ?? "No plate")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.dynamic(light: "#24252B", dark: "#E7E4EA"))
                    .lineLimit(2)

                Text(order.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(hex: "#FF5A1F"))
                    .lineLimit(2)

                Text(order.details)
                    .font(.caption)
                    .foregroundStyle(Color.dynamic(light: "#715B54", dark: "#D7B8AC"))
                    .lineLimit(2)
            }

            Divider()
                .overlay(Color.dynamic(light: "#E6D8D2", dark: "#343741"))

            HStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .font(.caption2.weight(.bold))
                Text(order.status.rawValue)
                    .font(.caption.weight(.semibold))
                Spacer()
                Text(order.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
            }
            .foregroundStyle(Color.dynamic(light: "#715B54", dark: "#D7B8AC"))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.dynamic(light: "#FFFFFF", dark: "#24262E").opacity(0.95))
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(tint)
                        .frame(width: 3)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.dynamic(light: "#E6D8D2", dark: "#373A45"), lineWidth: 0.5)
                )
        )
    }

    private var statusIcon: String {
        switch order.status {
        case .open: "tray.fill"
        case .inProgress: "wrench.adjustable.fill"
        case .waitingParts: "shippingbox.fill"
        case .completed: "checkmark.circle.fill"
        }
    }
}

private struct MaintenanceSchedulePreviewCard: View {
    let schedule: MaintenanceSchedule
    let vehicle: Vehicle?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                Text(schedule.dueDate.formatted(date: .abbreviated, time: .omitted))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .font(.caption2.monospaced().weight(.semibold))
            .foregroundStyle(Color.dynamic(light: "#715B54", dark: "#D7B8AC"))

            Text(schedule.serviceType)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.dynamic(light: "#24252B", dark: "#E7E4EA"))
                .lineLimit(2)
                .frame(height: 36, alignment: .topLeading)

            Text(vehicle?.displayName ?? "Vehicle")
                .font(.caption)
                .foregroundStyle(Color.dynamic(light: "#715B54", dark: "#D7B8AC"))
                .lineLimit(1)

            Text(schedule.status.rawValue)
                .font(.caption2.weight(.bold))
                .foregroundStyle(schedule.status == .overdue ? Color(hex: "#FF5A1F") : AppTheme.brand)
        }
        .frame(width: 200, alignment: .leading)
        .frame(minHeight: 110, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.dynamic(light: "#FFFFFF", dark: "#1B1D23").opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.dynamic(light: "#E6D8D2", dark: "#343741"), lineWidth: 0.5)
                )
        )
    }
}

#Preview {
    NavigationStack {
        MaintenanceDashboardView()
            .environment(AppViewModel())
    }
}
