import SwiftUI

struct PastPartOrdersView: View {
    private var accent: Color { Color(hex: "#FF5A1F") }
    private var headingText: Color { Color.dynamic(light: "#25262D", dark: "#E7E3E8") }
    private var detailText: Color { Color.dynamic(light: "#715B54", dark: "#E3C8BE") }

    /// Shared past orders of parts that had shortages and were ordered
    static var shortageOrders: [PastPartOrder] {
        [
            PastPartOrder(
                partName: "Hydraulic Filter Assembly",
                partNumber: "#PN-8821",
                orderedQuantity: 10,
                orderDate: Calendar.current.date(byAdding: .day, value: -3, to: .now)!,
                status: .delivered,
                estimatedDelivery: Calendar.current.date(byAdding: .day, value: -1, to: .now)!
            ),
            PastPartOrder(
                partName: "Heavy Duty Brake Pads",
                partNumber: "#PN-4402",
                orderedQuantity: 8,
                orderDate: Calendar.current.date(byAdding: .day, value: -2, to: .now)!,
                status: .inTransit,
                estimatedDelivery: Calendar.current.date(byAdding: .day, value: 1, to: .now)!
            ),
            PastPartOrder(
                partName: "Halogen Headlight Bulbs",
                partNumber: "#PN-3115",
                orderedQuantity: 15,
                orderDate: Calendar.current.date(byAdding: .day, value: -1, to: .now)!,
                status: .processing,
                estimatedDelivery: Calendar.current.date(byAdding: .day, value: 3, to: .now)!
            )
        ]
    }

    @State private var selectedSegment: PastPartOrderStatus = .delivered

    var body: some View {
        VStack(spacing: 0) {
            // Segmented control
            Picker("Status", selection: $selectedSegment) {
                ForEach(PastPartOrderStatus.allCases) { status in
                    Text(status.title).tag(status)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            ScrollView {
                let filtered = PastPartOrdersView.shortageOrders.filter { $0.status == selectedSegment }
                VStack(spacing: 12) {
                    if filtered.isEmpty {
                        EmptyStateView(
                            icon: "shippingbox",
                            title: "No \(selectedSegment.title.lowercased()) orders",
                            message: "Orders with this status will appear here."
                        )
                        .padding(.top, 40)
                    } else {
                        ForEach(filtered) { order in
                            orderCard(order)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Past Orders")
        .navigationBarTitleDisplayMode(.large)
    }

    private func orderCard(_ order: PastPartOrder) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(order.partNumber)
                        .font(.caption.monospaced().weight(.bold))
                        .foregroundStyle(accent)
                    Text(order.partName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(headingText)
                }
                Spacer()
                Text(order.status.title.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(order.status.color, in: Capsule())
            }

            Divider().overlay(Color.dynamic(light: "#E6D8D2", dark: "#343741"))

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Qty Ordered")
                        .font(.caption2)
                        .foregroundStyle(detailText)
                    Text("\(order.orderedQuantity) units")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(headingText)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Order Date")
                        .font(.caption2)
                        .foregroundStyle(detailText)
                    Text(order.orderDate.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(headingText)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Est. Delivery")
                        .font(.caption2)
                        .foregroundStyle(detailText)
                    Text(order.estimatedDelivery.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(headingText)
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 0.3)
        )
    }
}

// MARK: - Models

struct PastPartOrder: Identifiable {
    let id = UUID()
    let partName: String
    let partNumber: String
    let orderedQuantity: Int
    let orderDate: Date
    let status: PastPartOrderStatus
    let estimatedDelivery: Date
}

enum PastPartOrderStatus: String, CaseIterable, Identifiable {
    case delivered
    case inTransit
    case processing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .delivered:  "Delivered"
        case .inTransit:  "In Transit"
        case .processing: "Processing"
        }
    }

    var color: Color {
        switch self {
        case .delivered:  Color.dynamic(light: "#1E7A34", dark: "#6CDB80")
        case .inTransit:  Color.dynamic(light: "#1E5BE4", dark: "#7EA5FF")
        case .processing: Color.dynamic(light: "#8F4E00", dark: "#FFB874")
        }
    }
}
