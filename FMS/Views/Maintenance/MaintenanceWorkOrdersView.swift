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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingCalendar = true
                } label: {
                    Image(systemName: "calendar")
                        .foregroundStyle(ordersAccent)
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search work orders")
        .sheet(item: $selectedOrder) { order in
            MaintenanceOrderUpdateSheet(workOrder: order)
                .environment(appViewModel)
        }
