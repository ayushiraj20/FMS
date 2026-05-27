import SwiftUI

struct PendingVehiclesView: View {
    @Environment(AppViewModel.self) private var appViewModel

    private var accent: Color { Color(hex: "#FF5A1F") }
    private var headingText: Color { Color.dynamic(light: "#25262D", dark: "#E7E3E8") }
    private var detailText: Color { Color.dynamic(light: "#715B54", dark: "#E3C8BE") }

    private var pendingVehicles: [(vehicle: Vehicle, orders: [WorkOrder])] {
        let allOrders = appViewModel.service.workOrders(for: nil)
        let openOrWaiting = allOrders.filter { $0.status == .open || $0.status == .waitingParts }
        let grouped = Dictionary(grouping: openOrWaiting, by: \.vehicleID)
        return grouped.compactMap { (vehicleID, orders) in
            guard let vehicle = appViewModel.service.vehicle(for: vehicleID) else { return nil }
            return (vehicle: vehicle, orders: orders)
        }
        .sorted { $0.vehicle.displayName < $1.vehicle.displayName }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                if pendingVehicles.isEmpty {
                    EmptyStateView(
                        icon: "car.side.fill",
                        title: "No pending vehicles",
                        message: "All vehicles are up to date with maintenance."
                    )
                    .padding(.top, 40)
                } else {
                    ForEach(pendingVehicles, id: \.vehicle.id) { item in
                        vehicleCard(vehicle: item.vehicle, orders: item.orders)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .navigationTitle("Pending Vehicles")
        .navigationBarTitleDisplayMode(.large)
    }

    private func vehicleCard(vehicle: Vehicle, orders: [WorkOrder]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            // Vehicle header
            HStack(spacing: 12) {
                Image(systemName: "truck.box.fill")
                    .font(.title2)
                    .foregroundStyle(accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text(vehicle.displayName)
                        .font(.headline)
                        .foregroundStyle(headingText)
                    Text(vehicle.plateNumber)
                        .font(.caption.monospaced())
                        .foregroundStyle(detailText)
                }

                Spacer()

                Text("\(orders.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(accent, in: Capsule())
            }

            Divider()
                .overlay(Color.dynamic(light: "#E6D8D2", dark: "#343741"))

            // List the pending work orders for this vehicle
            ForEach(orders) { order in
                NavigationLink(destination: MaintenanceWorkOrdersView.MaintenanceWorkOrderDetailView(workOrder: order).environment(appViewModel)) {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(priorityColor(order.priority))
                            .frame(width: 8, height: 8)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(order.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(headingText)
                                .lineLimit(1)

                            Text(order.details)
                                .font(.caption)
                                .foregroundStyle(detailText)
                                .lineLimit(1)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(detailText.opacity(0.5))
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 0.3)
        )
    }

    private func priorityColor(_ priority: WorkOrderPriority) -> Color {
        switch priority {
        case .low:      Color.dynamic(light: "#1E5BE4", dark: "#7EA5FF")
        case .medium:   Color.dynamic(light: "#8F4E00", dark: "#FFB874")
        case .high:     Color(hex: "#FF5A1F")
        case .critical: Color.dynamic(light: "#BA1A1A", dark: "#FF8989")
        }
    }
}
