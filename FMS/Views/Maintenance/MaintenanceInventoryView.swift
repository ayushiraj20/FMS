//Created by Mayurakshi Das
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
        [allCategoriesLabel] + Array(Set(parts.map(\.category)))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
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
            VStack(alignment: .leading, spacing: 18) {
                header
                cardsGrid
                searchField
                bubbleFilter
                activeInventoryHeader
                inventoryList
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 28)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
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
