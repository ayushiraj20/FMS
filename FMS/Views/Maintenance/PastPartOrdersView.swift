import SwiftUI

struct PastPartOrdersView: View {
    @Environment(AppViewModel.self) private var appViewModel
    private var accent: Color { Color(hex: "#FF5A1F") }
    private var headingText: Color { Color.dynamic(light: "#25262D", dark: "#E7E3E8") }
    private var detailText: Color { Color.dynamic(light: "#715B54", dark: "#E3C8BE") }

    @State private var selectedSegment: PartOrderStatus = .delivered
    @State private var isShowingNewOrder = false

    private var filteredOrders: [PartOrder] {
        appViewModel.service.partOrders.filter { $0.status == selectedSegment }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Segmented control
            Picker("Status", selection: $selectedSegment) {
                ForEach([PartOrderStatus.delivered, .inTransit, .processing], id: \.self) { status in
                    Text(status.rawValue).tag(status)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            ScrollView {
                VStack(spacing: 12) {
                    if filteredOrders.isEmpty {
                        EmptyStateView(
                            icon: "shippingbox",
                            title: "No \(selectedSegment.rawValue.lowercased()) orders",
                            message: "Orders with this status will appear here."
                        )
                        .padding(.top, 40)
                    } else {
                        ForEach(filteredOrders) { order in
                            orderCard(order)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 96)
            }
            .refreshable {
                await appViewModel.service.syncMaintenanceData()
            }
        }
        .navigationTitle("Past Orders")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingNewOrder = true
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                }
            }
        }
        .sheet(isPresented: $isShowingNewOrder) {
            NavigationStack {
                NewPartOrderSheet()
                    .environment(appViewModel)
            }
        }
        .task {
            await appViewModel.service.syncMaintenanceData()
        }
    }

    private func orderCard(_ order: PartOrder) -> some View {
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
                Text(order.status.rawValue.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusColor(order.status), in: Capsule())
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
                    if let delivery = order.estimatedDelivery {
                        Text(delivery.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(headingText)
                    } else {
                        Text("TBD")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(detailText)
                    }
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

    private func statusColor(_ status: PartOrderStatus) -> Color {
        switch status {
        case .delivered:  Color.dynamic(light: "#1E7A34", dark: "#6CDB80")
        case .inTransit:  Color.dynamic(light: "#1E5BE4", dark: "#7EA5FF")
        case .processing: Color.dynamic(light: "#8F4E00", dark: "#FFB874")
        case .cancelled:  Color.dynamic(light: "#BA1A1A", dark: "#FF8989")
        }
    }
}

// MARK: - New Part Order Sheet

struct NewPartOrderSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel

    @State private var partName = ""
    @State private var partNumber = ""
    @State private var quantity = 1
    @State private var estimatedDays = 3
    @State private var notes = ""

    private var accent: Color { Color(hex: "#FF5A1F") }

    var body: some View {
        Form {
            Section("Part Details") {
                TextField("Part Name", text: $partName)
                TextField("Part Number", text: $partNumber)
                    .textInputAutocapitalization(.characters)
                Stepper("Quantity: \(quantity)", value: $quantity, in: 1...100)
            }

            Section("Delivery") {
                Stepper("Est. Delivery: \(estimatedDays) days", value: $estimatedDays, in: 1...30)
            }

            Section("Notes (Optional)") {
                TextField("Additional notes...", text: $notes, axis: .vertical)
                    .lineLimit(3...5)
            }
        }
        .navigationTitle("New Part Order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Place Order") {
                    placeOrder()
                }
                .font(.body.weight(.bold))
                .foregroundStyle(accent)
                .disabled(partName.trimmingCharacters(in: .whitespaces).isEmpty || partNumber.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func placeOrder() {
        guard let orgID = appViewModel.currentOrganization?.id else { return }
        let order = PartOrder(
            organizationID: orgID,
            partName: partName.trimmingCharacters(in: .whitespaces),
            partNumber: partNumber.trimmingCharacters(in: .whitespaces),
            orderedQuantity: quantity,
            orderDate: .now,
            status: .processing,
            estimatedDelivery: Calendar.current.date(byAdding: .day, value: estimatedDays, to: .now),
            notes: notes.trimmingCharacters(in: .whitespaces)
        )
        appViewModel.service.addPartOrder(order)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        PastPartOrdersView()
            .environment(AppViewModel())
    }
}
