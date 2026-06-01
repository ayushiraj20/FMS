import SwiftUI

struct WorkOrderManagementView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var viewModel: WorkOrderManagementViewModel

    init(service: MockDataService, currentOrgID: UUID?) {
        _viewModel = State(wrappedValue: WorkOrderManagementViewModel(service: service, currentOrgID: currentOrgID))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // MARK: – Stats Grid
                statsGrid
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // MARK: – Quick Access
                quickAccessSection
                    .padding(.horizontal, 20)

                // MARK: – Upcoming Services
                upcomingServicesSection
                    .padding(.horizontal, 20)

                // MARK: – Open Work Orders
                workOrdersSection
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
            }
        }
        .refreshable {
            await appViewModel.service.syncWithDatabase()
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Work Orders")
        .searchable(text: $viewModel.searchText)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.prepareCreateOrder()
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(AppTheme.brand)
                }
            }
        }
        .sheet(isPresented: $viewModel.isPresentingCreateSheet) {
            CreateWorkOrderSheet(viewModel: viewModel)
                .registersSheetPresentation()
        }
        .sheet(item: $viewModel.selectedWorkOrder) { _ in
            WorkOrderDetailSheet(viewModel: viewModel)
                .registersSheetPresentation()
        }
        .task {
            await appViewModel.service.syncDefectsAndWorkOrders()
        }
    }

    // MARK: - Stats Grid
    private var statsGrid: some View {
        let scheduledCount = appViewModel.service.maintenanceSchedules.filter { $0.status == .upcoming }.count
        let openDefects = appViewModel.service.defects.filter {
            $0.status == .pending || $0.status == .approved || $0.status == .inRepair
        }.count
        let activeWorkOrders = appViewModel.service.workOrders.filter { $0.status != .completed }.count
        let overdueCount = appViewModel.service.maintenanceSchedules.filter { $0.status == .overdue }.count

        return LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            statCard(title: "Scheduled", value: "\(scheduledCount)", icon: "calendar.badge.clock", color: AppTheme.brand)

            NavigationLink(destination: DefectReportsListView().environment(appViewModel)) {
                statCard(
                    title: "Open Defects",
                    value: "\(openDefects)",
                    icon: "exclamationmark.triangle.fill",
                    color: AppTheme.warning,
                    badge: openDefects > 0 ? "+New" : nil
                )
            }
            .buttonStyle(.plain)

            statCard(
                title: "Work Orders",
                value: "\(activeWorkOrders)",
                icon: "wrench.and.screwdriver.fill",
                color: AppTheme.textPrimary
            )

            statCard(
                title: "Overdue",
                value: "\(overdueCount)",
                icon: "clock.badge.exclamationmark",
                color: AppTheme.error,
                badge: overdueCount > 0 ? "ALERT" : nil
            )
        }
    }

    private func statCard(title: String, value: String, icon: String, color: Color, badge: String? = nil) -> some View {
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
                    if let badge {
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
                    Button {
                        viewModel.prepareCreateOrder()
                    } label: {
                        quickChip(icon: "calendar.badge.plus", title: "Schedule")
                    }

                    NavigationLink(destination: DefectReportsListView().environment(appViewModel)) {
                        quickChip(icon: "exclamationmark.triangle", title: "Defects")
                    }

                    quickChip(icon: "doc.text.magnifyingglass", title: "Reports")
                }
            }
        }
    }

    private func quickChip(icon: String, title: String) -> some View {
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
            Text("Upcoming Services")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            let schedules = appViewModel.service.maintenanceSchedules
                .sorted { $0.dueDate < $1.dueDate }
                .prefix(5)

            if schedules.isEmpty {
                EmptyStateView(
                    icon: "checkmark.circle",
                    title: "All caught up",
                    message: "No upcoming maintenance scheduled."
                )
            } else {
                ForEach(Array(schedules)) { schedule in
                    serviceCard(schedule)
                }
            }
        }
    }

    private func serviceCard(_ schedule: MaintenanceSchedule) -> some View {
        let vehicle = appViewModel.service.vehicle(for: schedule.vehicleID)
        let color = scheduleStatusColor(schedule.status)

        return GlassCard {
            HStack(spacing: 14) {
                Image(systemName: serviceIcon(schedule.serviceType))
                    .font(.title3)
                    .foregroundStyle(color)
                    .frame(width: 42, height: 42)
                    .background(color.opacity(0.12))
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
                        if let v = vehicle {
                            Label("\(v.odometer.formatted()) km", systemImage: "speedometer")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }

                Spacer()

                StatusBadgeView(text: schedule.status.rawValue, color: color)
            }
        }
    }

    // MARK: - Open Work Orders
    private var workOrdersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Open Work Orders")
                .font(.headline)
                .foregroundStyle(AppTheme.textPrimary)

            if viewModel.filteredOrders.isEmpty {
                EmptyStateView(
                    icon: "wrench.and.screwdriver",
                    title: "No work orders",
                    message: "All work orders have been completed."
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.filteredOrders) { order in
                        NavigationLink(destination:
                            WorkOrderChatView(
                                workOrderID: order.id,
                                onManage: { viewModel.prepareEditOrder(order) }
                            ).environment(appViewModel)
                        ) {
                            workOrderCard(order)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func workOrderCard(_ order: WorkOrder) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(order.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(viewModel.vehicle(for: order.vehicleID)?.displayName ?? "Vehicle")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        if order.isOverdue {
                            Text("Overdue")
                                .font(.footnote.weight(.bold))
                                .foregroundStyle(AppTheme.error)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(AppTheme.error.opacity(0.15))
                                .clipShape(Capsule())
                        }
                        Text(order.priority.rawValue)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(priorityColor(order.priority))
                    }
                }

                Text(order.details)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(2)

                HStack(spacing: 16) {
                    Text(order.status.rawValue)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(order.status == .completed ? AppTheme.success : AppTheme.warning)
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                        Text("Repair Chat")
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.brand)
                }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(order.isOverdue ? AppTheme.error : Color.clear, lineWidth: 2)
        )
    }

    // MARK: - Helpers
    private func priorityColor(_ priority: WorkOrderPriority) -> Color {
        switch priority {
        case .low:      AppTheme.success
        case .medium:   AppTheme.brand
        case .high:     AppTheme.warning
        case .critical: AppTheme.error
        }
    }

    private func scheduleStatusColor(_ status: MaintenanceScheduleStatus) -> Color {
        switch status {
        case .upcoming:  AppTheme.brand
        case .overdue:   AppTheme.error
        case .completed: AppTheme.success
        }
    }

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

    private func formattedDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }
}

// MARK: - Create Sheet

private struct CreateWorkOrderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: WorkOrderManagementViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Assignment") {
                    Picker("Vehicle", selection: $viewModel.createVehicleID) {
                        ForEach(viewModel.vehicles) { vehicle in
                            Text(vehicle.displayName).tag(Optional(vehicle.id))
                        }
                    }
                    Picker("Technician", selection: $viewModel.createMaintenanceID) {
                        Text("Unassigned").tag(Optional<UUID>.none)
                        ForEach(viewModel.technicians) { user in
                            Text(user.name).tag(Optional(user.id))
                        }
                    }
                }

                Section("Work Order") {
                    TextField("Title", text: $viewModel.createTitle)
                    TextField("Details", text: $viewModel.createDetails, axis: .vertical)
                    Picker("Priority", selection: $viewModel.createPriority) {
                        ForEach(WorkOrderPriority.allCases) { item in
                            Text(item.rawValue).tag(item)
                        }
                    }
                    DatePicker("Scheduled Date", selection: $viewModel.createScheduledDate)
                }
            }
            .navigationTitle("Create Work Order")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        viewModel.createWorkOrder()
                        dismiss()
                    }
                    .disabled(
                        viewModel.createVehicleID == nil ||
                        viewModel.createTitle.isEmpty ||
                        viewModel.createDetails.isEmpty
                    )
                }
            }
        }
    }
}

// MARK: - Detail / Edit Sheet

private struct WorkOrderDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: WorkOrderManagementViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Progress") {
                    Picker("Status", selection: $viewModel.editStatus) {
                        ForEach(WorkOrderStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    TextField("Repair Summary", text: $viewModel.editRepairSummary, axis: .vertical)
                    if viewModel.editStatus == .completed {
                        DatePicker("Completed Date", selection: $viewModel.editCompletedDate)
                    }
                }
            }
            .navigationTitle("Manage Work Order")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveWorkOrder()
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        WorkOrderManagementView(service: MockDataService(), currentOrgID: UUID())
            .environment(AppViewModel())
    }
}
