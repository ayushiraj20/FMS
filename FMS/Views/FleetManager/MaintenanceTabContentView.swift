import SwiftUI

struct MaintenanceTabContentView: View {
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // MARK: - Header
                headerSection

                // MARK: - Stats Grid
                statsGrid

                // MARK: - Quick Access
                quickAccessSection

                // MARK: - Upcoming Services
                upcomingServicesSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(AppTheme.background)
        .navigationTitle("Maintenance")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: WorkOrderManagementView(service: appViewModel.service, currentOrgID: appViewModel.currentOrganization?.id)) {
                    Image(systemName: "plus")
                        .foregroundStyle(AppTheme.brand)
                }
            }
        }
        .task {
            // Sync defect reports whenever the maintenance tab is opened
            await appViewModel.service.syncDefectsAndWorkOrders()
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Fleet health and service oversight.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    // MARK: - Stats Grid
    private var statsGrid: some View {
        let scheduledCount = appViewModel.service.maintenanceSchedules.filter { $0.status == .upcoming }.count
        let openDefects = appViewModel.service.defects.filter { $0.status == .pending || $0.status == .approved || $0.status == .inRepair }.count
        let activeWorkOrders = appViewModel.service.workOrders.filter { $0.status != .completed }.count
        let overdueCount = appViewModel.service.maintenanceSchedules.filter { $0.status == .overdue }.count

        return LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            maintenanceStatCard(
                title: "Scheduled",
                value: "\(scheduledCount)",
                icon: "calendar.badge.clock",
                color: AppTheme.brand
            )
            NavigationLink(destination: DefectReportsListView().environment(appViewModel)) {
                maintenanceStatCard(
                    title: "Open Defects",
                    value: "\(openDefects)",
                    icon: "exclamationmark.triangle.fill",
                    color: AppTheme.warning,
                    badgeText: openDefects > 0 ? "+New" : nil
                )
            }
            .buttonStyle(.plain)
            
            NavigationLink(destination: WorkOrderManagementView(service: appViewModel.service, currentOrgID: appViewModel.currentOrganization?.id)) {
                maintenanceStatCard(
                    title: "Work Orders",
                    value: "\(activeWorkOrders)",
                    icon: "wrench.and.screwdriver.fill",
                    color: AppTheme.textPrimary
                )
            }
            .buttonStyle(.plain)
            
            maintenanceStatCard(
                title: "Overdue",
                value: "\(overdueCount)",
                icon: "clock.badge.exclamationmark",
                color: AppTheme.error,
                badgeText: overdueCount > 0 ? "ALERT" : nil
            )
        }
    }

    // MARK: - Stat Card
    private func maintenanceStatCard(title: String, value: String, icon: String, color: Color, badgeText: String? = nil) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(title)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    Image(systemName: icon)
                        .font(.body)
                        .foregroundStyle(color)
                }

                HStack(alignment: .bottom, spacing: 6) {
                    Text(value)
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.textPrimary)

                    if let badge = badgeText {
                        Text(badge)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(color))
                            .padding(.bottom, 4)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Quick Access
    private var quickAccessSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Access")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    NavigationLink(destination: WorkOrderManagementView(service: appViewModel.service, currentOrgID: appViewModel.currentOrganization?.id)) {
                        quickAccessChip(icon: "calendar", title: "Schedule")
                    }

                    NavigationLink(destination: DefectReportsListView().environment(appViewModel)) {
                        quickAccessChip(icon: "exclamationmark.triangle", title: "Defects")
                    }

                    quickAccessChip(icon: "doc.text.magnifyingglass", title: "Reports")
                }
            }
        }
    }

    private func quickAccessChip(icon: String, title: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline)
            Text(title)
                .font(.subheadline.weight(.medium))
        }
        .foregroundStyle(AppTheme.textPrimary)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.surfaceSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 0.5)
        )
    }

    // MARK: - Upcoming Services
    private var upcomingServicesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming Services")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                Spacer()
                NavigationLink(destination: WorkOrderManagementView(service: appViewModel.service, currentOrgID: appViewModel.currentOrganization?.id)) {
                    Text("View All")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.brand)
                }
            }

            let schedules = appViewModel.service.maintenanceSchedules
                .sorted { $0.dueDate < $1.dueDate }
                .prefix(5)

            ForEach(Array(schedules)) { schedule in
                serviceCard(schedule)
            }

            if schedules.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: "All caught up",
                    message: "No upcoming maintenance services scheduled."
                )
            }
        }
    }

    // MARK: - Service Card
    private func serviceCard(_ schedule: MaintenanceSchedule) -> some View {
        let vehicle = appViewModel.service.vehicle(for: schedule.vehicleID)

        return GlassCard {
            HStack(spacing: 14) {
                Image(systemName: serviceIcon(schedule.serviceType))
                    .font(.title3)
                    .foregroundStyle(statusColor(schedule.status))
                    .frame(width: 42, height: 42)
                    .background(statusColor(schedule.status).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(vehicle?.displayName ?? "Vehicle")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("–")
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(schedule.serviceType)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(1)
                    }

                    HStack(spacing: 12) {
                        Label(formattedDate(schedule.dueDate), systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)

                        if let vehicle {
                            Label("\(vehicle.odometer.formatted()) km", systemImage: "speedometer")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }

                Spacer()

                StatusBadgeView(
                    text: schedule.status.rawValue,
                    color: statusColor(schedule.status)
                )
            }
        }
    }

    // MARK: - Helpers
    private func serviceIcon(_ serviceType: String) -> String {
        if serviceType.localizedCaseInsensitiveContains("oil") || serviceType.localizedCaseInsensitiveContains("filter") {
            return "drop.fill"
        } else if serviceType.localizedCaseInsensitiveContains("tyre") || serviceType.localizedCaseInsensitiveContains("tire") {
            return "circle.circle"
        } else if serviceType.localizedCaseInsensitiveContains("brake") {
            return "exclamationmark.octagon.fill"
        }
        return "wrench.fill"
    }

    private func statusColor(_ status: MaintenanceScheduleStatus) -> Color {
        switch status {
        case .upcoming: return AppTheme.brand
        case .overdue: return AppTheme.error
        case .completed: return AppTheme.success
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        MaintenanceTabContentView()
            .environment(AppViewModel())
    }
}
