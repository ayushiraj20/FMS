// Created for Maintenance Dashboard - Pending Vehicles

import SwiftUI

struct PendingVehiclesView: View {
    @Environment(AppViewModel.self) private var appViewModel

    private var accent: Color { Color(hex: "#FF5A1F") }
    private var headingText: Color { Color.dynamic(light: "#25262D", dark: "#E7E3E8") }
    private var detailText: Color { Color.dynamic(light: "#715B54", dark: "#E3C8BE") }

    private var currentUser: User? { appViewModel.currentUser }

    /// All pending (open or waiting parts) work orders in the system
    private var pendingOrders: [WorkOrder] {
        appViewModel.service
            .workOrders(for: nil)
            .filter { $0.status == .open || $0.status == .waitingParts }
            .sorted { $0.scheduledDate < $1.scheduledDate }
    }

    /// Unique vehicles that have pending work orders
    private var pendingVehicles: [(vehicle: Vehicle, orders: [WorkOrder])] {
        let grouped = Dictionary(grouping: pendingOrders) { $0.vehicleID }
        return grouped.compactMap { (vehicleID, orders) in
            guard let vehicle = appViewModel.service.vehicle(for: vehicleID) else { return nil }
            return (vehicle: vehicle, orders: orders)
        }
        .sorted { $0.orders.count > $1.orders.count }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if pendingVehicles.isEmpty {
                    EmptyStateView(
                        icon: "car.side.fill",
                        title: "No pending vehicles",
                        message: "All vehicles are up to date. No maintenance is pending."
                    )
                    .padding(.top, 40)
                } else {
                    // Summary banner
                    summaryBanner

                    ForEach(pendingVehicles, id: \.vehicle.id) { entry in
                        vehicleCard(vehicle: entry.vehicle, orders: entry.orders)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Pending Vehicles")
        .navigationBarTitleDisplayMode(.large)
    }

    private var summaryBanner: some View {
        HStack(spacing: 14) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text("\(pendingVehicles.count) Vehicle\(pendingVehicles.count == 1 ? "" : "s") Pending")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)

                Text("\(pendingOrders.count) open work order\(pendingOrders.count == 1 ? "" : "s") awaiting action")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.85))
            }

            Spacer()
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(hex: "#FF5A1F"), Color(hex: "#D70B1B")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private func vehicleCard(vehicle: Vehicle, orders: [WorkOrder]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Vehicle header
            HStack(spacing: 12) {
                Image(systemName: "truck.box.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(accent)
                    .frame(width: 44, height: 44)
                    .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 3) {
                    Text(vehicle.displayName)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(headingText)
                        .lineLimit(1)

                    Text(vehicle.plateNumber)
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(detailText)
                }

                Spacer()

                Text("\(orders.count) pending")
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

                        Text(order.priority.rawValue.uppercased())
                            .font(.system(size: 8, weight: .black))
                            .foregroundStyle(priorityColor(order.priority))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(priorityColor(order.priority).opacity(0.12), in: Capsule())

                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(detailText)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            // Scheduled date info
            if let earliest = orders.min(by: { $0.scheduledDate < $1.scheduledDate }) {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                    Text("Scheduled: \(earliest.scheduledDate.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(detailText)
                .padding(.top, 2)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.dynamic(light: "#FFFFFF", dark: "#1B1C22").opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.dynamic(light: "#E6D8D2", dark: "#353741"), lineWidth: 0.5)
                )
        )
    }

    private func priorityColor(_ priority: WorkOrderPriority) -> Color {
        switch priority {
        case .low: AppTheme.success
        case .medium: Color.orange
        case .high: Color(hex: "#FF5A1F")
        case .critical: Color.red
        }
    }
}

#Preview {
    NavigationStack {
        PendingVehiclesView()
            .environment(AppViewModel())
    }
}
