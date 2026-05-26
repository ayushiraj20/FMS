//Created by Mayurakshi Das
import SwiftUI

struct MaintenanceInventoryView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var parts = InventoryPart.demoParts
    @State private var searchText = ""
    @State private var selectedPartForUsage: InventoryPart?
    @State private var sortLowStockFirst = true
    @State private var reorderMessage: String?
    @State private var selectedCategory = "All"

    private var accent: Color { Color(hex: "#FF5A1F") }
    private var headingText: Color { Color.dynamic(light: "#25262D", dark: "#E7E3E8") }
    private var detailText: Color { Color.dynamic(light: "#715B54", dark: "#E3C8BE") }
    private var visibleParts: [InventoryPart] {
        let filtered = parts.filter { part in
            let matchesSearch = searchText.isEmpty ||
                part.name.localizedCaseInsensitiveContains(searchText) ||
                part.partNumber.localizedCaseInsensitiveContains(searchText) ||
                part.category.localizedCaseInsensitiveContains(searchText)
            
            let matchesCategory = selectedCategory == "All" || part.category == selectedCategory
            
            return matchesSearch && matchesCategory
        }

        if sortLowStockFirst {
            return filtered.sorted {
                if $0.statusRank == $1.statusRank {
                    return $0.name < $1.name
                }
                return $0.statusRank > $1.statusRank
            }
        }

        return filtered.sorted { $0.name < $1.name }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                cardsGrid
                searchField
                bubbleFilter
                inventoryList
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .navigationTitle("Inventory")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                NavigationLink {
                    InventoryForecastView(parts: parts, upcomingTaskCount: appViewModel.service.schedules().count)
                } label: {
                    Image(systemName: "wand.and.stars")
                }

                Button {
                    selectedPartForUsage = parts.first
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(item: $selectedPartForUsage) { part in
            AddSparePartSheet(
                part: part,
                allParts: parts,
                onApply: { partID, quantity in
                    consume(partID: partID, quantity: quantity)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .alert("Inventory Updated", isPresented: Binding(
            get: { reorderMessage != nil },
            set: { if !$0 { reorderMessage = nil } }
        )) {
            Button("OK", role: .cancel) { reorderMessage = nil }
        } message: {
            Text(reorderMessage ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Text("Inventory")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.dynamic(light: "#7A2618", dark: "#FFD1C6"))

            Spacer()

            NavigationLink {
                InventoryForecastView(parts: parts, upcomingTaskCount: appViewModel.service.schedules().count)
            } label: {
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(accent)
                    .frame(width: 34, height: 34)
            }

            Button {
                selectedPartForUsage = parts.first
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(accent)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
        }
    }

    private var cardsGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                // Card 1: Total Parts
                NavigationLink {
                    InventoryFilteredPartsView(
                        title: "Total Parts",
                        parts: parts,
                        affectedOrders: { affectedOrders(for: $0) },
                        onReorder: { reorder(partID: $0) },
                        onNotify: { reorderMessage = "Manager notified about \($0.name)." },
                        onConsume: { selectedPartForUsage = $0 }
                    )
                } label: {
                    gridCard(
                        icon: "shippingbox.fill",
                        title: "Total Parts",
                        subtitle: "Live stock",
                        value: "\(totalStock)",
                        badgeCount: nil,
                        iconBg: Color.blue.opacity(0.15),
                        iconColor: .blue
                    )
                }
                .buttonStyle(.plain)

                // Card 2: Low Stock
                NavigationLink {
                    InventoryFilteredPartsView(
                        title: "Low Stock Parts",
                        parts: parts.filter { $0.quantity <= $0.minimumRequired },
                        affectedOrders: { affectedOrders(for: $0) },
                        onReorder: { reorder(partID: $0) },
                        onNotify: { reorderMessage = "Manager notified about \($0.name)." },
                        onConsume: { selectedPartForUsage = $0 }
                    )
                } label: {
                    gridCard(
                        icon: "exclamationmark.triangle.fill",
                        title: "Low Stock",
                        subtitle: "\(lowStockCount) items low",
                        value: "\(lowStockCount)",
                        badgeCount: nil,
                        iconBg: Color.red.opacity(0.15),
                        iconColor: .red
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                // Card 3: AI Forecast
                NavigationLink {
                    InventoryForecastView(parts: parts, upcomingTaskCount: appViewModel.service.schedules().count)
                } label: {
                    gridCard(
                        icon: "brain.head.profile",
                        title: "AI Forecast",
                        subtitle: "Shortage risk",
                        value: nil,
                        badgeCount: forecastRiskCount > 0 ? forecastRiskCount : nil,
                        iconBg: Color.orange.opacity(0.15),
                        iconColor: .orange
                    )
                }
                .buttonStyle(.plain)

                // Card 4: Cancelled WO
                NavigationLink {
                    InventoryReconciliationView(onConfirm: { returnedParts in
                        for item in returnedParts {
                            restock(partID: item.partID, quantity: item.quantity)
                        }
                        reorderMessage = "Cancelled work order parts reconciled."
                    })
                } label: {
                    gridCard(
                        icon: "xmark.octagon.fill",
                        title: "Cancelled WO",
                        subtitle: "Reconcile parts",
                        value: nil,
                        badgeCount: nil,
                        iconBg: Color.purple.opacity(0.15),
                        iconColor: .purple
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func gridCard(
        icon: String,
        title: String,
        subtitle: String,
        value: String?,
        badgeCount: Int?,
        iconBg: Color,
        iconColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(iconColor)
                    .frame(width: 38, height: 38)
                    .background(iconBg, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                
                Spacer()
                
                if let badgeCount = badgeCount {
                    Text("\(badgeCount)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.red, in: Capsule())
                } else if let value = value {
                    Text(value)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(headingText)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(detailText)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(headingText)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(detailText)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dynamic(light: "#FFFFFF", dark: "#1B1C22"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.dynamic(light: "#E6D8D2", dark: "#353741"), lineWidth: 1)
        )
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(detailText)
            TextField("Search PN, description or category...", text: $searchText)
                .textInputAutocapitalization(.never)
                .foregroundStyle(headingText)
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(Color.dynamic(light: "#FFFFFF", dark: "#202127"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.dynamic(light: "#E6D8D2", dark: "#58372B"), lineWidth: 1)
        )
    }

    private var bubbleFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                let categories = ["All"] + Array(Set(parts.map { $0.category })).sorted()
                ForEach(categories, id: \.self) { category in
                    let isSelected = selectedCategory == category
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCategory = category
                        }
                    } label: {
                        Text(category)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? .white : Color.dynamic(light: "#715B54", dark: "#E3C8BE"))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(isSelected ? accent : Color.dynamic(light: "#FFFFFF", dark: "#202127"))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? Color.clear : Color.dynamic(light: "#E6D8D2", dark: "#353741"), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var activeInventoryHeader: some View {
        Text("Active Inventory")
            .font(.headline.weight(.bold))
            .foregroundStyle(headingText)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var inventoryList: some View {
        VStack(spacing: 10) {
            ForEach(visibleParts) { part in
                NavigationLink {
                    StockAlertView(
                        part: part,
                        affectedOrders: affectedOrders(for: part),
                        onReorder: { reorder(partID: part.id) },
                        onNotify: {
                            reorderMessage = "Manager notified about \(part.name)."
                        }
                    )
                } label: {
                    InventoryPartRow(part: part) {
                        selectedPartForUsage = part
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var totalStock: Int { parts.reduce(0) { $0 + $1.quantity } }
    private var lowStockCount: Int { parts.filter { $0.quantity <= $0.minimumRequired }.count }
    private var forecastRiskCount: Int { parts.filter { $0.quantity < $0.forecastDemand }.count }

    private func affectedOrders(for part: InventoryPart) -> [WorkOrder] {
        let activeOrders = appViewModel.service.workOrders.filter { $0.status != .completed }
        let keyword = part.forecastKeyword
        let matches = activeOrders.filter {
            $0.title.localizedCaseInsensitiveContains(keyword) ||
            $0.details.localizedCaseInsensitiveContains(keyword)
        }
        return matches.isEmpty ? Array(activeOrders.prefix(2)) : matches
    }

    private func consume(partID: UUID, quantity: Int) {
        guard let index = parts.firstIndex(where: { $0.id == partID }) else { return }
        parts[index].quantity = max(0, parts[index].quantity - quantity)
        reorderMessage = "\(quantity) \(quantity == 1 ? "unit" : "units") recorded for \(parts[index].name)."
    }

    private func reorder(partID: UUID) {
        guard let index = parts.firstIndex(where: { $0.id == partID }) else { return }
        let targetStock = max(parts[index].minimumRequired * 2, parts[index].forecastDemand + parts[index].leadTimeDays)
        let added = max(1, targetStock - parts[index].quantity)
        parts[index].quantity += added
        reorderMessage = "Reorder initiated. \(added) units added to incoming stock for \(parts[index].name)."
    }

    private func restock(partID: UUID, quantity: Int) {
        guard let index = parts.firstIndex(where: { $0.id == partID }) else { return }
        parts[index].quantity += quantity
    }
}

private struct InventoryPart: Identifiable, Hashable {
    let id: UUID
    var name: String
    var partNumber: String
    var category: String
    var quantity: Int
    var minimumRequired: Int
    var forecastDemand: Int
    var upcomingTaskCount: Int
    var leadTimeDays: Int
    var icon: String
    var forecastKeyword: String

    var isOutOfStock: Bool { quantity == 0 }
    var isLowStock: Bool { quantity > 0 && quantity <= minimumRequired }
    var statusRank: Int {
        if isOutOfStock { return 3 }
        if isLowStock { return 2 }
        if quantity < forecastDemand { return 1 }
        return 0
    }

    static let demoParts = [
        InventoryPart(id: UUID(), name: "Hydraulic Filter Assembly", partNumber: "#PN-8821", category: "Filters", quantity: 0, minimumRequired: 5, forecastDemand: 2, upcomingTaskCount: 2, leadTimeDays: 3, icon: "shippingbox", forecastKeyword: "filter"),
        InventoryPart(id: UUID(), name: "Heavy Duty Brake Pads", partNumber: "#PN-4402", category: "Brake System", quantity: 3, minimumRequired: 5, forecastDemand: 4, upcomingTaskCount: 3, leadTimeDays: 3, icon: "slider.horizontal.3", forecastKeyword: "brake"),
        InventoryPart(id: UUID(), name: "Semi-Synthetic Oil (5L)", partNumber: "#PN-1029", category: "Fluids", quantity: 112, minimumRequired: 20, forecastDemand: 20, upcomingTaskCount: 5, leadTimeDays: 2, icon: "drop.fill", forecastKeyword: "oil"),
        InventoryPart(id: UUID(), name: "Engine Gasket Kit V8", partNumber: "#PN-9283", category: "Engine", quantity: 45, minimumRequired: 8, forecastDemand: 6, upcomingTaskCount: 2, leadTimeDays: 4, icon: "rectangle.compress.vertical", forecastKeyword: "engine"),
        InventoryPart(id: UUID(), name: "Halogen Headlight Bulbs", partNumber: "#PN-3115", category: "Electrical", quantity: 8, minimumRequired: 12, forecastDemand: 3, upcomingTaskCount: 1, leadTimeDays: 2, icon: "lightbulb", forecastKeyword: "lamp"),
        InventoryPart(id: UUID(), name: "Fuel Filter Assembly", partNumber: "#PN-1205", category: "Filters", quantity: 12, minimumRequired: 10, forecastDemand: 5, upcomingTaskCount: 2, leadTimeDays: 3, icon: "line.3.horizontal.decrease", forecastKeyword: "fuel")
    ]
}

private struct InventorySummaryCard: View {
    let icon: String
    let label: String
    let value: String
    let title: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(tint)
                Spacer()
                Text(label)
                    .font(.caption2.monospaced().weight(.bold))
                    .foregroundStyle(Color.dynamic(light: "#715B54", dark: "#D7B8AC"))
            }
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.dynamic(light: "#25262D", dark: "#E7E3E8"))
            Text(title)
                .font(.caption)
                .foregroundStyle(Color.dynamic(light: "#715B54", dark: "#D7B8AC"))
        }
        .frame(width: 132, alignment: .leading)
        .frame(minHeight: 82, alignment: .leading)
        .padding(14)
        .background(Color.dynamic(light: "#FFFFFF", dark: "#1B1C22"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.dynamic(light: "#E6D8D2", dark: "#353741"), lineWidth: 1)
        )
    }
}

private struct InventoryPartRow: View {
    let part: InventoryPart
    let onAdd: () -> Void

    private var accent: Color { Color(hex: "#FF5A1F") }

    var body: some View {
        HStack(spacing: 14) {
            Rectangle()
                .fill(statusColor)
                .frame(width: 6)

            VStack(alignment: .leading, spacing: 5) {
                Text(part.partNumber)
                    .font(.caption.monospaced().weight(.bold))
                    .foregroundStyle(accent)
                Text(part.name)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color.dynamic(light: "#25262D", dark: "#E7E3E8"))
                    .lineLimit(2)
                Text(stockText)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(statusColor)
            }
            .padding(.vertical, 12)

            Spacer()

            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(accent, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .buttonStyle(.plain)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.dynamic(light: "#D0C8C5", dark: "#5E5552"))
                .padding(.trailing, 14)
        }
        .frame(minHeight: 82)
        .background(backgroundColor)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(strokeColor, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var stockText: String {
        if part.isOutOfStock { return "OUT OF STOCK" }
        if part.isLowStock { return "\(part.quantity) units remaining" }
        return "\(part.quantity) units"
    }

    private var statusColor: Color {
        if part.isOutOfStock {
            return Color.dynamic(light: "#BA1A1A", dark: "#FF8989")
        }
        if part.isLowStock {
            return Color.dynamic(light: "#8F4E00", dark: "#FFB874")
        }
        return Color.dynamic(light: "#1E5BE4", dark: "#7EA5FF")
    }

    private var backgroundColor: Color {
        if part.isOutOfStock {
            return Color.dynamic(light: "#FFF1F1", dark: "#2C1416")
        }
        if part.isLowStock {
            return Color.dynamic(light: "#FFF9F6", dark: "#2A1810")
        }
        return Color.dynamic(light: "#FFFFFF", dark: "#1B1C22")
    }

    private var strokeColor: Color {
        if part.isOutOfStock {
            return Color.dynamic(light: "#F5C2C2", dark: "#5E292C")
        }
        if part.isLowStock {
            return Color.dynamic(light: "#F7D8BF", dark: "#5C3822")
        }
        return Color.dynamic(light: "#D8E1F7", dark: "#2A3C63")
    }
}

private struct InventoryForecastView: View {
    let parts: [InventoryPart]
    let upcomingTaskCount: Int

    private var accent: Color { Color(hex: "#FF5A1F") }
    private var headingText: Color { Color.dynamic(light: "#25262D", dark: "#E7E3E8") }
    private var detailText: Color { Color.dynamic(light: "#715B54", dark: "#E3C8BE") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                forecastHeader
                ForEach(parts.sorted { $0.statusRank > $1.statusRank }.prefix(5)) { part in
                    ForecastPartCard(part: part)
                }
                HStack(spacing: 14) {
                    ForecastMetricCard(icon: "chart.line.uptrend.xyaxis", value: "94%", label: "Forecast Accuracy")
                    ForecastMetricCard(icon: "clock", value: "3 Days", label: "Avg Lead Time")
                }
            }
            .padding(16)
        }
        .navigationTitle("AI Parts Forecast")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var forecastHeader: some View {
        HStack(spacing: 14) {
            Image(systemName: "brain.head.profile")
                .font(.title2.weight(.bold))
                .foregroundStyle(Color.dynamic(light: "#431300", dark: "#240900"))
                .frame(width: 52, height: 52)
                .background(Circle().fill(accent))
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Forecast")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(headingText)
                Text("Based on upcoming \(max(upcomingTaskCount, 1) + 10) maintenance tasks")
                    .font(.caption)
                    .foregroundStyle(detailText)
            }
            Spacer()
        }
        .padding(18)
        .background(Color.dynamic(light: "#FFFFFF", dark: "#1B1C22"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.dynamic(light: "#E6D8D2", dark: "#353741"), lineWidth: 1)
        )
    }
}

private struct ForecastPartCard: View {
    let part: InventoryPart

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(part.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color.dynamic(light: "#25262D", dark: "#E7E3E8"))
                    Text(part.partNumber)
                        .font(.caption.monospaced().weight(.bold))
                        .foregroundStyle(Color(hex: "#FF5A1F"))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(part.quantity) units")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(part.quantity < part.forecastDemand ? Color(hex: "#FFB0A3") : Color.dynamic(light: "#25262D", dark: "#E7E3E8"))
                    Text("In Stock")
                        .font(.caption)
                        .foregroundStyle(Color.dynamic(light: "#715B54", dark: "#D7B8AC"))
                }
            }

            Label("\(part.forecastDemand) units required for \(part.upcomingTaskCount) upcoming tasks", systemImage: "calendar.badge.clock")
                .font(.headline.weight(.semibold))
                .foregroundStyle(Color.dynamic(light: "#25262D", dark: "#E7E3E8"))

            Label(part.quantity < part.forecastDemand ? "Insufficient stock - Reorder needed" : "Stock levels sufficient", systemImage: part.quantity < part.forecastDemand ? "exclamationmark.triangle" : "checkmark.circle")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(part.quantity < part.forecastDemand ? Color(hex: "#FFB0A3") : AppTheme.success)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.horizontal, 12)
                .background(Color.dynamic(light: "#F1E8E5", dark: "#4A3F40"), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(18)
        .background(Color.dynamic(light: "#FFFFFF", dark: "#1B1C22"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.dynamic(light: "#E6D8D2", dark: "#353741"), lineWidth: 1)
        )
    }
}

private struct ForecastMetricCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(Color(hex: "#FFB0A3"))
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.dynamic(light: "#25262D", dark: "#E7E3E8"))
            Text(label)
                .font(.caption)
                .foregroundStyle(Color.dynamic(light: "#715B54", dark: "#D7B8AC"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.dynamic(light: "#FFFFFF", dark: "#1B1C22"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.dynamic(light: "#E6D8D2", dark: "#353741"), lineWidth: 1)
        )
    }
}

private struct AddSparePartSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPartID: UUID
    @State private var quantity = 1
    @State private var searchText = ""

    let allParts: [InventoryPart]
    let onApply: (UUID, Int) -> Void

    init(part: InventoryPart, allParts: [InventoryPart], onApply: @escaping (UUID, Int) -> Void) {
        _selectedPartID = State(initialValue: part.id)
        self.allParts = allParts
        self.onApply = onApply
    }

    private var filteredParts: [InventoryPart] {
        allParts.filter {
            searchText.isEmpty ||
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.partNumber.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                    TextField("Search inventory...", text: $searchText)
                }
                .padding(.horizontal, 14)
                .frame(height: 46)
                .background(Color.dynamic(light: "#FFFFFF", dark: "#202127"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.dynamic(light: "#E6D8D2", dark: "#353741"), lineWidth: 1))

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(filteredParts) { part in
                            Button {
                                selectedPartID = part.id
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: part.icon)
                                        .frame(width: 42, height: 42)
                                        .background(Color.dynamic(light: "#EEF0F4", dark: "#30323A"), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(part.name)
                                            .font(.subheadline.weight(.bold))
                                        Text("\(part.partNumber) - \(part.quantity) units in stock")
                                            .font(.caption.monospaced())
                                            .foregroundStyle(Color.dynamic(light: "#715B54", dark: "#D7B8AC"))
                                    }
                                    Spacer()
                                    if selectedPartID == part.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color(hex: "#FF5A1F"))
                                    }
                                }
                                .foregroundStyle(Color.dynamic(light: "#25262D", dark: "#E7E3E8"))
                                .padding(12)
                                .background(Color.dynamic(light: "#FFFFFF", dark: "#1B1C22"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(selectedPartID == part.id ? Color(hex: "#FF5A1F") : Color.dynamic(light: "#E6D8D2", dark: "#353741"), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack {
                    Text("Quantity")
                        .font(.headline.weight(.bold))
                    Spacer()
                    Button { quantity = max(1, quantity - 1) } label: {
                        Image(systemName: "minus")
                            .frame(width: 36, height: 36)
                            .overlay(Circle().stroke(Color(hex: "#FF5A1F"), lineWidth: 1))
                    }
                    Text("\(quantity)")
                        .font(.title3.weight(.bold))
                        .frame(width: 40)
                    Button { quantity += 1 } label: {
                        Image(systemName: "plus")
                            .frame(width: 36, height: 36)
                            .background(Circle().fill(Color(hex: "#FF5A1F")))
                            .foregroundStyle(Color.dynamic(light: "#431300", dark: "#240900"))
                    }
                }
            }
            .padding(16)
            .navigationTitle("Add Spare Part")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onApply(selectedPartID, quantity)
                        dismiss()
                    }
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Color(hex: "#FF5A1F"))
                }
            }
        }
    }
}

private struct StockAlertView: View {
    let part: InventoryPart
    let affectedOrders: [WorkOrder]
    let onReorder: () -> Void
    let onNotify: () -> Void
    @State private var didReorder = false
    @State private var didNotify = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                alertBanner
                stockCard
                affectedWorkOrders
                actionButtons
            }
            .padding(16)
        }
        .navigationTitle("Stock Alert")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var alertBanner: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "archivebox.fill")
                    .font(.title2)
                    .frame(width: 56, height: 56)
                    .background(.white.opacity(0.18), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                Spacer()
                Text("PRIORITY HIGH")
                    .font(.caption2.monospaced().weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(.white.opacity(0.18), in: Capsule())
            }
            Text(part.isOutOfStock ? "Out of Stock Alert" : "Low Stock Alert")
                .font(.title3.weight(.bold))
            Text("Critical inventory threshold reached for fleet essential components.")
                .font(.subheadline)
        }
        .foregroundStyle(.white)
        .padding(18)
        .background(
            LinearGradient(colors: [Color(hex: "#FFB000"), Color(hex: "#FF5A1F")], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
    }

    private var stockCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(part.name)
                        .font(.headline.weight(.bold))
                    Text(part.partNumber)
                        .font(.caption.monospaced().weight(.bold))
                        .foregroundStyle(Color(hex: "#FFB0A3"))
                }
                Spacer()
                Text(part.isOutOfStock ? "OUT" : "LOW STOCK")
                    .font(.caption2.monospaced().weight(.bold))
                    .foregroundStyle(Color(hex: "#FFB0A3"))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#FF5A1F").opacity(0.18), in: Capsule())
            }

            HStack(spacing: 14) {
                AlertMetricBox(title: "Current Stock", value: "\(part.quantity) units", emphasized: true)
                AlertMetricBox(title: "Min. Required", value: "\(part.minimumRequired) units", emphasized: false)
            }
        }
        .padding(18)
        .background(Color.dynamic(light: "#FFFFFF", dark: "#1B1C22"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.dynamic(light: "#E6D8D2", dark: "#353741"), lineWidth: 1))
    }

    private var affectedWorkOrders: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Affected Work Orders")
                    .font(.headline.weight(.bold))
                Spacer()
                Text("\(affectedOrders.count) Active")
                    .font(.caption.monospaced().weight(.bold))
                    .foregroundStyle(Color(hex: "#FFB0A3"))
            }

            ForEach(affectedOrders.prefix(3)) { order in
                HStack(spacing: 12) {
                    Image(systemName: "wrench.fill")
                        .foregroundStyle(Color(hex: "#FFB0A3"))
                        .frame(width: 42, height: 42)
                        .background(Color(hex: "#FF5A1F").opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WO #\(String(order.id.uuidString.prefix(4)))")
                            .font(.caption.monospaced().weight(.bold))
                            .foregroundStyle(Color(hex: "#FFB0A3"))
                        Text(order.title)
                            .font(.subheadline.weight(.bold))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(Color.dynamic(light: "#715B54", dark: "#D7B8AC"))
                }
                .padding(14)
                .background(Color.dynamic(light: "#FFFFFF", dark: "#1B1C22"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.dynamic(light: "#E6D8D2", dark: "#353741"), lineWidth: 1))
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button {
                didReorder = true
                onReorder()
            } label: {
                Label(didReorder ? "Reorder Initiated" : "Initiate Reorder", systemImage: "cart.badge.plus")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.dynamic(light: "#431300", dark: "#240900"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(hex: "#FF5A1F"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                didNotify = true
                onNotify()
            } label: {
                Label(didNotify ? "Manager Notified" : "Notify Manager", systemImage: "person.badge.plus")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Color.dynamic(light: "#7A2618", dark: "#FFD1C6"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.dynamic(light: "#7A2618", dark: "#FFD1C6"), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }
}

private struct AlertMetricBox: View {
    let title: String
    let value: String
    let emphasized: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(emphasized ? Color(hex: "#FFB0A3") : Color.dynamic(light: "#25262D", dark: "#E7E3E8"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.dynamic(light: "#F3F4F7", dark: "#22242B"), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct InventoryDetailKeyValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color.dynamic(light: "#715B54", dark: "#D7B8AC"))
            Spacer()
            Text(value)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.dynamic(light: "#25262D", dark: "#E7E3E8"))
        }
    }
}

private struct ReturnedInventoryItem: Identifiable {
    let id = UUID()
    let partID: UUID
    let name: String
    let quantity: Int
    var isReturned: Bool
}

private struct InventoryReconciliationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var returnedItems = [
        ReturnedInventoryItem(partID: InventoryPart.demoParts[1].id, name: "Heavy Duty Brake Pads", quantity: 2, isReturned: true),
        ReturnedInventoryItem(partID: InventoryPart.demoParts[2].id, name: "Synthetic Oil Filter", quantity: 1, isReturned: true),
        ReturnedInventoryItem(partID: InventoryPart.demoParts[5].id, name: "Air Intake Sensor", quantity: 1, isReturned: false)
    ]

    let onConfirm: ([ReturnedInventoryItem]) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                cancelledHeader
                Text("Reconcile Recorded Parts")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.dynamic(light: "#7A2618", dark: "#FFD1C6"))

                ForEach($returnedItems) { $item in
                    Toggle(isOn: $item.isReturned) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(item.name)
                                .font(.headline.weight(.bold))
                            Text("\(item.quantity) \(item.quantity == 1 ? "UNIT" : "UNITS")")
                                .font(.title3.monospaced().weight(.bold))
                                .foregroundStyle(Color(hex: "#FF5A1F"))
                        }
                    }
                    .tint(Color(hex: "#FF5A1F"))
                    .padding(22)
                    .background(Color.dynamic(light: "#FFFFFF", dark: "#1B1C22"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.dynamic(light: "#E6D8D2", dark: "#353741"), lineWidth: 1))
                }

                logDetails
                infoBox
                confirmButton
            }
            .padding(16)
        }
        .navigationTitle("Alerts")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var cancelledHeader: some View {
        VStack(spacing: 10) {
            Text("Order Cancelled")
                .font(.title2.weight(.bold))
            Text("Work Order Cancelled")
                .font(.title3.weight(.bold))
            Text("#WO-2847  Annual Service")
            Text("Cancelled \(Date.now.formatted(date: .omitted, time: .shortened)) today")
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(LinearGradient(colors: [Color(hex: "#EF3340"), Color(hex: "#D71920")], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var logDetails: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("LOG DETAILS")
                .font(.caption.monospaced().weight(.bold))
                .tracking(2)
                .foregroundStyle(Color.dynamic(light: "#715B54", dark: "#D7B8AC"))
            InventoryDetailKeyValueRow(title: "WO Reference", value: "#WO-2847")
            InventoryDetailKeyValueRow(title: "Technician", value: "Marcus Reid")
            InventoryDetailKeyValueRow(title: "Time", value: Date.now.formatted(date: .omitted, time: .shortened))
            InventoryDetailKeyValueRow(title: "Total Parts Recorded", value: "\(returnedItems.reduce(0) { $0 + $1.quantity })")
        }
        .padding(22)
        .background(Color.dynamic(light: "#FFFFFF", dark: "#1B1C22"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.dynamic(light: "#E6D8D2", dark: "#353741"), lineWidth: 1))
    }

    private var infoBox: some View {
        Label("Unreturned parts will be flagged as lost inventory in the next cycle count. Ensure all parts are physically returned to the cage before confirming.", systemImage: "info.circle")
            .font(.subheadline)
            .foregroundStyle(Color.dynamic(light: "#715B54", dark: "#A6A8B1"))
            .lineSpacing(5)
            .padding(22)
            .background(Color.dynamic(light: "#F3F4F7", dark: "#181922"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.dynamic(light: "#E6D8D2", dark: "#353741").opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [3, 3])))
    }

    private var confirmButton: some View {
        Button {
            onConfirm(returnedItems.filter(\.isReturned))
            dismiss()
        } label: {
            Label("Confirm Inventory Correction", systemImage: "archivebox")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.dynamic(light: "#431300", dark: "#240900"))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(Color(hex: "#FF5A1F"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

private struct InventoryFilteredPartsView: View {
    let title: String
    let parts: [InventoryPart]
    let affectedOrders: (InventoryPart) -> [WorkOrder]
    let onReorder: (UUID) -> Void
    let onNotify: (InventoryPart) -> Void
    let onConsume: (InventoryPart) -> Void

    private var headingText: Color { Color.dynamic(light: "#25262D", dark: "#E7E3E8") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if parts.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "archivebox")
                            .font(.system(size: 44))
                            .foregroundStyle(Color.gray.opacity(0.6))
                        Text("No parts to display")
                            .font(.headline)
                            .foregroundStyle(headingText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    ForEach(parts) { part in
                        NavigationLink {
                            StockAlertView(
                                part: part,
                                affectedOrders: affectedOrders(part),
                                onReorder: { onReorder(part.id) },
                                onNotify: { onNotify(part) }
                            )
                        } label: {
                            InventoryPartRow(part: part) {
                                onConsume(part)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        MaintenanceInventoryView()
            .environment(AppViewModel())
    }
}
