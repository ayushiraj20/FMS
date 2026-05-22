//Created by Mayurakshi Das

import SwiftUI

struct MaintenanceDashboardView: View {
    @Environment(AppViewModel.self) private var appViewModel
    // Previous state owner kept for rollback:
    // @StateObject private var viewModel = MaintenanceDashboardViewModel()
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if isLoading {
                    LoadingStateView(title: "Loading workshop queue...")
                        .frame(height: 320)
                } else {
                    // Previous sections kept below for quick rollback:
                    // header
                    // activeOrders
                    // schedulePreview
                    dashboardHeader
                    assignmentNotice
                    metricsGrid
                    priorityQueue
                    maintenanceScheduleStrip
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .navigationTitle("Dashboard")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: NotificationsView()) {
                    Image(systemName: "bell")
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
        }
        .task {
            // Previous load path kept for rollback:
            // await viewModel.load()
            guard isLoading else { return }
            try? await Task.sleep(for: .seconds(0.35))
            isLoading = false
        }
    }

    private var currentUser: User? { appViewModel.currentUser }
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

    private var dashboardHeader: some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "person.2.badge.gearshape.fill")
                        .foregroundStyle(maintenanceAccent)
                    Text("FleetOS")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(warmPrimaryText)
                }

                Text("\(Date.now.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())) • \(activeAssignedOrders.count) active assignments")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(warmSecondaryText)
            }

            Spacer()

            Text(userInitials)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [maintenanceAccent.opacity(0.9), Color(hex: "#C93610")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
        }
    }

    private var assignmentNotice: some View {
        HStack(spacing: 14) {
            Image(systemName: activeAssignedOrders.isEmpty ? "checkmark.seal.fill" : "tray.full.fill")
                .font(.title3)
                .foregroundStyle(noticeColor)

            VStack(alignment: .leading, spacing: 4) {
                Text(activeAssignedOrders.isEmpty ? "No assigned work pending" : "\(activeAssignedOrders.count) admin-assigned work orders")
                    .font(.headline)
                    .foregroundStyle(warmPrimaryText)
                Text(activeAssignedOrders.isEmpty ? "You are clear for now." : "Tap Orders to update progress after each repair.")
                    .font(.subheadline)
                    .foregroundStyle(warmSecondaryText)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.headline.weight(.semibold))
                .foregroundStyle(noticeColor)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(noticeColor.opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(noticeColor.opacity(0.18), lineWidth: 1)
                )
        )
    }

    private var metricsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 16),
            GridItem(.flexible(), spacing: 16)
        ], spacing: 16) {
            MaintenanceMetricCard(
                icon: "list.clipboard.fill",
                title: "Open Orders",
                value: "\(activeAssignedOrders.count)",
                tint: maintenanceAccent
            )
            MaintenanceMetricCard(
                icon: "exclamationmark.triangle.fill",
                title: "Critical",
                value: "\(assignedOrders.filter { $0.priority == .critical && $0.status != .completed }.count)",
                tint: Color(hex: "#FFB4A6")
            )
            MaintenanceMetricCard(
                icon: "wrench.and.screwdriver.fill",
                title: "In Progress",
                value: "\(assignedOrders.filter { $0.status == .inProgress }.count)",
                tint: Color(hex: "#C8D1E0")
            )
            MaintenanceMetricCard(
                icon: "shippingbox.fill",
                title: "Waiting Parts",
                value: "\(assignedOrders.filter { $0.status == .waitingParts }.count)",
                tint: Color(hex: "#FFC3AD")
            )
        }
    }

    private var priorityQueue: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(maintenanceAccent)
                    .frame(width: 8, height: 8)
                Text("Today's Priority Queue")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(warmPrimaryText)
            }

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
        .padding(.top, 8)
    }

    private var maintenanceScheduleStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Scheduled Maintenance")
                .font(.title3.weight(.bold))
                .foregroundStyle(warmPrimaryText)

            if upcomingSchedules.isEmpty {
                EmptyStateView(icon: "calendar.badge.checkmark", title: "No scheduled maintenance", message: "Upcoming service jobs will appear here.")
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
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
        .padding(.top, 8)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workshop Command")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Track assigned work, close repairs quickly, and keep preventive maintenance on schedule.")
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var activeOrders: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Assigned Work Orders", subtitle: "Your active workshop queue")
            ForEach(appViewModel.service.workOrders(for: currentUser?.id).prefix(3)) { order in
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(order.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(order.details)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(order.status.rawValue)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(order.status == .completed ? AppTheme.success : AppTheme.warning)
                    }
                }
            }
        }
    }

    private var schedulePreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Maintenance Schedule", subtitle: "Upcoming and overdue service")
            ForEach(appViewModel.service.schedules().prefix(3)) { schedule in
                let vehicle = appViewModel.service.vehicle(for: schedule.vehicleID)
                GlassCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(schedule.serviceType)
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(vehicle?.displayName ?? "Vehicle")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        Text(schedule.dueDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(schedule.status == .overdue ? AppTheme.error : AppTheme.brand)
                    }
                }
            }
        }
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
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon)
                .font(.title3.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 24, height: 24, alignment: .leading)

            Spacer(minLength: 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(Color.dynamic(light: "#715B54", dark: "#D7B8AC"))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text(value)
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.dynamic(light: "#1F2024", dark: "#F2E8E4"))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.dynamic(light: "#FFFFFF", dark: "#1B1D23").opacity(0.92))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.dynamic(light: "#E6D8D2", dark: "#343741"), lineWidth: 1)
                )
        )
    }
}

private struct MaintenancePriorityOrderCard: View {
    let order: WorkOrder
    let vehicle: Vehicle?
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text("WO #\(String(order.id.uuidString.prefix(8)))")
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(Color.dynamic(light: "#8A7066", dark: "#C8A99D"))

                Spacer()

                Text(order.priority.rawValue.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(Color.dynamic(light: "#7A2618", dark: "#FFD1C6"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(tint.opacity(0.18), in: Capsule())
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("\(vehicle?.displayName ?? "Assigned Vehicle") • \(vehicle?.plateNumber ?? "No plate")")
                    .font(.headline)
                    .foregroundStyle(Color.dynamic(light: "#24252B", dark: "#E7E4EA"))
                    .lineLimit(2)

                Text(order.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color(hex: "#FF5A1F"))
                    .lineLimit(2)

                Text(order.details)
                    .font(.subheadline)
                    .foregroundStyle(Color.dynamic(light: "#715B54", dark: "#D7B8AC"))
                    .lineLimit(2)
            }

            Divider()
                .overlay(Color.dynamic(light: "#E6D8D2", dark: "#343741"))

            HStack(spacing: 8) {
                Image(systemName: statusIcon)
                    .font(.caption.weight(.bold))
                Text(order.status.rawValue)
                    .font(.footnote.weight(.semibold))
                Spacer()
                Text(order.scheduledDate.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
            }
            .foregroundStyle(Color.dynamic(light: "#715B54", dark: "#D7B8AC"))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.dynamic(light: "#FFFFFF", dark: "#24262E").opacity(0.95))
                .overlay(alignment: .leading) {
                    Rectangle()
                        .fill(tint)
                        .frame(width: 4)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.dynamic(light: "#E6D8D2", dark: "#373A45"), lineWidth: 1)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "clock")
                Text(schedule.dueDate.formatted(date: .abbreviated, time: .omitted))
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .font(.caption.monospaced().weight(.semibold))
            .foregroundStyle(Color.dynamic(light: "#715B54", dark: "#D7B8AC"))

            Text(schedule.serviceType)
                .font(.headline)
                .foregroundStyle(Color.dynamic(light: "#24252B", dark: "#E7E4EA"))
                .lineLimit(2)
                .frame(height: 44, alignment: .topLeading)

            Text(vehicle?.displayName ?? "Vehicle")
                .font(.subheadline)
                .foregroundStyle(Color.dynamic(light: "#715B54", dark: "#D7B8AC"))
                .lineLimit(1)

            Text(schedule.status.rawValue)
                .font(.caption.weight(.bold))
                .foregroundStyle(schedule.status == .overdue ? Color(hex: "#FF5A1F") : AppTheme.brand)
        }
        .frame(width: 230, alignment: .leading)
        .frame(minHeight: 138, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.dynamic(light: "#FFFFFF", dark: "#1B1D23").opacity(0.94))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.dynamic(light: "#E6D8D2", dark: "#343741"), lineWidth: 1)
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
