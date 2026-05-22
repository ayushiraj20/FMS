import SwiftUI

struct MaintenanceWorkOrdersView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var searchText = ""
    @State private var selectedOrder: WorkOrder?

    private var currentUser: User? { appViewModel.currentUser }
    private var orders: [WorkOrder] {
        appViewModel.service.workOrders(for: currentUser?.id).filter {
            searchText.isEmpty ||
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.details.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        List {
            ForEach(orders) { order in
                Button {
                    selectedOrder = order
                } label: {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(order.title)
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(order.details)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                            HStack {
                                Text(order.status.rawValue)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(order.status == .completed ? AppTheme.success : AppTheme.warning)
                                Spacer()
                                Text(appViewModel.service.vehicle(for: order.vehicleID)?.plateNumber ?? "")
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .appListStyle()
        .searchable(text: $searchText)
        .navigationTitle("Assigned Orders")
        .sheet(item: $selectedOrder) { order in
            MaintenanceOrderUpdateSheet(workOrder: order)
                .environment(appViewModel)
        }
    }
}

private struct MaintenanceOrderUpdateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel
    @State var workOrder: WorkOrder

    var body: some View {
        NavigationStack {
            Form {
                Section("Status") {
                    Picker("Current Status", selection: $workOrder.status) {
                        ForEach(WorkOrderStatus.allCases) { status in
                            Text(status.rawValue).tag(status)
                        }
                    }
                    TextField("Completed Repairs", text: $workOrder.repairSummary, axis: .vertical)
                }
            }
            .navigationTitle("Update Work Order")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if workOrder.status == .completed && workOrder.completedDate == nil {
                            workOrder.completedDate = .now
                        }
                        appViewModel.service.updateWorkOrder(workOrder)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MaintenanceWorkOrdersView()
            .environment(AppViewModel())
    }
}
