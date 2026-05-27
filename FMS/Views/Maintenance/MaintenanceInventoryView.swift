
import SwiftUI

struct MaintenanceInventoryView: View {
    @Environment(AppViewModel.self) private var appViewModel
    private let allCategoriesLabel = "All"
    @State private var parts = InventoryPart.demoParts
    @State private var searchText = ""
    @State private var selectedPartForUsage: InventoryPart?
    @State private var sortLowStockFirst = true
    @State private var reorderMessage: String?
    @State private var selectedCategory = "All"

    private var accent: Color { Color(hex: "#FF5A1F") }
    private var headingText: Color { Color.dynamic(light: "#25262D", dark: "#E7E3E8") }
    private var detailText: Color { Color.dynamic(light: "#715B54", dark: "#E3C8BE") }
    private var availableCategories: [String] {
        let categories = parts.map { $0.category }
        let uniqueCategories = Array(Set(categories)).sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
        return [allCategoriesLabel] + uniqueCategories
    }

    private var visibleParts: [InventoryPart] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = parts.filter { part in
            let matchesSearch = query.isEmpty ||
                part.name.localizedCaseInsensitiveContains(query) ||
                part.partNumber.localizedCaseInsensitiveContains(query) ||
                part.category.localizedCaseInsensitiveContains(query)

            let matchesCategory = selectedCategory == allCategoriesLabel ||
                part.category.localizedCaseInsensitiveCompare(selectedCategory) == .orderedSame

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
            VStack(alignment: .leading, spacing: 12) {
                cardsGrid
                bubbleFilter
                inventoryList
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .navigationTitle("Inventory")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(uiColor: .systemGroupedBackground))
        .toolbarBackground(Color(uiColor: .systemGroupedBackground), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .searchable(text: $searchText, prompt: "Search name, part no. or category...")
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Image(systemName: icon)
                    .font(.callout)
                    .foregroundStyle(iconColor)
                    .frame(width: 30, height: 30)
                    .background(iconBg, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                Spacer()

                if let badgeCount = badgeCount {
                    Text("\(badgeCount)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.red, in: Capsule())
                } else if let value = value {
                    Text(value)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(headingText)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(detailText)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(headingText)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(detailText)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.dynamic(light: "#FFFFFF", dark: "#1B1C22"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.dynamic(light: "#E6D8D2", dark: "#353741"), lineWidth: 0.5)
        )
    }



    private var bubbleFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableCategories, id: \.self) { category in
                    let isSelected = selectedCategory == category
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            selectedCategory = category
                        }
                    } label: {
                        Text(category)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(isSelected ? .white : Color.dynamic(light: "#715B54", dark: "#E3C8BE"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(isSelected ? accent : Color.dynamic(light: "#FFFFFF", dark: "#202127"))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(isSelected ? Color.clear : Color.dynamic(light: "#E6D8D2", dark: "#353741"), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var activeInventoryHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(selectedCategory == allCategoriesLabel ? "Active Inventory" : selectedCategory)
                .font(.headline.weight(.bold))
                .foregroundStyle(headingText)

            Spacer()

            Text("\(visibleParts.count) items")
                .font(.caption.weight(.semibold))
                .foregroundStyle(detailText)
        }
    }

    private var inventoryList: some View {
        VStack(spacing: 6) {
            if visibleParts.isEmpty {
                EmptyStateView(
                    icon: "shippingbox",
                    title: "No matching parts",
                    message: "Try a different search or category filter."
                )
                .padding(.top, 8)
            } else {
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
        InventoryPart(id: UUID(), name: "Hydraulic Filter Assembly", partNumber: "#PN-8821", category: "Fluid System", quantity: 0, minimumRequired: 5, forecastDemand: 2, upcomingTaskCount: 2, leadTimeDays: 3, icon: "shippingbox", forecastKeyword: "filter"),
        InventoryPart(id: UUID(), name: "Heavy Duty Brake Pads", partNumber: "#PN-4402", category: "Brakes", quantity: 3, minimumRequired: 5, forecastDemand: 4, upcomingTaskCount: 3, leadTimeDays: 3, icon: "slider.horizontal.3", forecastKeyword: "brake"),
        InventoryPart(id: UUID(), name: "Semi-Synthetic Oil (5L)", partNumber: "#PN-1029", category: "Fluids", quantity: 112, minimumRequired: 20, forecastDemand: 20, upcomingTaskCount: 5, leadTimeDays: 2, icon: "drop.fill", forecastKeyword: "oil"),
        InventoryPart(id: UUID(), name: "Engine Gasket Kit V8", partNumber: "#PN-9283", category: "Engine", quantity: 45, minimumRequired: 8, forecastDemand: 6, upcomingTaskCount: 2, leadTimeDays: 4, icon: "rectangle.compress.vertical", forecastKeyword: "engine"),
        InventoryPart(id: UUID(), name: "Halogen Headlight Bulbs", partNumber: "#PN-3115", category: "Electrical", quantity: 8, minimumRequired: 12, forecastDemand: 3, upcomingTaskCount: 1, leadTimeDays: 2, icon: "lightbulb", forecastKeyword: "lamp"),
        InventoryPart(id: UUID(), name: "Fuel Filter Assembly", partNumber: "#PN-1205", category: "Fluid System", quantity: 12, minimumRequired: 10, forecastDemand: 5, upcomingTaskCount: 2, leadTimeDays: 3, icon: "line.3.horizontal.decrease", forecastKeyword: "fuel"),
        InventoryPart(id: UUID(), name: "Windshield Wiper Blades", partNumber: "#PN-5510", category: "Spare Parts", quantity: 24, minimumRequired: 10, forecastDemand: 8, upcomingTaskCount: 3, leadTimeDays: 2, icon: "car.window.right", forecastKeyword: "wiper"),
        InventoryPart(id: UUID(), name: "Side Mirror Assembly", partNumber: "#PN-6678", category: "Spare Parts", quantity: 6, minimumRequired: 4, forecastDemand: 2, upcomingTaskCount: 1, leadTimeDays: 5, icon: "rectangle.portrait.lefthalf.inset.filled", forecastKeyword: "mirror")
    ]
}

private struct InventoryPartRow: View {
    let part: InventoryPart
    let onAdd: () -> Void

    private var accent: Color { Color(hex: "#FF5A1F") }

    var body: some View {
        HStack(spacing: 12) {
            // ── Main info capsule (liquid glass) ──
            HStack(spacing: 10) {
                // Status indicator dot
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(part.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        Text(part.partNumber)
                            .font(.caption2.monospaced().weight(.medium))
                            .foregroundStyle(AppTheme.textSecondary)

                        Text("·")
                            .foregroundStyle(AppTheme.textSecondary)

                        Text(stockText)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(statusColor)
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.textSecondary.opacity(0.6))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                Capsule(style: .continuous)
                    .fill(.regularMaterial)
            )
            .glassEffect(.regular.interactive(), in: .capsule)

            // ── Plus button capsule (liquid glass) ──
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(.regularMaterial)
                    )
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    private var stockText: String {
        if part.isOutOfStock { return "OUT OF STOCK" }
        if part.isLowStock { return "\(part.quantity) remaining" }
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
}

private struct InventoryForecastView: View {
    let parts: [InventoryPart]
    let upcomingTaskCount: Int

    private var accent: Color { Color(hex: "#FF5A1F") }
    private var headingText: Color { Color.dynamic(light: "#25262D", dark: "#E7E3E8") }
    private var detailText: Color { Color.dynamic(light: "#715B54", dark: "#E3C8BE") }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                forecastHeader
                ForEach(parts.sorted { $0.statusRank > $1.statusRank }.prefix(5)) { part in
                    ForecastPartCard(part: part)
                }
                HStack(spacing: 10) {
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
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.dynamic(light: "#431300", dark: "#240900"))
                .frame(width: 40, height: 40)
                .background(Circle().fill(accent))
            VStack(alignment: .leading, spacing: 4) {
                Text("AI Forecast")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(headingText)
                Text("Based on upcoming \(max(upcomingTaskCount, 1) + 10) tasks")
                    .font(.caption2)
                    .foregroundStyle(detailText)
            }
            Spacer()
        }
        .padding(14)
        .background(Color.dynamic(light: "#FFFFFF", dark: "#1B1C22"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.dynamic(light: "#E6D8D2", dark: "#353741"), lineWidth: 0.5)
        )
    }
}

private struct ForecastPartCard: View {
    let part: InventoryPart

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(part.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Color.dynamic(light: "#25262D", dark: "#E7E3E8"))
                    Text(part.partNumber)
                        .font(.caption.monospaced().weight(.bold))
                        .foregroundStyle(Color(hex: "#FF5A1F"))
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(part.quantity) units")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(part.quantity < part.forecastDemand ? Color(hex: "#FFB0A3") : Color.dynamic(light: "#25262D", dark: "#E7E3E8"))
                    Text("In Stock")
                        .font(.caption)
                        .foregroundStyle(Color.dynamic(light: "#715B54", dark: "#D7B8AC"))
                }
            }

            Label("\(part.forecastDemand) required for \(part.upcomingTaskCount) tasks", systemImage: "calendar.badge.clock")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.dynamic(light: "#25262D", dark: "#E7E3E8"))

            Label(part.quantity < part.forecastDemand ? "Insufficient stock - Reorder needed" : "Stock levels sufficient", systemImage: part.quantity < part.forecastDemand ? "exclamationmark.triangle" : "checkmark.circle")
                .font(.caption.weight(.bold))
                .foregroundStyle(part.quantity < part.forecastDemand ? Color(hex: "#FFB0A3") : AppTheme.success)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(Color.dynamic(light: "#F1E8E5", dark: "#4A3F40"), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .padding(12)
        .background(Color.dynamic(light: "#FFFFFF", dark: "#1B1C22"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.dynamic(light: "#E6D8D2", dark: "#353741"), lineWidth: 0.5)
        )
    }
}

private struct ForecastMetricCard: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(Color(hex: "#FFB0A3"))
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.dynamic(light: "#25262D", dark: "#E7E3E8"))
            Text(label)
                .font(.caption2)
                .foregroundStyle(Color.dynamic(light: "#715B54", dark: "#D7B8AC"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.dynamic(light: "#FFFFFF", dark: "#1B1C22"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.dynamic(light: "#E6D8D2", dark: "#353741"), lineWidth: 0.5)
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
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Stock Alert")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var alertBanner: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "archivebox.fill")
                    .font(.system(.title2, design: .rounded))
                    .frame(width: 56, height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                Spacer()
                Text("PRIORITY HIGH")
                    .font(.system(.caption2, design: .rounded).monospaced().weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(.ultraThinMaterial))
                    .glassEffect(.regular, in: .capsule)
            }
            Text(part.isOutOfStock ? "Out of Stock Alert" : "Low Stock Alert")
                .font(.system(.title3, design: .rounded).weight(.bold))
            Text("Critical inventory threshold reached for fleet essential components.")
                .font(.system(.subheadline, design: .rounded))
        }
        .foregroundStyle(.white)
        .padding(18)
        .background(
            LinearGradient(colors: [Color(hex: "#FFB000"), Color(hex: "#FF5A1F")], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private var stockCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(part.name)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(.primary)
                    Text(part.partNumber)
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .foregroundStyle(Color(hex: "#FF5A1F"))
                }
                Spacer()
                Text(part.isOutOfStock ? "OUT" : "LOW")
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(part.isOutOfStock ? Color.red : Color.orange)
                    )
            }

            HStack(spacing: 12) {
                AlertMetricBox(title: "Current Stock", value: "\(part.quantity) units", emphasized: true)
                AlertMetricBox(title: "Min. Required", value: "\(part.minimumRequired) units", emphasized: false)
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)
        )
        .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
    }

    private var affectedWorkOrders: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Affected Work Orders")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                Spacer()
                Text("\(affectedOrders.count) Active")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                    .foregroundStyle(Color(hex: "#FF5A1F"))
            }

            ForEach(affectedOrders.prefix(3)) { order in
                HStack(spacing: 12) {
                    Image(systemName: "wrench.fill")
                        .font(.system(.callout, design: .rounded))
                        .foregroundStyle(Color(hex: "#FF5A1F"))
                        .frame(width: 42, height: 42)
                        .background(Color(hex: "#FF5A1F").opacity(0.12), in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text("WO #\(String(order.id.uuidString.prefix(4)))")
                            .font(.system(.caption, design: .monospaced).weight(.bold))
                            .foregroundStyle(.secondary)
                        Text(order.title)
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.regularMaterial)
                )
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
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
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color(hex: "#FF5A1F"), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)

            Button {
                didNotify = true
                onNotify()
            } label: {
                Label(didNotify ? "Manager Notified" : "Notify Manager", systemImage: "person.badge.plus")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(Color(hex: "#FF5A1F"))
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(.regularMaterial)
                    )
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
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
                .font(.system(.caption, design: .rounded))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundStyle(emphasized ? Color(hex: "#FF5A1F") : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .glassEffect(.regular, in: .rect(cornerRadius: 10))
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
