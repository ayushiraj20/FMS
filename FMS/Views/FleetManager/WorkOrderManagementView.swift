import SwiftUI

struct WorkOrderManagementView: View {
    @State private var viewModel: WorkOrderManagementViewModel

    init(service: MockDataService, currentOrgID: UUID?) {
        _viewModel = State(wrappedValue: WorkOrderManagementViewModel(service: service, currentOrgID: currentOrgID))
    }

    var body: some View {
        List {
            ForEach(viewModel.filteredOrders) { order in
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {

                        // MARK: Top row: title + vehicle + priority
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
                                Text(order.priority.rawValue)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(priorityColor(order.priority))

                                // AC3: OVERDUE badge — red background + text label
                                // so colour-blind users are never relying on
                                // colour alone.
                                if order.isOverdue {
                                    HStack(spacing: 3) {
                                        Image(systemName: "exclamationmark.clock.fill")
                                            .font(.caption2.bold())
                                        Text("OVERDUE")
                                            .font(.caption2.bold())
                                    }
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                                }
                            }
                        }

                        // AC4: Show vehicle make/model/plate when overdue so the
                        // fleet manager sees all required details at a glance.
                        if order.isOverdue, let vehicle = viewModel.vehicle(for: order.vehicleID) {
                            HStack(spacing: 6) {
                                Image(systemName: "truck.box.fill")
                                    .font(.caption2)
                                Text([vehicle.displayName, vehicle.model, vehicle.plateNumber]
                                    .filter { !$0.isEmpty }
                                    .joined(separator: " · "))
                                    .font(.caption.weight(.medium))
                            }
                            .foregroundStyle(Color.red.opacity(0.85))
                        }

                        Text(order.details)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)

                        // MARK: Bottom row: status + manage button
                        HStack {
                            Text(order.status.rawValue)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(order.status == .completed ? AppTheme.success : AppTheme.warning)
                            Spacer()
                            Button("Manage") {
                                viewModel.prepareEditOrder(order)
                            }
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.brand)
                        }
                    }
                }
                // AC3: Red border overlay when overdue.
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(order.isOverdue ? Color.red : Color.clear, lineWidth: 2)
                )
                // AC3: Subtle red tint on the card background when overdue.
                .background(
                    order.isOverdue
                        ? Color.red.opacity(0.04)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .appListStyle()
        .searchable(text: $viewModel.searchText)
        .navigationTitle("Work Orders")
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
        }
        .sheet(item: $viewModel.selectedWorkOrder) { _ in
            WorkOrderDetailSheet(viewModel: viewModel)
        }
    }

    private func priorityColor(_ priority: WorkOrderPriority) -> Color {
        switch priority {
        case .low:      AppTheme.success
        case .medium:   AppTheme.brand
        case .high:     AppTheme.warning
        case .critical: AppTheme.error
        }
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
    }
}
