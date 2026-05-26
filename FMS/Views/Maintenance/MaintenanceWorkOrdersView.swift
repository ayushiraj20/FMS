import SwiftUI

struct MaintenanceWorkOrdersView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var searchText = ""
    @State private var selectedOrder: WorkOrder?
    @State private var selectedFilter: MaintenanceOrderProgressFilter = .all
    @State private var isShowingCalendar = false
    @State private var showOnlyCritical: Bool
    
    init(initialFilter: MaintenanceOrderProgressFilter = .all, showOnlyCritical: Bool = false) {
        _selectedFilter = State(initialValue: initialFilter)
        _showOnlyCritical = State(initialValue: showOnlyCritical)
    }
    

    
    private var currentUser: User? { appViewModel.currentUser }
    private var orders: [WorkOrder] {
        appViewModel.service
            .workOrders(for: currentUser?.id)
            .filter {
                (!showOnlyCritical || $0.priority == .critical) &&
                selectedFilter.matches($0.status) &&
                (searchText.isEmpty ||
                 $0.title.localizedCaseInsensitiveContains(searchText) ||
                 $0.details.localizedCaseInsensitiveContains(searchText) ||
                 (appViewModel.service.vehicle(for: $0.vehicleID)?.displayName.localizedCaseInsensitiveContains(searchText) ?? false) ||
                 (appViewModel.service.vehicle(for: $0.vehicleID)?.plateNumber.localizedCaseInsensitiveContains(searchText) ?? false))
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
            filterBar
            
            if showOnlyCritical {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text("Showing Critical Work Orders Only")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.red)
                    Spacer()
                    Button {
                        showOnlyCritical = false
                    } label: {
                        Text("Show All Priorities")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(ordersAccent)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(ordersAccent.opacity(0.12), in: Capsule())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.06))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundStyle(AppTheme.border),
                    alignment: .bottom
                )
            }
            
            ordersList
        }
        .navigationTitle("Work Orders")
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
    }
    
    // MARK: - Subviews
    
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(MaintenanceOrderProgressFilter.allCases) { filter in
                    Button {
                        selectedFilter = filter
                    } label: {
                        Text(filter.title)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(selectedFilter == filter ? Color.white : warmSecondaryText)
                            .lineLimit(1)
                            .minimumScaleFactor(0.82)
                            .padding(.horizontal, 20)
                            .frame(height: 44)
                            .background(
                                Capsule()
                                    .fill(selectedFilter == filter ? ordersAccent : Color.dynamic(light: "#FFFFFF", dark: "#202127"))
                            )
                            .overlay(
                                Capsule()
                                    .stroke(selectedFilter == filter ? ordersAccent.opacity(0.2) : Color.dynamic(light: "#E6D8D2", dark: "#3B3841"), lineWidth: 1)
                            )
                            .shadow(color: selectedFilter == filter ? ordersAccent.opacity(0.28) : .clear, radius: 12, x: 0, y: 6)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
    }
    
    private var legacyOrdersList: some View {
        List {
            ForEach(orders) { order in
                Button {
                    selectedOrder = order
                } label: {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(order.title)
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(order.details)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                            HStack {
                                Text(order.status.rawValue)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(order.status == .completed ? AppTheme.success : AppTheme.warning)
                                Spacer()
                                Text(appViewModel.service.vehicle(for: order.vehicleID)?.plateNumber ?? "")
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .appListStyle()
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
        case pending
        case inProgress
        case waitingParts
        case done
        
        var id: String { rawValue }
        
        var title: String {
            switch self {
            case .all:          "All"
            case .pending:      "Pending"
            case .inProgress:   "In Progress"
            case .waitingParts: "Waiting on Parts"
            case .done:         "Done"
            }
        }
        
        var emptyMessage: String {
            switch self {
            case .all:          "Assigned work from admin will appear here."
            case .pending:      "No pending work orders right now."
            case .inProgress:   "No work orders are currently in progress."
            case .waitingParts: "No work orders are currently blocked by missing parts."
            case .done:         "Completed work will appear here after you mark it done."
            }
        }
        
        func matches(_ status: WorkOrderStatus) -> Bool {
            switch self {
            case .all:          true
            case .pending:      status == .open
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
                VStack(alignment: .leading, spacing: 10) {
                    
                    // MARK: Top row: WO ID + priority/overdue badges
                    HStack(alignment: .center, spacing: 8) {
                        Text("#WO-\(String(order.id.uuidString.prefix(4)))")
                            .font(.caption.monospaced().weight(.bold))
                            .foregroundStyle(Color.secondary)
                        
                        Spacer()
                        
                        if order.isOverdue {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.clock.fill")
                                    .font(.system(size: 9, weight: .bold))
                                Text("OVERDUE")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.red, in: Capsule())
                        } else if order.priority == .critical {
                            Text("URGENT")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.red, in: Capsule())
                        }
                        
                        Text(order.priority.rawValue.uppercased())
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(priorityTextColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(priorityBackgroundColor, in: Capsule())
                    }
                    
                    // MARK: Vehicle + title + details
                    VStack(alignment: .leading, spacing: 4) {
                        Text(order.title)
                            .font(.headline)
                            .foregroundStyle(Color(.label))
                            .lineLimit(2)
                        
                        Text(vehicle?.displayName ?? "Assigned Vehicle")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Color.secondary)
                        
                        if !order.details.isEmpty {
                            Text(order.details)
                                .font(.footnote)
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
                            .font(.caption.weight(.semibold))
                        
                        Spacer()
                        
                        Label(order.status.rawValue.uppercased(), systemImage: statusIcon)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(statusColor)
                    }
                    .foregroundStyle(Color.secondary)
                }
                
                // MARK: iOS Navigation Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color(.tertiaryLabel))
                    .padding(.leading, 4)
            }
            .padding(.vertical, 8)
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
        
        init(workOrder: WorkOrder) {
            _workOrder = State(initialValue: workOrder)
            _progress = State(initialValue: MaintenanceWorkOrderDetailView.initialProgress(for: workOrder.status))
            _repairStartedAt = State(initialValue: workOrder.status == .completed ? nil : Date.now.addingTimeInterval(-5081))
        }
        
        private var vehicle: Vehicle? { appViewModel.service.vehicle(for: workOrder.vehicleID) }
        private var accent: Color { Color(hex: "#FF5A1F") }
        private var dangerAccent: Color { Color(hex: "#D70B1B") }
        private var cardBackground: Color { Color.dynamic(light: "#FFFFFF", dark: "#1B1C22") }
        private var detailText: Color { Color.dynamic(light: "#715B54", dark: "#E3C8BE") }
        private var headingText: Color { Color.dynamic(light: "#25262D", dark: "#E7E3E8") }
        
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
            .navigationTitle("#WO-\(String(workOrder.id.uuidString.prefix(4)))")
            .navigationBarTitleDisplayMode(.inline)
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
                    partName: partName
                )
                .environment(appViewModel)
            }
        }
        
        private var heroCard: some View {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    Text("\(workOrder.priority.rawValue.uppercased()) PRIORITY")
                        .font(.caption2.monospaced().weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.16), in: Capsule())
                    
                    Spacer()
                    
                    // AC3: Show OVERDUE badge in the detail hero card too.
                    if workOrder.isOverdue {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.clock.fill")
                                .font(.caption2.bold())
                            Text("OVERDUE")
                                .font(.caption2.monospaced().weight(.bold))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red, in: Capsule())
                    } else {
                        Text(workOrder.status.rawValue.uppercased())
                            .font(.caption2.monospaced().weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.16), in: Capsule())
                    }
                }
                
                Text(workOrder.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                
                HStack(spacing: 12) {
                    Label(vehicle?.displayName ?? "Vehicle", systemImage: "truck.box")
                    Label("Assigned: \(workOrder.scheduledDate.formatted(date: .omitted, time: .shortened))", systemImage: "clock")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.9))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            // AC3: Pure red gradient when overdue, standard danger otherwise.
                            colors: workOrder.isOverdue
                                ? [Color.red, Color(hex: "#FF5A1F")]
                                : [dangerAccent, accent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: workOrder.isOverdue
                              ? "exclamationmark.clock.fill"
                              : "exclamationmark.triangle.fill")
                            .font(.system(size: 52))
                            .foregroundStyle(.white.opacity(0.16))
                            .padding(.trailing, 12)
                            .padding(.top, 10)
                    }
            )
        }
        
        private var timerCard: some View {
            DetailSectionCard {
                VStack(spacing: 14) {
                    Text("ACTIVE REPAIR TIMER")
                        .font(.caption2.monospaced().weight(.bold))
                        .tracking(2)
                        .foregroundStyle(detailText)
                    
                    if let repairStartedAt {
                        TimelineView(.periodic(from: .now, by: 1)) { timeline in
                            Text(Self.formattedDuration(from: repairStartedAt, to: timeline.date))
                                .font(.system(size: 34, weight: .bold, design: .monospaced))
                                .foregroundStyle(accent)
                        }
                    } else {
                        Text("00:00:00")
                            .font(.system(size: 34, weight: .bold, design: .monospaced))
                            .foregroundStyle(detailText)
                    }
                    
                    Button {
                        repairStartedAt = repairStartedAt == nil ? .now : nil
                    } label: {
                        Label(repairStartedAt == nil ? "Start Timer" : "Stop Timer",
                              systemImage: repairStartedAt == nil ? "play.circle" : "stop.circle")
                            .font(.headline)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(dangerAccent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        
        private var actionRow: some View {
            HStack(spacing: 12) {
                Button {
                    updateProgress(to: max(progress, 75))
                } label: {
                    Text("Update Progress")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(headingText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.dynamic(light: "#EEF0F4", dark: "#2B2D35"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                
                Button {
                    isShowingCompletion = true
                } label: {
                    Text("Mark Complete")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: accent.opacity(0.24), radius: 12, x: 0, y: 6)
                }
                .buttonStyle(.plain)
            }
        }
        
        private var progressCard: some View {
            DetailSectionCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Task Progress")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(headingText)
                        Spacer()
                        Text("\(progress)%")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(accent)
                    }
                    
                    ProgressView(value: Double(progress), total: 100)
                        .tint(accent)
                        .background(Color.dynamic(light: "#D9DDE4", dark: "#30323A"))
                        .clipShape(Capsule())
                    
                    HStack(spacing: 8) {
                        ForEach([25, 50, 75, 100], id: \.self) { value in
                            Button {
                                updateProgress(to: value)
                            } label: {
                                Text("\(value)%")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(progress == value ? Color.white : detailText)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 34)
                                    .background(
                                        progress == value ? accent.opacity(0.45) : Color.dynamic(light: "#EFF1F5", dark: "#292B32"),
                                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    Label("Actual Start Time: \(actualStartText)", systemImage: "alarm")
                        .font(.caption.weight(.semibold))
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
                        .font(.caption2.monospaced().weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(detailText)
                    Text("\"\(workOrder.details)\"")
                        .font(.subheadline.italic())
                        .foregroundStyle(headingText)
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
                            .font(.headline.weight(.bold))
                            .foregroundStyle(headingText)
                        Spacer()
                        Button {
                        } label: {
                            Label("Add Hours", systemImage: "plus")
                                .font(.subheadline.weight(.bold))
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
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(headingText)
                            Text("Mechanic ID: #552")
                                .font(.caption)
                                .foregroundStyle(detailText)
                        }
                        Spacer()
                        Text("\(labourTotalText) hrs")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color.dynamic(light: "#7A2618", dark: "#FFD1C6"))
                    }
                    .padding(12)
                    .background(Color.dynamic(light: "#F3F4F7", dark: "#22242B"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
            }
        }
        
        private var partsCard: some View {
            DetailSectionCard {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Spare Parts")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(headingText)
                        Spacer()
                        Button {
                        } label: {
                            Label("Add Part", systemImage: "plus.square")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .overlay(Capsule().stroke(accent, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                    }
                    
                    HStack(spacing: 12) {
                        Image(systemName: "slider.horizontal.3")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(detailText)
                            .frame(width: 44, height: 44)
                            .background(Color.dynamic(light: "#EEF0F4", dark: "#30323A"), in: Circle())
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(partName)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(headingText)
                            Text("BP-402")
                                .font(.caption)
                                .foregroundStyle(detailText)
                        }
                        
                        Spacer()
                        
                        Text("Qty: 1 set")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Color.dynamic(light: "#7A2618", dark: "#FFD1C6"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(accent.opacity(0.14), in: Capsule())
                    }
                    .padding(10)
                    .background(Color.dynamic(light: "#F3F4F7", dark: "#11131A"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
            }
        }
        
        private var chatCard: some View {
            DetailSectionCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Work Order Chat", systemImage: "message")
                            .font(.headline.weight(.bold))
                            .foregroundStyle(headingText)
                        Spacer()
                        Circle()
                            .fill(accent)
                            .frame(width: 6, height: 6)
                    }
                    
                    DetailChatBubble(sender: "DISPATCH", message: "Parts are at the counter.", highlighted: false)
                    DetailChatBubble(sender: currentMechanicName.uppercased(), message: "Picking them up now.", highlighted: true)
                    
                    NavigationLink(destination: WorkOrderChatView(workOrderID: workOrder.id).environment(appViewModel)) {
                        Text("Open Coordination Chat")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(headingText)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(Color.dynamic(light: "#EEF0F4", dark: "#33353D"), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        
        private var partName: String {
            if workOrder.title.localizedCaseInsensitiveContains("brake") { return "Front Brake Pads" }
            if workOrder.title.localizedCaseInsensitiveContains("oil")   { return "Oil Filter Kit" }
            if workOrder.title.localizedCaseInsensitiveContains("tyre") ||
               workOrder.title.localizedCaseInsensitiveContains("tire")  { return "Tyre Valve Set" }
            return "Workshop Parts Kit"
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
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.dynamic(light: "#FFFFFF", dark: "#1B1C22").opacity(0.96))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.dynamic(light: "#E6D8D2", dark: "#353741"), lineWidth: 1)
                        )
                )
        }
    }
    
    private struct DetailKeyValueRow: View {
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
                    .font(.headline)
                    .foregroundStyle(Color.dynamic(light: "#25262D", dark: "#E7E3E8"))
                    .padding(.horizontal, 12)
                    .frame(height: 48)
                    .background(Color.dynamic(light: "#FFFFFF", dark: "#11131A"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.dynamic(light: "#BFC6D4", dark: "#667085"), lineWidth: 1)
                    )
                
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(Color.dynamic(light: "#715B54", dark: "#D7B8AC"))
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
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Color.dynamic(light: "#7A2618", dark: "#FFD1C6"))
                Text(message)
                    .font(.caption)
                    .foregroundStyle(Color.dynamic(light: "#25262D", dark: "#E7E3E8"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.dynamic(light: "#F3F4F7", dark: "#11131A"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .leading) {
                if highlighted {
                    Rectangle()
                        .fill(Color(hex: "#FF5A1F"))
                        .frame(width: 3)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
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
