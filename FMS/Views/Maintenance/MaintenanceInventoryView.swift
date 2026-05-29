
import SwiftUI

// MARK: - Main View

struct MaintenanceInventoryView: View {
    @Environment(AppViewModel.self) private var appViewModel
    private let allCategoriesLabel = "All"

    @State private var parts: [SparePart] = []
    @State private var isLoading = false
    @State private var loadError: String?
    @State private var searchText = ""
    @State private var selectedCategory = "All"
    @State private var sortLowStockFirst = true
    @State private var toastMessage: String?
    @State private var showingAddPart = false
    @State private var partToEdit: SparePart?

    private var accent: Color { Color(hex: "#FF5A1F") }
    private var headingText: Color { Color.dynamic(light: "#25262D", dark: "#E7E3E8") }
    private var detailText: Color { Color.dynamic(light: "#715B54", dark: "#E3C8BE") }

    private var availableCategories: [String] {
        let cats = Array(Set(parts.map { $0.category })).sorted {
            $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
        }
        return [allCategoriesLabel] + cats
    }

    private var visibleParts: [SparePart] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = parts.filter { part in
            let matchesSearch = q.isEmpty ||
                part.name.localizedCaseInsensitiveContains(q) ||
                part.partNumber.localizedCaseInsensitiveContains(q) ||
                part.category.localizedCaseInsensitiveContains(q)
            let matchesCategory = selectedCategory == allCategoriesLabel ||
                part.category.localizedCaseInsensitiveCompare(selectedCategory) == .orderedSame
            return matchesSearch && matchesCategory
        }
        if sortLowStockFirst {
            return filtered.sorted {
                if statusRank($0) == statusRank($1) { return $0.name < $1.name }
                return statusRank($0) > statusRank($1)
            }
        }
        return filtered.sorted { $0.name < $1.name }
    }

    private func statusRank(_ p: SparePart) -> Int {
        if p.isOutOfStock { return 3 }
        if p.isLowStock   { return 2 }
        return 0
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
            .padding(.bottom, 96)
        }
        .navigationTitle("Inventory")
        .navigationBarTitleDisplayMode(.large)
        .background(Color(uiColor: .systemGroupedBackground))
        .searchable(text: $searchText, prompt: "Search name, part no. or category...")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddPart = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPart) {
            AddEditSparePartSheet(existingPart: nil) { newPart in
                Task { await savePart(newPart) }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $partToEdit) { part in
            AddEditSparePartSheet(existingPart: part) { updated in
                Task { await updatePart(updated) }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .overlay(toastOverlay)
        .task { await loadParts() }
        .refreshable { await loadParts() }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("inventoryNeedsRefresh"))) { _ in
            Task {
                await loadParts()
            }
        }
    }

    // MARK: – Toast
    @ViewBuilder private var toastOverlay: some View {
        if let msg = toastMessage {
            VStack {
                Spacer()
                Text(msg)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color(hex: "#222222").opacity(0.9), in: Capsule())
                    .padding(.bottom, 24)
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(duration: 0.4), value: toastMessage)
        }
    }

    private func showToast(_ msg: String) {
        withAnimation { toastMessage = msg }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation { toastMessage = nil }
        }
    }

    // MARK: – Cards

    private var cardsGrid: some View {
        HStack(spacing: 12) {
            gridCard(
                icon: "shippingbox.fill",
                title: "Total Parts",
                value: "\(parts.reduce(0) { $0 + $1.quantity })",
                subtitle: "\(parts.count) types",
                iconBg: Color.blue.opacity(0.15),
                iconColor: .blue
            )
            gridCard(
                icon: "exclamationmark.triangle.fill",
                title: "Low Stock",
                value: "\(parts.filter { $0.isLowStock || $0.isOutOfStock }.count)",
                subtitle: "Need attention",
                iconBg: Color.red.opacity(0.15),
                iconColor: .red
            )
        }
    }

    private func gridCard(
        icon: String,
        title: String,
        value: String,
        subtitle: String,
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
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(headingText)
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

    // MARK: – Category Filter

    private var bubbleFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableCategories, id: \.self) { category in
                    let isSelected = selectedCategory == category
                    if isSelected {
                        Button { selectedCategory = category } label: {
                            Text(category)
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .tint(accent)
                    } else {
                        Button { selectedCategory = category } label: {
                            Text(category)
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(.secondary)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: – List

    @ViewBuilder private var inventoryList: some View {
        if isLoading {
            ProgressView("Loading inventory…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
        } else if let err = loadError {
            VStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 36))
                    .foregroundStyle(.orange)
                Text(err)
                    .font(.subheadline)
                    .foregroundStyle(detailText)
                    .multilineTextAlignment(.center)
                Button("Retry") { Task { await loadParts() } }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
        } else if visibleParts.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "shippingbox")
                    .font(.system(size: 44))
                    .foregroundStyle(.gray.opacity(0.5))
                Text(parts.isEmpty ? "No parts yet" : "No matching parts")
                    .font(.headline)
                    .foregroundStyle(headingText)
                Text(parts.isEmpty ? "Tap + to add your first spare part." : "Try a different search or filter.")
                    .font(.subheadline)
                    .foregroundStyle(detailText)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        } else {
            VStack(spacing: 6) {
                ForEach(visibleParts) { part in
                    SparePartRow(part: part) {
                        partToEdit = part
                    } onDelete: {
                        Task { await deletePart(part) }
                    }
                }
            }
        }
    }

    // MARK: – Data Operations

    private func loadParts() async {
        guard let orgID = appViewModel.currentOrganization?.id else { return }
        isLoading = true
        loadError = nil
        do {
            parts = try await SupabaseService.shared.fetchSpareParts(organizationID: orgID)
            print("[Inventory] Loaded \(parts.count) spare parts ✅")
        } catch is CancellationError {
            // Ignore cancellation (normal on view transitions / refresh), but always
            // reset the loading flag so the spinner does not get stuck.
            isLoading = false
            return
        } catch {
            loadError = "Could not load inventory: \(error.localizedDescription)"
            print("[Inventory ERROR] \(error)")
        }
        isLoading = false
    }

    private func savePart(_ part: SparePart) async {
        do {
            try await SupabaseService.shared.addSparePart(part)
            await loadParts()
            showToast("✅ \(part.name) added to inventory.")
            await checkAndNotifyLowStock(part)
        } catch {
            showToast("❌ Failed to add part: \(error.localizedDescription)")
            print("[Inventory ERROR] addSparePart: \(error)")
        }
    }

    private func updatePart(_ part: SparePart) async {
        do {
            try await SupabaseService.shared.updateSparePart(part)
            if let idx = parts.firstIndex(where: { $0.id == part.id }) {
                parts[idx] = part
            }
            showToast("✅ \(part.name) updated.")
            await checkAndNotifyLowStock(part)
        } catch {
            showToast("❌ Failed to update: \(error.localizedDescription)")
            print("[Inventory ERROR] updateSparePart: \(error)")
        }
    }

    private func deletePart(_ part: SparePart) async {
        do {
            try await SupabaseService.shared.deleteSparePart(part)
            parts.removeAll { $0.id == part.id }
            showToast("🗑 \(part.name) removed.")
        } catch {
            showToast("❌ Failed to delete: \(error.localizedDescription)")
            print("[Inventory ERROR] deleteSparePart: \(error)")
        }
    }

    /// Sends a notification to both Maintenance Personnel and Fleet Manager if stock < 2
    private func checkAndNotifyLowStock(_ part: SparePart) async {
        guard part.isCriticallyLow else { return }
        let title = "⚠️ Low Stock Alert"
        let msg = "\(part.name) (\(part.partNumber)) has only \(part.quantity) unit\(part.quantity == 1 ? "" : "s") remaining — below critical threshold."

        // Notify Maintenance Personnel role
        appViewModel.service.addNotification(
            userID: nil,
            roleTarget: .maintenance,
            title: title,
            message: msg,
            category: .warning
        )
        // Notify Fleet Manager role
        appViewModel.service.addNotification(
            userID: nil,
            roleTarget: .fleetManager,
            title: title,
            message: msg,
            category: .warning
        )
        // Also reload notifications for the current user
        await appViewModel.loadNotifications()
    }
}

// MARK: - Spare Part Row

private struct SparePartRow: View {
    let part: SparePart
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var accent: Color { Color(hex: "#FF5A1F") }

    var body: some View {
        HStack(spacing: 12) {
            HStack(spacing: 10) {
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
                        Text(stockLabel)
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
            .background(Capsule(style: .continuous).fill(.regularMaterial))
            .glassEffect(.regular.interactive(), in: .capsule)
            .onTapGesture { onEdit() }

            // Edit / Delete
            Menu {
                Button { onEdit() } label: {
                    Label("Edit Part", systemImage: "pencil")
                }
                Button(role: .destructive) { onDelete() } label: {
                    Label("Delete Part", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.regularMaterial))
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 4)
    }

    private var stockLabel: String {
        if part.isOutOfStock { return "OUT OF STOCK" }
        if part.isCriticallyLow { return "\(part.quantity) – CRITICAL" }
        if part.isLowStock { return "\(part.quantity) remaining" }
        return "\(part.quantity) units"
    }

    private var statusColor: Color {
        if part.isOutOfStock { return Color.dynamic(light: "#BA1A1A", dark: "#FF8989") }
        if part.isCriticallyLow { return .orange }
        if part.isLowStock { return Color.dynamic(light: "#8F4E00", dark: "#FFB874") }
        return Color.dynamic(light: "#1E5BE4", dark: "#7EA5FF")
    }
}

// MARK: - Add / Edit Sheet

struct AddEditSparePartSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel

    let existingPart: SparePart?
    let onSave: (SparePart) -> Void

    @State private var name = ""
    @State private var partNumber = ""
    @State private var category = ""
    @State private var quantity = 0
    @State private var minimumRequired = 2
    @State private var selectedIcon = "shippingbox"

    private let iconOptions = [
        "shippingbox", "drop.fill", "slider.horizontal.3", "engine.combustion.fill",
        "lightbulb.fill", "line.3.horizontal.decrease", "car.window.right",
        "rectangle.portrait.lefthalf.inset.filled", "wrench.and.screwdriver.fill",
        "battery.100", "thermometer", "gear"
    ]

    private var accent: Color { Color(hex: "#FF5A1F") }
    private var isEditing: Bool { existingPart != nil }
    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !partNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !category.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(existingPart: SparePart?, onSave: @escaping (SparePart) -> Void) {
        self.existingPart = existingPart
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Part Details") {
                    TextField("Part Name", text: $name)
                    TextField("Part Number (e.g. #PN-1234)", text: $partNumber)
                    TextField("Category (e.g. Engine, Brakes)", text: $category)
                }

                Section("Stock") {
                    Stepper("Current Quantity: \(quantity)", value: $quantity, in: 0...9999)
                    Stepper("Minimum Required: \(minimumRequired)", value: $minimumRequired, in: 0...9999)
                    if quantity < 2 {
                        Label("Stock below 2 — a low-stock notification will be sent.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 6), spacing: 12) {
                        ForEach(iconOptions, id: \.self) { icon in
                            Button {
                                selectedIcon = icon
                            } label: {
                                Image(systemName: icon)
                                    .font(.title3)
                                    .frame(width: 44, height: 44)
                                    .background(
                                        selectedIcon == icon
                                            ? accent.opacity(0.2)
                                            : Color(uiColor: .systemGroupedBackground),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(selectedIcon == icon ? accent : Color.clear, lineWidth: 2)
                                    )
                                    .foregroundStyle(selectedIcon == icon ? accent : .secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle(isEditing ? "Edit Part" : "Add Spare Part")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let orgID = appViewModel.currentOrganization?.id else { return }
                        let part = SparePart(
                            id: existingPart?.id ?? UUID(),
                            organizationID: orgID,
                            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                            partNumber: partNumber.trimmingCharacters(in: .whitespacesAndNewlines),
                            category: category.trimmingCharacters(in: .whitespacesAndNewlines),
                            quantity: quantity,
                            minimumRequired: minimumRequired,
                            icon: selectedIcon
                        )
                        onSave(part)
                        dismiss()
                    }
                    .disabled(!canSave)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(canSave ? accent : .secondary)
                }
            }
            .onAppear {
                if let p = existingPart {
                    name = p.name
                    partNumber = p.partNumber
                    category = p.category
                    quantity = p.quantity
                    minimumRequired = p.minimumRequired
                    selectedIcon = p.icon
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MaintenanceInventoryView()
            .environment(AppViewModel())
    }
}
