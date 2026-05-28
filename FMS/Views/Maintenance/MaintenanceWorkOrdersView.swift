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
        case waitingParts
        case done
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .all:          "All"
            case .open:         "Open"
            case .inProgress:   "In Progress"
            case .waitingParts: "Waiting Parts"
            case .done:         "Done"
            }
        }
        
        var emptyMessage: String {
            switch self {
            case .all:          "No work orders found."
            case .open:         "No open work orders right now."
            case .inProgress:   "No work orders are currently in progress."
            case .waitingParts: "No work orders are waiting on parts."
            case .done:         "Completed work will appear here after you mark it done."
            }
        }
        
        func matches(_ status: WorkOrderStatus) -> Bool {
            switch self {
            case .all:          true
            case .open:         status == .open
            case .inProgress:   status == .inProgress
            case .waitingParts: status == .waitingParts
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
        @State private var progress: Int
        @State private var repairStartedAt: Date?
        @State private var labourHours = "1"
        @State private var labourMinutes = "30"
        @State private var isShowingCompletion = false
        @State private var selectedPartName: String? = nil
        
        let sparePartsOptions = [
            "Heavy Duty Brake Pads",
            "Oil Filter Kit",
            "Tyre Valve Set",
            "Hydraulic Filter Assembly",
            "Engine Gasket Kit V8",
            "Halogen Headlight Bulbs",
            "Fuel Filter Assembly",
            "Windshield Wiper Blades",
            "Side Mirror Assembly",
            "Workshop Parts Kit"
        ]
        
        init(workOrder: WorkOrder) {
            _workOrder = State(initialValue: workOrder)
            _progress = State(initialValue: MaintenanceWorkOrderDetailView.initialProgress(for: workOrder.status))
            
            if workOrder.status == .inProgress {
                _repairStartedAt = State(initialValue: Date.now.addingTimeInterval(-3600)) // 1 hr ago
            } else {
                _repairStartedAt = State(initialValue: nil)
            }
            
            // Derive initial part name dynamically from title
            let initialPart: String
            if workOrder.title.localizedCaseInsensitiveContains("brake") { initialPart = "Heavy Duty Brake Pads" }
            else if workOrder.title.localizedCaseInsensitiveContains("oil")   { initialPart = "Oil Filter Kit" }
            else if workOrder.title.localizedCaseInsensitiveContains("tyre") ||
               workOrder.title.localizedCaseInsensitiveContains("tire")  { initialPart = "Tyre Valve Set" }
            else { initialPart = "Workshop Parts Kit" }
            _selectedPartName = State(initialValue: initialPart)
        }
        
        private var vehicle: Vehicle? { appViewModel.service.vehicle(for: workOrder.vehicleID) }
        private var accent: Color { Color(hex: "#FF5A1F") }
        private var dangerAccent: Color { Color(hex: "#D70B1B") }
        private var cardBackground: Color { Color.dynamic(light: "#FFFFFF", dark: "#1B1C22") }
        private var detailText: Color { Color.dynamic(light: "#715B54", dark: "#E3C8BE") }
        private var headingText: Color { Color.dynamic(light: "#25262D", dark: "#E7E3E8") }
        
        private var statusColor: Color {
            switch workOrder.status {
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
                    timerCard
                    actionRow
                    progressCard
                    scheduleCard
                    descriptionCard
                    labourCard
                    partsCard
                    chatCard
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 28)
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
            .navigationDestination(isPresented: $isShowingCompletion) {
                CompleteWorkOrderView(
                    workOrder: workOrder,
                    vehicle: vehicle,
                    labourHoursText: labourTotalText,
                    partName: selectedPartName ?? "Workshop Parts Kit"
                )
                .environment(appViewModel)
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
                        Text(workOrder.status.rawValue.uppercased())
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
                      : "exclamationmark.triangle.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.tertiary.opacity(0.5))
                    .padding(.trailing, 12)
                    .padding(.top, 10)
            }
        }
        
        private var timerCard: some View {
            DetailSectionCard {
                VStack(spacing: 14) {
                    Text("ACTIVE REPAIR TIMER")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .tracking(2)
                        .foregroundStyle(.secondary)
                    
                    if let repairStartedAt {
                        TimelineView(.periodic(from: .now, by: 1)) { timeline in
                            Text(Self.formattedDuration(from: repairStartedAt, to: timeline.date))
                                .font(.system(size: 34, weight: .bold, design: .monospaced))
                                .foregroundStyle(accent)
                        }
                    } else {
                        Text("00:00:00")
                            .font(.system(size: 34, weight: .bold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    
                    Button {
                        repairStartedAt = repairStartedAt == nil ? .now : nil
                    } label: {
                        Label(repairStartedAt == nil ? "Start Timer" : "Stop Timer",
                              systemImage: repairStartedAt == nil ? "play.circle" : "stop.circle")
                            .font(.system(.headline, design: .rounded))
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.capsule)
                    .tint(repairStartedAt == nil ? dangerAccent : .secondary)
                }
            }
        }
        
        private var actionRow: some View {
            Button {
                updateProgress(to: max(progress, 75))
            } label: {
                Text("Update Progress")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(accent)
        }
        
        private var progressCard: some View {
            DetailSectionCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Task Progress")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("\(progress)%")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .foregroundStyle(accent)
                    }
                    
                    ProgressView(value: Double(progress), total: 100)
                        .tint(accent)
                        .background(Color(uiColor: .tertiarySystemGroupedBackground))
                        .clipShape(Capsule())
                    
                    HStack(spacing: 8) {
                        ForEach([25, 50, 75, 100], id: \.self) { value in
                            Button {
                                updateProgress(to: value)
                            } label: {
                                Text("\(value)%")
                                    .font(.system(.caption, design: .rounded).weight(.bold))
                                    .foregroundStyle(progress == value ? Color.white : .secondary)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 34)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(progress == value ? AnyShapeStyle(accent) : AnyShapeStyle(.ultraThinMaterial))
                                    )
                                    .glassEffect(progress == value ? .identity : .regular.interactive(), in: .rect(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Label("Actual Start Time: \(actualStartText)", systemImage: "alarm")
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
                        
                        Menu {
                            ForEach(sparePartsOptions, id: \.self) { option in
                                Button(option) {
                                    selectedPartName = option
                                }
                            }
                        } label: {
                            Label(selectedPartName == nil ? "Add Part" : "Change Part", systemImage: "plus.square")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundStyle(accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .overlay(Capsule().stroke(accent, lineWidth: 1))
                        }
                    }
                    
                    if let partName = selectedPartName {
                        HStack(spacing: 12) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(.title3, design: .rounded).weight(.bold))
                                .foregroundStyle(.secondary)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(.ultraThinMaterial)
                                )
                                .glassEffect(.regular, in: .circle)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(partName)
                                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                                    .foregroundStyle(.primary)
                                Text(partNumber(for: partName))
                                    .font(.system(.caption, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("Qty: 1 set")
                                .font(.system(.caption, design: .rounded).weight(.bold))
                                .foregroundStyle(Color(hex: "#FF5A1F"))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(accent.opacity(0.14), in: Capsule())
                        }
                        .padding(10)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(.regularMaterial)
                        )
                        .glassEffect(.regular, in: .rect(cornerRadius: 14))
                    } else {
                        Text("No spare parts added to this work order yet.")
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 4)
                    }
                }
            }
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
        
        private var actualStartText: String {
            (repairStartedAt ?? workOrder.scheduledDate).formatted(date: .omitted, time: .shortened)
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
        
        private func partNumber(for name: String) -> String {
            if name.contains("Brake") { return "BP-4402" }
            if name.contains("Oil") { return "PN-1029" }
            if name.contains("Tyre") || name.contains("Tire") { return "PN-5510" }
            if name.contains("Hydraulic") { return "PN-8821" }
            if name.contains("Gasket") { return "PN-9283" }
            if name.contains("Headlight") || name.contains("Bulb") { return "PN-3115" }
            if name.contains("Fuel") { return "PN-1205" }
            if name.contains("Wiper") { return "PN-5510" }
            if name.contains("Mirror") { return "PN-6678" }
            return "BP-402"
        }
        
        private var labourTotalText: String {
            let hours   = Double(labourHours)   ?? 0
            let minutes = Double(labourMinutes) ?? 0
            return String(format: "%.1f", hours + (minutes / 60))
        }
        
        private func updateProgress(to value: Int) {
            progress = value
            if value >= 100 {
                isShowingCompletion = true
                return
            }
            if workOrder.status == .open {
                workOrder.status = .inProgress
            }
            appViewModel.service.updateWorkOrder(workOrder)
        }
        
        private func markComplete() {
            progress = 100
            workOrder.status = .completed
            workOrder.completedDate = .now
            repairStartedAt = nil
            if workOrder.repairSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                workOrder.repairSummary = "Marked complete from work order detail."
            }
            appViewModel.service.updateWorkOrder(workOrder)
        }
        
        private static func initialProgress(for status: WorkOrderStatus) -> Int {
            switch status {
            case .open:         25
            case .inProgress:   75
            case .waitingParts: 50
            case .completed:    100
            }
        }
        
        private static func formattedDuration(from start: Date, to end: Date) -> String {
            let seconds = max(0, Int(end.timeIntervalSince(start)))
            let hours   = seconds / 3600
            let minutes = (seconds % 3600) / 60
            let remaining = seconds % 60
            return String(format: "%02d:%02d:%02d", hours, minutes, remaining)
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

#Preview {
    NavigationStack {
        MaintenanceWorkOrdersView()
            .environment(AppViewModel())
    }
}
