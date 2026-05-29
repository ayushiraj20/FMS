import SwiftUI

struct MaintenanceWorkOrdersView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var searchText = ""
    @State private var selectedOrder: WorkOrder?
    private let initialFilter: MaintenanceOrderProgressFilter
    private let initialShowOnlyCritical: Bool
    private let isLockedFilter: Bool

    @State private var selectedFilter: MaintenanceOrderProgressFilter
    @State private var isShowingCalendar = false
    @State private var showOnlyCritical: Bool
    
    init(initialFilter: MaintenanceOrderProgressFilter = .all, showOnlyCritical: Bool = false, isLockedFilter: Bool = false) {
        self.initialFilter = initialFilter
        self.initialShowOnlyCritical = showOnlyCritical
        self.isLockedFilter = isLockedFilter
        _selectedFilter = State(initialValue: initialFilter)
        _showOnlyCritical = State(initialValue: showOnlyCritical)
    }
    

    
    private var currentUser: User? { appViewModel.currentUser }
    private var orders: [WorkOrder] {
        appViewModel.service
            .workOrders(for: currentUser?.id)
            .filter {
                if showOnlyCritical {
                    // Show all critical orders (except completed and in-progress ones) regardless of status filter
                    return $0.priority == .critical && $0.status != .completed && $0.status != .inProgress &&
                        (searchText.isEmpty ||
                         $0.title.localizedCaseInsensitiveContains(searchText) ||
                         $0.details.localizedCaseInsensitiveContains(searchText) ||
                         (appViewModel.service.vehicle(for: $0.vehicleID)?.displayName.localizedCaseInsensitiveContains(searchText) ?? false) ||
                         (appViewModel.service.vehicle(for: $0.vehicleID)?.plateNumber.localizedCaseInsensitiveContains(searchText) ?? false))
                } else {
                    return selectedFilter.matches($0.status) &&
                        (searchText.isEmpty ||
                         $0.title.localizedCaseInsensitiveContains(searchText) ||
                         $0.details.localizedCaseInsensitiveContains(searchText) ||
                         (appViewModel.service.vehicle(for: $0.vehicleID)?.displayName.localizedCaseInsensitiveContains(searchText) ?? false) ||
                         (appViewModel.service.vehicle(for: $0.vehicleID)?.plateNumber.localizedCaseInsensitiveContains(searchText) ?? false))
                }
            }
            .sorted {
                // Overdue critical orders always float to the very top
                if $0.isOverdue != $1.isOverdue { return $0.isOverdue }
                return priorityValue($0.priority) > priorityValue($1.priority) ||
                (priorityValue($0.priority) == priorityValue($1.priority) && $0.scheduledDate < $1.scheduledDate)
            }
    }
    
    private func priorityValue(_ priority: WorkOrderPriority) -> Int {
        switch priority {
        case .critical: return 4
        case .high:     return 3
        case .medium:   return 2
        case .low:      return 1
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if !showOnlyCritical && !isLockedFilter {
                filterBar
            }
            
            ordersList
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(showOnlyCritical ? "Critical" : (isLockedFilter ? selectedFilter.title : "Work Orders"))
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingCalendar = true
                } label: {
                    Image(systemName: "calendar")
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search work orders")
        .sheet(item: $selectedOrder) { order in
            MaintenanceOrderUpdateSheet(workOrder: order)
                .environment(appViewModel)
        }
        .sheet(isPresented: $isShowingCalendar) {
            NavigationStack {
                MaintenanceCalendarView(orders: appViewModel.service.workOrders(for: currentUser?.id))
                    .environment(appViewModel)
            }
        }
        .onAppear {
            selectedFilter = initialFilter
            showOnlyCritical = initialShowOnlyCritical
        }
    }
    
    // MARK: - Subviews
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(MaintenanceOrderProgressFilter.allCases) { filter in
                    if selectedFilter == filter {
                        Button {
                            selectedFilter = filter
                        } label: {
                            Text(filter.title)
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .tint(ordersAccent)
                        .foregroundStyle(.white)
                    } else {
                        Button {
                            selectedFilter = filter
                        } label: {
                            Text(filter.title)
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                        }
                        .buttonStyle(.bordered)
                        .buttonBorderShape(.capsule)
                        .tint(.secondary)
                        .foregroundStyle(.primary)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
    
    private var ordersList: some View {
        List {
            if orders.isEmpty {
                EmptyStateView(
                    icon: "list.clipboard",
                    title: "No work orders here",
                    message: selectedFilter.emptyMessage
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            } else {
                ForEach(orders) { order in
                    ZStack {
                        MaintenanceWorkOrderCard(
                            order: order,
                            vehicle: appViewModel.service.vehicle(for: order.vehicleID)
                        )
                        
                        NavigationLink {
                            MaintenanceWorkOrderDetailView(workOrder: order)
                                .environment(appViewModel)
                        } label: {
                            EmptyView()
                        }
                        .opacity(0)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            markOrderDone(order)
                        } label: {
                            Label("Done", systemImage: "checkmark.circle.fill")
                        }
                        .tint(AppTheme.success)
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await appViewModel.service.syncWithDatabase()
        }
        .background(Color.clear)
    }
    
    private var ordersAccent: Color { Color(hex: "#FF5A1F") }
    private var warmSecondaryText: Color { Color.dynamic(light: "#715B54", dark: "#D7B8AC") }
    

    
    private func markOrderDone(_ order: WorkOrder) {
        var updatedOrder = order
        updatedOrder.status = .completed
        updatedOrder.completedDate = .now
        if updatedOrder.repairSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            updatedOrder.repairSummary = "Marked done by maintenance staff."
        }
        appViewModel.service.updateWorkOrder(updatedOrder)
    }
    
    // MARK: - Filter Enum
    
    enum MaintenanceOrderProgressFilter: String, CaseIterable, Identifiable {
        case all
        case open
        case inProgress
        case done

        static var allCases: [MaintenanceOrderProgressFilter] {
            [.all, .open, .inProgress, .done]
        }
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .all:          "All"
            case .open:         "To Start"
            case .inProgress:   "In Progress"
            case .done:         "Done"
            }
        }
        
        var emptyMessage: String {
            switch self {
            case .all:          "No work orders found."
            case .open:         "No newly assigned work orders right now."
            case .inProgress:   "No work orders are currently in progress."
            case .done:         "Completed work will appear here after you mark it done."
            }
        }
        
        func matches(_ status: WorkOrderStatus) -> Bool {
            switch self {
            case .all:          true
            case .open:         status == .open || status == .waitingParts
            case .inProgress:   status == .inProgress
            case .done:         status == .completed
            }
        }
    }
    
    // MARK: - Card
    
    struct MaintenanceWorkOrderCard: View {
        let order: WorkOrder
        let vehicle: Vehicle?
        
        var body: some View {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    
                    // MARK: Top row: WO ID + priority/overdue badges
                    HStack(alignment: .center, spacing: 8) {
                        Text("#WO-\(String(order.id.uuidString.prefix(4)))")
                            .font(.system(.caption, design: .monospaced).weight(.bold))
                            .foregroundStyle(Color.secondary)
                        
                        Spacer()
                        
                        if order.isOverdue {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.clock.fill")
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                Text("OVERDUE")
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.red, in: Capsule())
                        } else if order.priority == .critical {
                            Text("URGENT")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.red, in: Capsule())
                        }
                        
                        Text(order.priority.rawValue.uppercased())
                            .font(.system(size: 8, weight: .black, design: .rounded))
                            .foregroundStyle(priorityTextColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(priorityBackgroundColor, in: Capsule())
                    }
                    
                    // MARK: Vehicle + title + details
                    VStack(alignment: .leading, spacing: 4) {
                        Text(order.title)
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(Color(.label))
                            .lineLimit(2)
                        
                        Text(vehicle?.displayName ?? "Assigned Vehicle")
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .foregroundStyle(Color.secondary)
                        
                        if !order.details.isEmpty {
                            Text(order.details)
                                .font(.system(.footnote, design: .rounded))
                                .foregroundStyle(Color.secondary)
                                .lineLimit(2)
                                .padding(.top, 2)
                        }
                    }
                    
                    Divider()
                        .background(Color(.separator))
                    
                    // MARK: Footer: scheduled time + status
                    HStack(spacing: 8) {
                        Label(order.scheduledDate.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                        
                        Spacer()
                        
                        Label(order.status.rawValue.uppercased(), systemImage: statusIcon)
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(statusColor)
                    }
                    .foregroundStyle(Color.secondary)
                }
                
                // MARK: iOS Navigation Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .padding(.leading, 2)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
            )
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 16))
        }
        
        // MARK: - Derived style helpers
        
        private var borderColor: Color {
            if order.isOverdue { return Color.red.opacity(0.4) }
            if order.priority == .critical { return Color.red.opacity(0.3) }
            return Color(.separator)
        }
        
        private var borderWidth: CGFloat {
            if order.isOverdue || order.priority == .critical { return 1.0 }
            return 0.5
        }
        
        private var priorityTextColor: Color {
            switch order.priority {
            case .low:      return AppTheme.success
            case .medium:   return Color.orange
            case .high:     return Color(hex: "#FF5A1F")
            case .critical: return Color.red
            }
        }
        
        private var priorityBackgroundColor: Color {
            switch order.priority {
            case .low:      return AppTheme.success.opacity(0.12)
            case .medium:   return Color.orange.opacity(0.12)
            case .high:     return Color(hex: "#FF5A1F").opacity(0.12)
            case .critical: return Color.red.opacity(0.12)
            }
        }
        
        private var statusColor: Color {
            switch order.status {
            case .open:         return Color.secondary
            case .inProgress:   return Color(hex: "#2EA7FF")
            case .waitingParts: return AppTheme.warning
            case .completed:    return AppTheme.success
            }
        }
        
        private var statusIcon: String {
            switch order.status {
            case .open:         return "ellipsis.circle"
            case .inProgress:   return "arrow.triangle.2.circlepath"
            case .waitingParts: return "shippingbox"
            case .completed:    return "checkmark.circle.fill"
            }
        }
    }
    
    // MARK: - Detail View
    
    struct MaintenanceWorkOrderDetailView: View {
        @Environment(\.dismiss) private var dismiss
        @Environment(AppViewModel.self) private var appViewModel
        @State private var workOrder: WorkOrder
        @State private var selectedStatus: WorkOrderStatus
        @State private var labourHours = "0"
        @State private var labourMinutes = "0"
        @State private var isShowingLabourSheet = false
        @State private var isShowingPartsSheet = false
        @State private var inventoryParts: [SparePart] = []
        @State private var partsLoadError: String?
        @State private var isLoadingParts = false
        @State private var selectedParts: [WorkOrderPartSelection] = []
        
        init(workOrder: WorkOrder) {
            _workOrder = State(initialValue: workOrder)
            _selectedStatus = State(initialValue: workOrder.status == .waitingParts ? .open : workOrder.status)
        }
        
        private var vehicle: Vehicle? { appViewModel.service.vehicle(for: workOrder.vehicleID) }
        private var accent: Color { Color(hex: "#FF5A1F") }
        private var dangerAccent: Color { Color(hex: "#D70B1B") }
        private var cardBackground: Color { Color.dynamic(light: "#FFFFFF", dark: "#1B1C22") }
        private var detailText: Color { Color.dynamic(light: "#715B54", dark: "#E3C8BE") }
        private var headingText: Color { Color.dynamic(light: "#25262D", dark: "#E7E3E8") }
        
        private var statusColor: Color {
            switch selectedStatus {
            case .open:         return Color.secondary
            case .inProgress:   return Color(hex: "#2EA7FF")
            case .waitingParts: return AppTheme.warning
            case .completed:    return AppTheme.success
            }
        }
        
        var body: some View {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    progressCard
                    scheduleCard
                    descriptionCard
                    labourCard
                    partsCard
                    chatCard
                    updateButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 96)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("#WO-\(String(workOrder.id.uuidString.prefix(4)))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(uiColor: .systemGroupedBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(detailText)
                }
            }
            .sheet(isPresented: $isShowingLabourSheet) {
                LabourEntrySheet(hours: $labourHours, minutes: $labourMinutes)
                    .presentationDetents([.height(300), .medium])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isShowingPartsSheet) {
                SparePartSelectionSheet(
                    parts: inventoryParts,
                    selectedParts: selectedParts,
                    isLoading: isLoadingParts,
                    loadError: partsLoadError,
                    onAdd: mergeSelectedParts
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
            }
            .task {
                await loadInventoryParts()
            }
        }
        
        private var heroCard: some View {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    Text("\(workOrder.priority.rawValue.uppercased()) PRIORITY")
                        .font(.system(.caption2, design: .rounded).monospaced().weight(.bold))
                        .foregroundStyle(workOrder.isOverdue ? .white : AppTheme.warning)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(workOrder.isOverdue ? Color.red : AppTheme.warning.opacity(0.12), in: Capsule())
                    
                    Spacer()
                    
                    // AC3: Show OVERDUE badge in the detail hero card too.
                    if workOrder.isOverdue {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.clock.fill")
                                .font(.system(.caption2, design: .rounded).bold())
                            Text("OVERDUE")
                                .font(.system(.caption2, design: .rounded).monospaced().weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                            .background(Color.red, in: Capsule())
                    } else {
                        Text(selectedStatus.displayTitle.uppercased())
                            .font(.system(.caption2, design: .rounded).monospaced().weight(.bold))
                            .foregroundStyle(statusColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(statusColor.opacity(0.12), in: Capsule())
                    }
                }
                
                Text(workOrder.title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    Label(vehicle?.displayName ?? "Vehicle", systemImage: "truck.box")
                    Label("Assigned: \(workOrder.scheduledDate.formatted(date: .omitted, time: .shortened))", systemImage: "clock")
                }
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.regularMaterial)
            )
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .overlay(alignment: .topTrailing) {
                Image(systemName: workOrder.isOverdue
                      ? "exclamationmark.clock.fill"
                      : selectedStatus.detailIcon)
                    .font(.system(size: 52))
                    .foregroundStyle(statusColor.opacity(0.18))
                    .padding(.trailing, 12)
                    .padding(.top, 10)
            }
        }
        
        private var progressCard: some View {
            DetailSectionCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Update Progress")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(progressValue)%")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(accent)
                    }
                    
                    ProgressView(value: Double(progressValue), total: 100)
                        .tint(accent)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .clipShape(Capsule())
                    
                    HStack(spacing: 8) {
                        ForEach(Self.progressStatuses, id: \.self) { status in
                            Button {
                                selectedStatus = status
                            } label: {
                                Text(status.displayTitle)
                                    .font(.system(.caption, design: .rounded).weight(.bold))
                                    .foregroundStyle(selectedStatus == status ? Color.white : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 34)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(selectedStatus == status ? AnyShapeStyle(accent) : AnyShapeStyle(.ultraThinMaterial))
                                    )
                                    .glassEffect(selectedStatus == status ? .identity : .regular.interactive(), in: .rect(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Label("Scheduled: \(workOrder.scheduledDate.formatted(date: .abbreviated, time: .shortened))", systemImage: "calendar.badge.clock")
                        .font(.system(.caption2, design: .rounded))
                        .foregroundStyle(accent)
                }
            }
        }
        
        private var scheduleCard: some View {
            DetailSectionCard {
                VStack(spacing: 14) {
                    DetailKeyValueRow(title: "Location", value: "Bay \(bayNumber)")
                    DetailDivider()
                    DetailKeyValueRow(title: "Scheduled", value: workOrder.scheduledDate.formatted(date: .omitted, time: .shortened))
                    DetailDivider()
                    DetailKeyValueRow(title: "Est. Duration", value: estimatedDuration)
                }
            }
        }
        
        private var descriptionCard: some View {
            DetailSectionCard {
                VStack(alignment: .leading, spacing: 10) {
                    Text("DESCRIPTION")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(.secondary)
                    Text("\"\(workOrder.details)\"")
                        .font(.system(.subheadline, design: .rounded).italic())
                        .foregroundStyle(.primary)
                        .lineSpacing(4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        
        private var labourCard: some View {
            DetailSectionCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Labour Hours")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Button {
                            isShowingLabourSheet = true
                        } label: {
                            Label("Add Hours", systemImage: "plus")
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(accent)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    HStack(spacing: 12) {
                        DetailTimeInput(title: "HOURS", value: $labourHours)
                        DetailTimeInput(title: "MINUTES", value: $labourMinutes)
                    }
                    
                    HStack {
                        Rectangle()
                            .fill(accent)
                            .frame(width: 3)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(currentMechanicName)
                                .font(.system(.subheadline, design: .rounded).weight(.bold))
                                .foregroundStyle(.primary)
                            Text("ID: \(String(appViewModel.currentUser?.id.uuidString.prefix(8) ?? "N/A").uppercased())")
                                .font(.system(.caption2, design: .monospaced).weight(.bold))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(labourTotalText) hrs")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(Color(hex: "#FF5A1F"))
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.regularMaterial)
                    )
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                }
            }
        }
        
        private var partsCard: some View {
            DetailSectionCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Spare Parts")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(.primary)
                        Spacer()
                        
                        Button {
                            isShowingPartsSheet = true
                        } label: {
                            Label(selectedParts.isEmpty ? "Add Part" : "Change Part", systemImage: "plus.square")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundStyle(accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .overlay(Capsule().stroke(accent, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    if selectedParts.isEmpty {
                        Text("No spare parts added to this work order yet.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        VStack(spacing: 10) {
                            ForEach(selectedParts) { part in
                                sparePartRow(part)
                            }
                        }
                    }
                }
            }
        }

        private func sparePartRow(_ part: WorkOrderPartSelection) -> some View {
            let invPart = inventoryParts.first(where: { $0.id == part.id })
            let maxStock = invPart?.quantity ?? part.quantity

            return HStack(spacing: 12) {
                Image(systemName: part.icon)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(.ultraThinMaterial))
                    .glassEffect(.regular, in: .circle)

                VStack(alignment: .leading, spacing: 4) {
                    Text(part.name)
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(.primary)
                    Text("\(part.partNumber) • \(part.category) • Stock \(maxStock)")
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        adjustPartQuantity(part.id, by: -1)
                    } label: {
                        Image(systemName: "minus")
                            .font(.caption.weight(.bold))
                            .frame(width: 28, height: 28)
                    }

                    Text("\(part.quantity)")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .frame(minWidth: 20)

                    Button {
                        adjustPartQuantity(part.id, by: 1)
                    } label: {
                        Image(systemName: "plus")
                            .font(.caption.weight(.bold))
                            .frame(width: 28, height: 28)
                    }
                    .disabled(part.quantity >= maxStock)
                }
                .foregroundStyle(accent)
                .background(accent.opacity(0.12), in: Capsule())
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.regularMaterial)
            )
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
        }
        
        private var recentChatMessages: [ChatMessage] {
            appViewModel.service.chatMessages(forWorkOrder: workOrder.id)
                .suffix(2)
        }
        
        private var chatCard: some View {
            DetailSectionCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Work Order Chat", systemImage: "message")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(.primary)
                        Spacer()
                        if !recentChatMessages.isEmpty {
                            Circle()
                                .fill(accent)
                                .frame(width: 6, height: 6)
                        }
                    }
                    
                    if recentChatMessages.isEmpty {
                        Text("No chat coordination messages yet. Tap below to start a thread with the fleet manager.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    } else {
                        ForEach(recentChatMessages) { msg in
                            let senderName = appViewModel.service.users().first(where: { $0.id == msg.senderID })?.name ?? "Staff"
                            DetailChatBubble(
                                sender: senderName.uppercased(),
                                message: msg.message,
                                highlighted: msg.senderID == appViewModel.currentUser?.id
                            )
                        }
                    }
                    
                    NavigationLink(destination: WorkOrderChatView(workOrderID: workOrder.id).environment(appViewModel)) {
                        Text("Open Coordination Chat")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(.regularMaterial)
                            )
                            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        
        private var updateButton: some View {
            Button {
                saveTechnicianUpdate()
            } label: {
                Label("Update Progress", systemImage: "checkmark.circle.fill")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        
        private var bayNumber: String {
            let value = abs(workOrder.id.hashValue % 5) + 1
            return "\(value)"
        }
        
        private var estimatedDuration: String {
            switch workOrder.priority {
            case .low:      "1h 00m"
            case .medium:   "2h 00m"
            case .high:     "2h 30m"
            case .critical: "3h 00m"
            }
        }
        
        private var currentMechanicName: String {
            appViewModel.currentUser?.name ?? "Maintenance Staff"
        }
        
        private var labourTotalText: String {
            let hours   = Double(labourHours)   ?? 0
            let minutes = Double(labourMinutes) ?? 0
            return String(format: "%.1f", hours + (minutes / 60))
        }
        
        private var progressValue: Int {
            switch selectedStatus {
            case .open, .waitingParts: 0
            case .inProgress: 50
            case .completed: 100
            }
        }
        
        private static let progressStatuses: [WorkOrderStatus] = [.open, .inProgress, .completed]

        private func adjustPartQuantity(_ id: UUID, by delta: Int) {
            guard let index = selectedParts.firstIndex(where: { $0.id == id }) else { return }
            let currentQuantity = selectedParts[index].quantity
            
            if delta > 0 {
                let maxStock = inventoryParts.first(where: { $0.id == id })?.quantity ?? currentQuantity
                if currentQuantity >= maxStock {
                    return
                }
            }
            
            let updatedQuantity = currentQuantity + delta
            if updatedQuantity <= 0 {
                selectedParts.remove(at: index)
            } else {
                selectedParts[index].quantity = updatedQuantity
            }
        }

        private func mergeSelectedParts(_ parts: [WorkOrderPartSelection]) {
            for part in parts {
                if let index = selectedParts.firstIndex(where: { $0.id == part.id }) {
                    selectedParts[index].quantity += part.quantity
                } else {
                    selectedParts.append(part)
                }
            }
            selectedParts.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        private func saveTechnicianUpdate() {
            var updatedOrder = workOrder
            updatedOrder.status = selectedStatus
            updatedOrder.completedDate = selectedStatus == .completed ? (updatedOrder.completedDate ?? .now) : nil
            updatedOrder.repairSummary = repairSummaryText

            appViewModel.service.updateWorkOrder(updatedOrder)

            // Persist parts usage to Supabase
            if !selectedParts.isEmpty {
                let partsUsage = selectedParts.map { part in
                    WorkOrderPartUsage(
                        workOrderID: workOrder.id,
                        sparePartID: part.id,
                        partName: part.name,
                        partNumber: part.partNumber,
                        quantityUsed: part.quantity
                    )
                }
                appViewModel.service.saveWorkOrderParts(
                    partsUsage,
                    workOrderID: workOrder.id,
                    decrementStock: selectedStatus == .completed
                )
            }

            workOrder = updatedOrder
            NotificationCenter.default.post(name: .maintenanceOrdersRequested, object: nil)
            dismiss()
        }

        private var repairSummaryText: String {
            var lines = workOrder.repairSummary
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map(String.init)
                .filter {
                    !$0.hasPrefix("Technician update:") &&
                    !$0.hasPrefix("Labour logged:") &&
                    !$0.hasPrefix("Parts used:")
                }
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

            lines.append("Technician update: \(selectedStatus.displayTitle)")
            lines.append("Labour logged: \(labourHours)h \(labourMinutes)m")
            if selectedParts.isEmpty {
                lines.append("Parts used: None")
            } else {
                lines.append("Parts used: \(selectedParts.map { "\($0.name) x\($0.quantity)" }.joined(separator: ", "))")
            }
            return lines.joined(separator: "\n")
        }

        private func loadInventoryParts() async {
            guard inventoryParts.isEmpty, !isLoadingParts else { return }
            guard SupabaseConfig.isConfigured else {
                partsLoadError = "Inventory is not connected."
                return
            }
            guard let orgID = appViewModel.currentOrganization?.id else {
                partsLoadError = "No organization selected."
                return
            }

            isLoadingParts = true
            partsLoadError = nil
            do {
                inventoryParts = try await SupabaseService.shared.fetchSpareParts(organizationID: orgID)

                // Load any previously saved parts for this work order
                let savedParts = try await SupabaseService.shared.fetchWorkOrderParts(workOrderID: workOrder.id)
                if !savedParts.isEmpty && selectedParts.isEmpty {
                    selectedParts = savedParts.map { usage in
                        WorkOrderPartSelection(
                            part: inventoryParts.first(where: { $0.id == usage.sparePartID }) ?? SparePart(
                                id: usage.sparePartID,
                                organizationID: orgID,
                                name: usage.partName,
                                partNumber: usage.partNumber,
                                category: "",
                                quantity: 0,
                                minimumRequired: 0,
                                icon: "wrench.fill"
                            ),
                            quantity: usage.quantityUsed
                        )
                    }
                }
            } catch is CancellationError {
                // Ignore task cancellation
                return
            } catch {
                partsLoadError = "Could not load spare parts."
            }
            isLoadingParts = false
        }
    }
    
    // MARK: - Shared Detail Components
    
    private struct DetailSectionCard<Content: View>: View {
        let content: Content
        
        init(@ViewBuilder content: () -> Content) {
            self.content = content()
        }
        
        var body: some View {
            content
                .padding(18)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(.regularMaterial)
                )
                .glassEffect(.regular, in: .rect(cornerRadius: 16))
        }
    }
    
    private struct DetailKeyValueRow: View {
        let title: String
        let value: String
        
        var body: some View {
            HStack {
                Text(title)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(.primary)
            }
        }
    }
    
    private struct DetailDivider: View {
        var body: some View {
            Divider()
                .overlay(Color.dynamic(light: "#E6D8D2", dark: "#3B3841"))
        }
    }
    
    private struct DetailTimeInput: View {
        let title: String
        @Binding var value: String
        
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                TextField("", text: $value)
                    .keyboardType(.numberPad)
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .frame(height: 48)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
                    .glassEffect(.regular, in: .rect(cornerRadius: 12))
                
                Text(title)
                    .font(.system(.caption2, design: .rounded))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private struct WorkOrderPartSelection: Identifiable, Hashable {
        let id: UUID
        var name: String
        var partNumber: String
        var category: String
        var icon: String
        var quantity: Int

        init(part: SparePart, quantity: Int = 1) {
            id = part.id
            name = part.name
            partNumber = part.partNumber
            category = part.category
            icon = part.icon
            self.quantity = quantity
        }
    }

    private struct LabourEntrySheet: View {
        @Environment(\.dismiss) private var dismiss
        @Binding var hours: String
        @Binding var minutes: String
        @State private var draftHours = 0
        @State private var draftMinutes = 0

        var body: some View {
            NavigationStack {
                Form {
                    Section("Labour Time") {
                        Stepper(value: $draftHours, in: 0...72) {
                            HStack {
                                Text("Hours")
                                Spacer()
                                Text("\(draftHours)")
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Stepper(value: $draftMinutes, in: 0...55, step: 5) {
                            HStack {
                                Text("Minutes")
                                Spacer()
                                Text("\(draftMinutes)")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .navigationTitle("Add Labour")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Apply") {
                            hours = "\(draftHours)"
                            minutes = "\(draftMinutes)"
                            dismiss()
                        }
                    }
                }
                .onAppear {
                    draftHours = Int(hours) ?? 0
                    draftMinutes = Int(minutes) ?? 0
                }
            }
        }
    }

    private struct SparePartSelectionSheet: View {
        @Environment(\.dismiss) private var dismiss

        let parts: [SparePart]
        let selectedParts: [WorkOrderPartSelection]
        let isLoading: Bool
        let loadError: String?
        let onAdd: ([WorkOrderPartSelection]) -> Void

        @State private var searchText = ""
        @State private var selectedCategory = "All"
        @State private var showInStockOnly = true
        @State private var draftQuantities: [UUID: Int] = [:]

        private var accent: Color { Color(hex: "#FF5A1F") }

        private var categories: [String] {
            ["All"] + Array(Set(parts.map(\.category))).sorted()
        }

        private var visibleParts: [SparePart] {
            let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            return parts.filter { part in
                let matchesSearch = query.isEmpty ||
                    part.name.localizedCaseInsensitiveContains(query) ||
                    part.partNumber.localizedCaseInsensitiveContains(query) ||
                    part.category.localizedCaseInsensitiveContains(query)
                let matchesCategory = selectedCategory == "All" || part.category == selectedCategory
                let matchesStock = !showInStockOnly || part.quantity > 0
                return matchesSearch && matchesCategory && matchesStock
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        private var selectedDraftParts: [WorkOrderPartSelection] {
            draftQuantities.compactMap { id, quantity in
                guard quantity > 0, let part = parts.first(where: { $0.id == id }) else { return nil }
                return WorkOrderPartSelection(part: part, quantity: quantity)
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }

        var body: some View {
            NavigationStack {
                Group {
                    if isLoading {
                        ProgressView("Loading spare parts...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let loadError {
                        EmptyStateView(icon: "shippingbox", title: "Parts unavailable", message: loadError)
                    } else if parts.isEmpty {
                        EmptyStateView(icon: "shippingbox", title: "No inventory found", message: "Add spare parts in Inventory first.")
                    } else {
                        List {
                            Section {
                                filterControls
                            }
                            .listRowBackground(Color.clear)

                            Section("Parts") {
                                ForEach(visibleParts) { part in
                                    partPickerRow(part)
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
                .navigationTitle("Change Parts")
                .navigationBarTitleDisplayMode(.inline)
                .searchable(text: $searchText, prompt: "Search parts")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Add") {
                            onAdd(selectedDraftParts)
                            dismiss()
                        }
                        .disabled(selectedDraftParts.isEmpty)
                    }
                }
                .onAppear {
                    guard draftQuantities.isEmpty else { return }
                    draftQuantities = Dictionary(uniqueKeysWithValues: selectedParts.map { ($0.id, $0.quantity) })
                }
            }
        }

        private var filterControls: some View {
            VStack(alignment: .leading, spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(categories, id: \.self) { category in
                            Button {
                                selectedCategory = category
                            } label: {
                                Text(category)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(selectedCategory == category ? .white : .primary)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(selectedCategory == category ? accent : Color(uiColor: .secondarySystemGroupedBackground), in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Toggle("In stock only", isOn: $showInStockOnly)
                    .tint(accent)
            }
            .padding(.vertical, 4)
        }

        private func partPickerRow(_ part: SparePart) -> some View {
            let quantity = draftQuantities[part.id, default: 0]

            return HStack(spacing: 12) {
                Image(systemName: part.icon)
                    .foregroundStyle(accent)
                    .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 3) {
                    Text(part.name)
                        .font(.subheadline.weight(.semibold))
                    Text("\(part.partNumber) • \(part.category) • Stock \(part.quantity)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                HStack(spacing: 8) {
                    Button {
                        draftQuantities[part.id] = max(0, quantity - 1)
                    } label: {
                        Image(systemName: "minus")
                            .frame(width: 28, height: 28)
                    }
                    .disabled(quantity == 0)

                    Text("\(quantity)")
                        .font(.subheadline.weight(.bold))
                        .frame(minWidth: 20)

                    Button {
                        draftQuantities[part.id] = min(part.quantity, quantity + 1)
                    } label: {
                        Image(systemName: "plus")
                            .frame(width: 28, height: 28)
                    }
                    .disabled(quantity >= part.quantity)
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(accent)
            }
        }
    }
    
    private struct DetailChatBubble: View {
        let sender: String
        let message: String
        let highlighted: Bool
        
        var body: some View {
            VStack(alignment: .leading, spacing: 6) {
                Text(sender)
                    .font(.system(.caption2, design: .rounded).weight(.bold))
                    .foregroundStyle(Color(hex: "#FF5A1F"))
                Text(message)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.regularMaterial)
            )
            .glassEffect(.regular, in: .rect(cornerRadius: 12))
            .overlay(alignment: .leading) {
                if highlighted {
                    Rectangle()
                        .fill(Color(hex: "#FF5A1F"))
                        .frame(width: 3)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
    
    // MARK: - Update Sheet
    
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
}

private extension WorkOrderStatus {
    var displayTitle: String {
        switch self {
        case .open: "To Be Started"
        case .inProgress: "In Progress"
        case .waitingParts: "To Be Started"
        case .completed: "Done"
        }
    }

    var detailIcon: String {
        switch self {
        case .open: "clock.badge"
        case .inProgress: "wrench.and.screwdriver.fill"
        case .waitingParts: "shippingbox.fill"
        case .completed: "checkmark.circle.fill"
        }
    }
}

#Preview {
    NavigationStack {
        MaintenanceWorkOrdersView()
            .environment(AppViewModel())
    }
}
