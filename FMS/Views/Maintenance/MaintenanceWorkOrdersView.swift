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
            HStack(spacing: 10) {
                ForEach(MaintenanceOrderProgressFilter.allCases) { filter in
                    let isSelected = selectedFilter == filter
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background {
                                Capsule()
                                    .fill(isSelected ? AppTheme.brand : Color(uiColor: .secondarySystemGroupedBackground))
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.vertical, 8)
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
                                .hideTabBarOnPush()
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
    
    private var ordersAccent: Color { Color(hex: "#FF9500") }
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
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .foregroundStyle(AppTheme.brand)
                            Text(order.scheduledDate.formatted(date: .omitted, time: .shortened))
                        }
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Image(systemName: statusIcon)
                                .foregroundStyle(AppTheme.brand)
                            Text(order.status.rawValue.uppercased())
                                .foregroundStyle(statusColor)
                        }
                        .font(.system(.caption, design: .rounded).weight(.bold))
                    }
                    .foregroundStyle(Color.secondary)
                }
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
            case .high:     return Color(hex: "#FF9500")
            case .critical: return Color.red
            }
        }
        
        private var priorityBackgroundColor: Color {
            switch order.priority {
            case .low:      return AppTheme.success.opacity(0.12)
            case .medium:   return Color.orange.opacity(0.12)
            case .high:     return Color(hex: "#FF9500").opacity(0.12)
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
        private var accent: Color { Color(hex: "#FF9500") }
        
        private var statusColor: Color {
            switch selectedStatus {
            case .open:         return Color.secondary
            case .inProgress:   return Color(hex: "#2EA7FF")
            case .waitingParts: return AppTheme.warning
            case .completed:    return AppTheme.success
            }
        }
        
        var body: some View {
            Form {
                // MARK: Hero Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("\(workOrder.priority.rawValue.uppercased()) PRIORITY")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(workOrder.isOverdue ? .white : AppTheme.warning)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(workOrder.isOverdue ? Color.red : AppTheme.warning.opacity(0.12), in: Capsule())
                            
                            Spacer()
                            
                            if workOrder.isOverdue {
                                Label("OVERDUE", systemImage: "exclamationmark.clock.fill")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red, in: Capsule())
                            } else {
                                Label(selectedStatus.displayTitle.uppercased(), systemImage: selectedStatus.detailIcon)
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(statusColor)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(statusColor.opacity(0.12), in: Capsule())
                            }
                        }
                        
                        Text(workOrder.title)
                            .font(.title3.bold())
                            .foregroundStyle(.primary)
                        
                        HStack(spacing: 12) {
                            Label(vehicle?.displayName ?? "Vehicle", systemImage: "car.fill")
                            Label(workOrder.scheduledDate.formatted(date: .omitted, time: .shortened), systemImage: "clock")
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                    }
                    .listRowInsets(EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16))
                }
                
                // MARK: Progress Section
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Progress")
                                .font(.headline)
                            Spacer()
                            Text("\(progressValue)%")
                                .font(.headline)
                                .foregroundStyle(accent)
                        }
                        
                        ProgressView(value: Double(progressValue), total: 100)
                            .tint(accent)
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    
                    // Status picker — native iOS Picker
                    Picker("Status", selection: $selectedStatus.animation(.spring(duration: 0.3))) {
                        ForEach(Self.progressStatuses, id: \.self) { status in
                            Text(status.displayTitle).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 12, trailing: 16))
                } footer: {
                    Label("Scheduled: \(workOrder.scheduledDate.formatted(date: .abbreviated, time: .shortened))", systemImage: "calendar.badge.clock")
                        .font(.caption2)
                }
                
                // MARK: Schedule Info Section
                Section("Details") {
                    LabeledContent("Location", value: "Bay \(bayNumber)")
                    LabeledContent("Scheduled", value: workOrder.scheduledDate.formatted(date: .omitted, time: .shortened))
                    LabeledContent("Est. Duration", value: estimatedDuration)
                }
                
                // MARK: Description Section
                Section("Description") {
                    Text(workOrder.details)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineSpacing(4)
                }
                
                // MARK: Labour Section
                Section {
                    Stepper(value: Binding(
                        get: { Int(labourHours) ?? 0 },
                        set: { labourHours = "\($0)" }
                    ), in: 0...72) {
                        LabeledContent("Hours", value: labourHours)
                    }
                    
                    Stepper(value: Binding(
                        get: { Int(labourMinutes) ?? 0 },
                        set: { labourMinutes = "\($0)" }
                    ), in: 0...55, step: 5) {
                        LabeledContent("Minutes", value: labourMinutes)
                    }
                    
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(accent)
                            .frame(width: 4, height: 36)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(currentMechanicName)
                                .font(.subheadline.weight(.semibold))
                            Text("ID: \(String(appViewModel.currentUser?.id.uuidString.prefix(8) ?? "N/A").uppercased())")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        Text("\(labourTotalText) hrs")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(accent)
                    }
                } header: {
                    Text("Labour")
                }
                
                // MARK: Spare Parts Section
                Section {
                    if selectedParts.isEmpty {
                        Text("No spare parts added yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(selectedParts) { part in
                            nativeSparePartRow(part)
                        }
                        .onDelete { indexSet in
                            selectedParts.remove(atOffsets: indexSet)
                        }
                    }
                    
                    Button {
                        isShowingPartsSheet = true
                    } label: {
                        Label(selectedParts.isEmpty ? "Add Part" : "Change Parts", systemImage: "plus.circle.fill")
                    }
                } header: {
                    Text("Spare Parts")
                }
                
                // MARK: Chat Section
                Section {
                    let lastMsg = appViewModel.service.chatMessages(forWorkOrder: workOrder.id).last
                    let manager = appViewModel.service.users(for: .fleetManager).first
                    let chatTitle = manager?.name ?? "Fleet Manager"
                    let initials = chatTitle.split(separator: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
                    
                    NavigationLink(destination: WorkOrderChatView(workOrderID: workOrder.id).environment(appViewModel).hideTabBarOnPush()) {
                        HStack(spacing: 12) {
                            // Avatar
                            Text(initials)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(accent)
                                .clipShape(Circle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(chatTitle)
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundStyle(Color.primary)
                                    
                                    Spacer()
                                    
                                    if let lastMsg {
                                        Text(lastMsg.timestamp.formatted(date: .omitted, time: .shortened))
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                
                                HStack(spacing: 4) {
                                    if let lastMsg {
                                        let isCurrentUser = lastMsg.senderID == appViewModel.currentUser?.id
                                        if isCurrentUser {
                                            HStack(spacing: -5) {
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 9, weight: .bold))
                                                Image(systemName: "checkmark")
                                                    .font(.system(size: 9, weight: .bold))
                                            }
                                            .foregroundStyle(lastMsg.isRead ? Color.blue : Color.secondary)
                                        }
                                        Text(lastMsg.message)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    } else {
                                        Text("Tap to start coordinating...")
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Work Order Chat")
                }
                
                // MARK: Save Button Section
                Section {
                    Button {
                        saveTechnicianUpdate()
                    } label: {
                        HStack {
                            Spacer()
                            Label("Update Progress", systemImage: "checkmark.circle.fill")
                            Spacer()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(accent)
                    .controlSize(.large)
                    .buttonBorderShape(.capsule)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                }
            }
            .formStyle(.grouped)
            .navigationTitle("#WO-\(String(workOrder.id.uuidString.prefix(4)))")
            .navigationBarTitleDisplayMode(.inline)
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
        
        // MARK: - Native Spare Part Row
        
        private func nativeSparePartRow(_ part: WorkOrderPartSelection) -> some View {
            let invPart = inventoryParts.first(where: { $0.id == part.id })
            let maxStock = invPart?.quantity ?? part.quantity
            
            return HStack(spacing: 12) {
                Image(systemName: part.icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(width: 36, height: 36)
                    .background(accent.opacity(0.1), in: Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(part.name)
                        .font(.subheadline.weight(.semibold))
                    Text("\(part.partNumber) • \(part.category)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Stepper(value: Binding(
                    get: { part.quantity },
                    set: { newVal in
                        if newVal <= 0 {
                            selectedParts.removeAll { $0.id == part.id }
                        } else if let idx = selectedParts.firstIndex(where: { $0.id == part.id }) {
                            selectedParts[idx].quantity = newVal
                        }
                    }
                ), in: 0...maxStock) {
                    Text("\(part.quantity)")
                        .font(.subheadline.weight(.bold))
                        .monospacedDigit()
                }
                .labelsHidden()
                .fixedSize()
            }
        }
        
        private var recentChatMessages: [ChatMessage] {
            appViewModel.service.chatMessages(forWorkOrder: workOrder.id)
                .suffix(2)
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
            GlassCard {
                content
            }
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

        private var accent: Color { Color(hex: "#FF9500") }

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
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(selectedCategory == category ? .white : .primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
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
                    .foregroundStyle(Color(hex: "#FF9500"))
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
                        .fill(Color(hex: "#FF9500"))
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
