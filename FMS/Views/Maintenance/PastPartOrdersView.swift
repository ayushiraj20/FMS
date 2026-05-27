// Created for Maintenance Dashboard - Past Part Orders

import SwiftUI

/// Represents a past part order record (simulated from inventory shortage data)
struct PastPartOrder: Identifiable {
    let id = UUID()
    let partName: String
    let partNumber: String
    let category: String
    let quantityOrdered: Int
    let orderDate: Date
    let status: PastPartOrderStatus
    let icon: String

    enum PastPartOrderStatus: String, CaseIterable, Identifiable {
        case delivered = "Delivered"
        case inTransit = "In Transit"
        case processing = "Processing"

        var id: String { rawValue }

        var color: Color {
            switch self {
            case .delivered: AppTheme.success
            case .inTransit: Color(hex: "#2EA7FF")
            case .processing: Color.orange
            }
        }

        var icon: String {
            switch self {
            case .delivered: "checkmark.circle.fill"
            case .inTransit: "truck.box.fill"
            case .processing: "clock.fill"
            }
        }
    }
}

struct PastPartOrdersView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var selectedStatus: PastPartOrder.PastPartOrderStatus = .delivered

    private var accent: Color { Color(hex: "#FF5A1F") }
    private var headingText: Color { Color.dynamic(light: "#25262D", dark: "#E7E3E8") }
    private var detailText: Color { Color.dynamic(light: "#715B54", dark: "#E3C8BE") }

    /// Shared past orders of parts that had shortages and were ordered
    static var shortageOrders: [PastPartOrder] {
        [
            PastPartOrder(
                partName: "Hydraulic Filter Assembly",
                partNumber: "#PN-8821",
                category: "Fluid System",
                quantityOrdered: 10,
                orderDate: Date.now.addingTimeInterval(-86400 * 5),
                status: .delivered,
                icon: "shippingbox"
            ),
            PastPartOrder(
                partName: "Heavy Duty Brake Pads",
                partNumber: "#PN-4402",
                category: "Brake System",
                quantityOrdered: 8,
                orderDate: Date.now.addingTimeInterval(-86400 * 3),
                status: .delivered,
                icon: "slider.horizontal.3"
            ),
            PastPartOrder(
                partName: "Halogen Headlight Bulbs",
                partNumber: "#PN-3115",
                category: "Electrical",
                quantityOrdered: 15,
                orderDate: Date.now.addingTimeInterval(-86400 * 2),
                status: .inTransit,
                icon: "lightbulb"
            )
        ]
    }

    private var pastOrders: [PastPartOrder] {
        Self.shortageOrders
    }

    private var filteredOrders: [PastPartOrder] {
        pastOrders.filter { $0.status == selectedStatus }
    }

    private func count(for status: PastPartOrder.PastPartOrderStatus) -> Int {
        pastOrders.filter { $0.status == status }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if pastOrders.isEmpty {
                    EmptyStateView(
                        icon: "clock.arrow.circlepath",
                        title: "No past orders",
                        message: "Parts ordered due to shortage will appear here."
                    )
                    .padding(.top, 40)
                } else {
                    // Native Segmented Control for filtering
                    Picker("Order Status", selection: $selectedStatus) {
                        ForEach(PastPartOrder.PastPartOrderStatus.allCases) { status in
                            Text("\(status.rawValue) (\(count(for: status)))")
                                .tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.bottom, 6)
                    
                    if filteredOrders.isEmpty {
                        EmptyStateView(
                            icon: selectedStatus.icon,
                            title: "No \(selectedStatus.rawValue) Orders",
                            message: "There are no part orders currently in \(selectedStatus.rawValue.lowercased()) status."
                        )
                        .padding(.top, 40)
                    } else {
                        ForEach(filteredOrders) { order in
                            pastOrderCard(order)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 24)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Past Part Orders")
        .navigationBarTitleDisplayMode(.large)
    }

    private func pastOrderCard(_ order: PastPartOrder) -> some View {
        HStack(spacing: 14) {
            // Part icon
            Image(systemName: order.icon)
                .font(.title3.weight(.bold))
                .foregroundStyle(accent)
                .frame(width: 44, height: 44)
                .background(accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(order.partName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(headingText)
                    .lineLimit(1)

                Text("\(order.partNumber) · \(order.category)")
                    .font(.caption.monospaced().weight(.semibold))
                    .foregroundStyle(accent)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label("Qty: \(order.quantityOrdered)", systemImage: "shippingbox")
                        .font(.caption)
                        .foregroundStyle(detailText)

                    Label(order.orderDate.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(detailText)
                }
            }

            Spacer()

            // Status badge
            VStack(spacing: 4) {
                Image(systemName: order.status.icon)
                    .font(.callout.weight(.bold))
                    .foregroundStyle(order.status.color)

                Text(order.status.rawValue)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(order.status.color)
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
}

#Preview {
    NavigationStack {
        PastPartOrdersView()
            .environment(AppViewModel())
    }
}
