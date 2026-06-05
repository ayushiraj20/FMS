import SwiftUI

struct NotificationsView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var selectedFilter: NotificationFilter = .all
    @State private var reportShareURL: URL?
    @State private var showReportShareSheet = false

    enum NotificationFilter: String, CaseIterable {
        case all = "All"
        case unread = "Unread"
    }

    var filteredNotifications: [AppNotification] {
        switch selectedFilter {
        case .all:
            return appViewModel.notifications
        case .unread:
            return appViewModel.notifications.filter { !$0.isRead }
        }
    }

    var body: some View {
        ZStack {
            DriverScreenBackground()
            
            VStack(spacing: 0) {
                // iOS-style Segmented Control & Action Header
                VStack(spacing: 12) {
                    HStack {
                        Picker("Filter", selection: $selectedFilter.animation(.spring(response: 0.25, dampingFraction: 0.8))) {
                            ForEach(NotificationFilter.allCases, id: \.self) { filter in
                                Text(filter.rawValue).tag(filter)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 160)
                        
                        Spacer()
                        
                        if appViewModel.unreadNotificationsCount > 0 {
                            Button {
                                Task {
                                    await appViewModel.markAllNotificationsAsRead()
                                }
                            } label: {
                                Text("Mark All Read")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(DriverTheme.accent)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    
                    Divider()
                }
                .background(Color.clear)

                if filteredNotifications.isEmpty {
                    // Clean Native Empty State
                    ScrollView(showsIndicators: false) {
                        ContentUnavailableView {
                            Label(
                                selectedFilter == .all ? "No Notifications" : "No Unread Notifications",
                                systemImage: selectedFilter == .all ? "bell.slash.fill" : "bell.badge.slash.fill"
                            )
                        } description: {
                            Text("You're completely up to date. New duty alerts will appear here.")
                        }
                        .frame(minHeight: 400)
                    }
                    .refreshable {
                        await appViewModel.loadNotifications()
                    }
                } else {
                    // Native List with clean swipe and tap behaviors
                    List {
                        ForEach(filteredNotifications) { notification in
                            ZStack(alignment: .leading) {
                                NavigationLink {
                                    destinationView(for: notification)
                                        .onAppear {
                                            if !notification.isRead {
                                                Task {
                                                    await appViewModel.markNotificationAsRead(id: notification.id)
                                                }
                                            }
                                        }
                                } label: {
                                    EmptyView()
                                }
                                .opacity(0)

                                HStack(alignment: .top, spacing: 12) {
                                    // Unread Dot Indicator
                                    Circle()
                                        .fill(notification.isRead ? Color.clear : DriverTheme.accent)
                                        .frame(width: 8, height: 8)
                                        .padding(.top, 8)
                                    
                                    // Category Icon
                                    Image(systemName: iconName(for: notification.category))
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .frame(width: 24, height: 24)
                                        .background(color(for: notification.category), in: Circle())
                                        .padding(.top, 2)

                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(alignment: .top) {
                                            Text(notification.title)
                                                .font(.system(size: 15, weight: notification.isRead ? .semibold : .bold))
                                                .foregroundStyle(DriverTheme.textPrimary)
                                                .lineLimit(1)
                                            
                                            Spacer()
                                            
                                            Text(notification.date.formatted(.dateTime.hour().minute()))
                                                .font(.system(size: 11, weight: .regular))
                                                .foregroundStyle(DriverTheme.textSecondary.opacity(0.8))
                                        }
                                        
                                        Text(notification.message)
                                            .font(.system(size: 13))
                                            .foregroundStyle(DriverTheme.textSecondary)
                                            .lineLimit(3)
                                            .multilineTextAlignment(.leading)

                                        if let reportID = notification.inventoryReportID {
                                            Button {
                                                if let url = GeneratedReportStore.shared.url(for: reportID) {
                                                    reportShareURL = url
                                                    showReportShareSheet = true
                                                }
                                            } label: {
                                                Label("Download PDF", systemImage: "arrow.down.doc.fill")
                                                    .font(.caption.weight(.semibold))
                                            }
                                            .buttonStyle(.bordered)
                                            .controlSize(.small)
                                            .tint(DriverTheme.accent)
                                            .disabled(GeneratedReportStore.shared.url(for: reportID) == nil)
                                            .padding(.top, 4)
                                        }
                                    }
                                }
                                .padding(.vertical, 2)
                                .contentShape(Rectangle())
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparatorTint(DriverTheme.accent.opacity(0.15))
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        await appViewModel.loadNotifications()
                    }
                }
            }
        }
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.large)
        .task {
            await appViewModel.loadNotifications()
        }
        .sheet(isPresented: $showReportShareSheet, onDismiss: { reportShareURL = nil }) {
            if let reportShareURL {
                ShareSheet(items: [reportShareURL])
                    .registersSheetPresentation()
            }
        }
        .hidesTabBarWhileSheet(isPresented: showReportShareSheet)
    }

    // MARK: - Redirection & Resolution Helpers

    @ViewBuilder
    private func destinationView(for notification: AppNotification) -> some View {
        if let role = appViewModel.currentRole {
            switch role {
            case .maintenance:
                destinationForMaintenance(notification)
            case .fleetManager:
                destinationForFleetManager(notification)
            case .driver:
                destinationForDriver(notification)
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func destinationForMaintenance(_ notification: AppNotification) -> some View {
        let isChat = notification.title.localizedCaseInsensitiveContains("Message") ||
                     notification.title.localizedCaseInsensitiveContains("Chat") ||
                     notification.title.localizedCaseInsensitiveContains("message")
        
        let isStock = notification.title.localizedCaseInsensitiveContains("Stock") ||
                      notification.title.localizedCaseInsensitiveContains("Part Out") ||
                      notification.inventoryReportID != nil
        
        if isChat {
            let chat = findChatDetails(for: notification)
            WorkOrderChatView(workOrderID: chat.workOrderID, defectReportID: chat.defectReportID)
                .environment(appViewModel)
                .hideTabBarOnPush()
        } else if isStock {
            MaintenanceInventoryView(selectedCategory: "Low Stock")
                .environment(appViewModel)
                .hideTabBarOnPush()
        } else if let order = findWorkOrder(for: notification) {
            MaintenanceWorkOrdersView.MaintenanceWorkOrderDetailView(workOrder: order)
                .environment(appViewModel)
                .hideTabBarOnPush()
        } else {
            MaintenanceWorkOrdersView()
                .environment(appViewModel)
                .hideTabBarOnPush()
        }
    }

    @ViewBuilder
    private func destinationForFleetManager(_ notification: AppNotification) -> some View {
        let isChat = notification.title.localizedCaseInsensitiveContains("Message") ||
                     notification.title.localizedCaseInsensitiveContains("Chat") ||
                     notification.title.localizedCaseInsensitiveContains("message")
        
        let isStock = notification.title.localizedCaseInsensitiveContains("Stock") ||
                      notification.title.localizedCaseInsensitiveContains("Part Out") ||
                      notification.inventoryReportID != nil
        
        let isSOS = notification.title.localizedCaseInsensitiveContains("ACTIVE EMERGENCY") ||
                    notification.title.localizedCaseInsensitiveContains("SOS")
        
        let isGeofence = notification.title.localizedCaseInsensitiveContains("Geofence") ||
                         notification.title.localizedCaseInsensitiveContains("Breach") ||
                         notification.message.localizedCaseInsensitiveContains("geofence")
        let isOffRoute = notification.title.localizedCaseInsensitiveContains("Off-Route") ||
                         notification.title.localizedCaseInsensitiveContains("Route Corridor") ||
                         notification.title.localizedCaseInsensitiveContains("Non-Ideal") ||
                         notification.message.localizedCaseInsensitiveContains("route corridor")
        
        let isCompliance = notification.title.localizedCaseInsensitiveContains("Expired") ||
                           notification.title.localizedCaseInsensitiveContains("Compliance") ||
                           notification.title.localizedCaseInsensitiveContains("Missing") ||
                           notification.message.localizedCaseInsensitiveContains("compliance")
        
        let isDefect = notification.title.localizedCaseInsensitiveContains("Defect") ||
                       notification.message.localizedCaseInsensitiveContains("defect")
                       
        let isDriverOnDuty = notification.title.localizedCaseInsensitiveContains("Driver") ||
                             notification.message.localizedCaseInsensitiveContains("on duty")

        if isSOS {
            PriorityAlertsListView(initialSelectedCategory: "SOS Alerts")
                .environment(appViewModel)
                .hideTabBarOnPush()
        } else if isGeofence || isOffRoute {
            if let trip = findTrip(for: notification) {
                TripDetailView(trip: trip)
                    .environment(appViewModel)
                    .hideTabBarOnPush()
            } else if let vehicle = findVehicle(for: notification) {
                VehicleDetailView(viewModel: VehicleManagementViewModel(service: appViewModel.service, currentOrgID: appViewModel.currentOrganization?.id), vehicleID: vehicle.id)
                    .environment(appViewModel)
                    .hideTabBarOnPush()
            } else {
                PriorityAlertsListView(initialSelectedCategory: "Off-Route")
                    .environment(appViewModel)
                    .hideTabBarOnPush()
            }
        } else if isCompliance {
            if let vehicle = findVehicle(for: notification) {
                VehicleDetailView(viewModel: VehicleManagementViewModel(service: appViewModel.service, currentOrgID: appViewModel.currentOrganization?.id), vehicleID: vehicle.id)
                    .environment(appViewModel)
                    .hideTabBarOnPush()
            } else {
                VehicleManagementView(service: appViewModel.service, currentOrgID: appViewModel.currentOrganization?.id)
                    .environment(appViewModel)
                    .hideTabBarOnPush()
            }
        } else if isDefect {
            if let defect = findDefectReport(for: notification) {
                DefectReportsListView(initialSelectedDefectID: defect.id)
                    .environment(appViewModel)
                    .hideTabBarOnPush()
            } else {
                DefectReportsListView()
                    .environment(appViewModel)
                    .hideTabBarOnPush()
            }
        } else if isDriverOnDuty {
            if let driver = findDriver(for: notification) {
                DriverDetailView(driver: driver, service: appViewModel.service)
                    .environment(appViewModel)
                    .hideTabBarOnPush()
            } else {
                TeamView(service: appViewModel.service, currentOrgID: appViewModel.currentOrganization?.id)
                    .environment(appViewModel)
                    .hideTabBarOnPush()
            }
        } else if isChat {
            let chat = findChatDetails(for: notification)
            if chat.workOrderID != nil || chat.defectReportID != nil {
                WorkOrderChatView(workOrderID: chat.workOrderID, defectReportID: chat.defectReportID)
                    .environment(appViewModel)
                    .hideTabBarOnPush()
            } else if let sender = findSenderUser(for: notification) {
                DriverManagerChatView(driverID: sender.id)
                    .environment(appViewModel)
                    .hideTabBarOnPush()
            } else {
                DriverManagerChatView()
                    .environment(appViewModel)
                    .hideTabBarOnPush()
            }
        } else if isStock {
            FleetReportsAnalyticsView()
                .environment(appViewModel)
                .hideTabBarOnPush()
        } else if let order = findWorkOrder(for: notification) {
            WorkOrderChatView(workOrderID: order.id)
                .environment(appViewModel)
                .hideTabBarOnPush()
        } else {
            PriorityAlertsListView()
                .environment(appViewModel)
                .hideTabBarOnPush()
        }
    }

    @ViewBuilder
    private func destinationForDriver(_ notification: AppNotification) -> some View {
        let isChat = notification.title.localizedCaseInsensitiveContains("Message") ||
                     notification.title.localizedCaseInsensitiveContains("Chat") ||
                     notification.title.localizedCaseInsensitiveContains("message")
        
        if isChat {
            let chat = findChatDetails(for: notification)
            if chat.workOrderID != nil || chat.defectReportID != nil {
                WorkOrderChatView(workOrderID: chat.workOrderID, defectReportID: chat.defectReportID)
                    .environment(appViewModel)
                    .hideTabBarOnPush()
            } else {
                DriverManagerChatView()
                    .environment(appViewModel)
                    .hideTabBarOnPush()
            }
        } else if let trip = findTrip(for: notification) {
            TripDetailView(trip: trip)
                .environment(appViewModel)
                .hideTabBarOnPush()
        } else {
            DriverManagerChatView()
                .environment(appViewModel)
                .hideTabBarOnPush()
        }
    }

    private func findWorkOrder(for notification: AppNotification) -> WorkOrder? {
        let workOrders = appViewModel.service.workOrders
        for order in workOrders {
            if notification.message.localizedCaseInsensitiveContains(order.title) ||
               notification.title.localizedCaseInsensitiveContains(order.title) {
                return order
            }
        }
        return nil
    }

    private func findVehicle(for notification: AppNotification) -> Vehicle? {
        let vehicles = appViewModel.service.vehicles
        for vehicle in vehicles {
            if notification.message.localizedCaseInsensitiveContains(vehicle.plateNumber) ||
               notification.title.localizedCaseInsensitiveContains(vehicle.plateNumber) {
                return vehicle
            }
        }
        for vehicle in vehicles {
            if notification.message.localizedCaseInsensitiveContains(vehicle.displayName) ||
               notification.title.localizedCaseInsensitiveContains(vehicle.displayName) {
                return vehicle
            }
        }
        return nil
    }

    private func findDriver(for notification: AppNotification) -> User? {
        let users = appViewModel.service.users.filter { $0.role == .driver }
        for user in users {
            if notification.message.localizedCaseInsensitiveContains(user.name) ||
               notification.title.localizedCaseInsensitiveContains(user.name) {
                return user
            }
        }
        return nil
    }

    private func findDefectReport(for notification: AppNotification) -> DefectReport? {
        let defects = appViewModel.service.defects
        for defect in defects {
            if let driver = appViewModel.service.users.first(where: { $0.id == defect.driverID }),
               let vehicle = appViewModel.service.vehicles.first(where: { $0.id == defect.vehicleID }) {
                if notification.message.localizedCaseInsensitiveContains(driver.name),
                   notification.message.localizedCaseInsensitiveContains(vehicle.plateNumber) {
                    if let title = defect.title, notification.message.localizedCaseInsensitiveContains(title) {
                        return defect
                    }
                    let desc = defect.description
                    if !desc.isEmpty, notification.message.localizedCaseInsensitiveContains(desc) {
                        return defect
                    }
                }
            }
        }
        for defect in defects {
            if let title = defect.title,
               (notification.message.localizedCaseInsensitiveContains(title) ||
                notification.title.localizedCaseInsensitiveContains(title)) {
                return defect
            }
            let desc = defect.description
            if !desc.isEmpty,
               (notification.message.localizedCaseInsensitiveContains(desc) ||
                notification.title.localizedCaseInsensitiveContains(desc)) {
                return defect
            }
        }
        return nil
    }

    private func findChatDetails(for notification: AppNotification) -> (workOrderID: UUID?, defectReportID: UUID?) {
        let messages = appViewModel.service.chatMessages
        for msg in messages {
            if notification.message.localizedCaseInsensitiveContains(msg.message) {
                return (msg.workOrderID, msg.defectReportID)
            }
        }
        
        if let order = findWorkOrder(for: notification) {
            return (order.id, nil)
        }
        if let defect = findDefectReport(for: notification) {
            return (nil, defect.id)
        }
        
        return (nil, nil)
    }

    private func findSenderUser(for notification: AppNotification) -> User? {
        let message = notification.message
        guard let colonIndex = message.range(of: ":") else { return nil }
        let prefix = message[..<colonIndex.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanName: String
        if let parenIndex = prefix.range(of: " (") {
            cleanName = String(prefix[..<parenIndex.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            cleanName = prefix
        }
        return appViewModel.service.users.first { $0.name.localizedCaseInsensitiveContains(cleanName) }
    }

    private func findTrip(for notification: AppNotification) -> Trip? {
        let trips = appViewModel.service.trips
        for trip in trips {
            if notification.message.localizedCaseInsensitiveContains(trip.origin) ||
               notification.message.localizedCaseInsensitiveContains(trip.destination) {
                return trip
            }
        }
        return nil
    }

    private func color(for category: NotificationCategory) -> Color {
        switch category {
        case .info:
            return DriverTheme.accent
        case .warning:
            return DriverTheme.warningAmber
        case .critical:
            return DriverTheme.criticalRed
        case .success:
            return DriverTheme.successGreen
        case .maintenance:
            return DriverTheme.accent
        }
    }

    private func iconName(for category: NotificationCategory) -> String {
        switch category {
        case .info:
            return "info.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .critical:
            return "exclamationmark.octagon.fill"
        case .success:
            return "checkmark.circle.fill"
        case .maintenance:
            return "wrench.and.screwdriver.fill"
        }
    }
}

#Preview {
    NavigationStack {
        NotificationsView()
            .environment(AppViewModel())
    }
}
