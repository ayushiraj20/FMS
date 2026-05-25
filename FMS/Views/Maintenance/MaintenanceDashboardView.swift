//Created by Mayurakshi Das

import SwiftUI

struct MaintenanceDashboardView: View {
    @Environment(AppViewModel.self) private var appViewModel
    // Previous state owner kept for rollback:
    // @StateObject private var viewModel = MaintenanceDashboardViewModel()
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if isLoading {
                    LoadingStateView(title: "Loading workshop queue...")
                        .frame(height: 320)
                } else {
                    topBar
                    dashboardHeader
                    metricsGrid
                    priorityQueue
                    maintenanceScheduleStrip
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await appViewModel.loadNotifications()
            guard isLoading else { return }
            try? await Task.sleep(for: .seconds(0.35))
            isLoading = false
        }
    }

    private var topBar: some View {
        HStack {
            NavigationLink(destination: ProfileSettingsView()) {
                ZStack {
                    Circle()
                        .fill(maintenanceAccent)
                        .frame(width: 44, height: 44)
                    Text(userInitials)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .accessibilityIdentifier("PROFILE_BUTTON")

            Spacer()

            NavigationLink(destination: NotificationsView()) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(AppTheme.surfaceSecondary)
                        .frame(width: 44, height: 44)

                    Image(systemName: "bell.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(maintenanceAccent)
                        .frame(width: 44, height: 44)

                    if appViewModel.unreadNotificationsCount > 0 {
                        Circle()
                            .fill(AppTheme.error)
                            .frame(width: 18, height: 18)
                            .overlay(
                                Text("\(appViewModel.unreadNotificationsCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .offset(x: 2, y: -2)
                    }
                }
            }
            .accessibilityIdentifier("BELL_BUTTON")
        }
    }

    private var currentUser: User? { appViewModel.currentUser }
    private var userFirstName: String { currentUser?.name.components(separatedBy: " ").first ?? "User" }
    private var assignedOrders: [WorkOrder] { appViewModel.service.workOrders(for: currentUser?.id) }
    private var activeAssignedOrders: [WorkOrder] { assignedOrders.filter { $0.status != .completed } }
    private var priorityOrders: [WorkOrder] {
        activeAssignedOrders.sorted {
            if priorityRank($0.priority) == priorityRank($1.priority) {
                return $0.scheduledDate < $1.scheduledDate
            }
            return priorityRank($0.priority) > priorityRank($1.priority)
        }
    }
    private var assignedVehicleIDs: Set<UUID> { Set(assignedOrders.map(\.vehicleID)) }
    private var waitingOnPartsCount: Int { assignedOrders.filter { $0.status == .waitingParts }.count }
    private var upcomingSchedules: [MaintenanceSchedule] {
        let schedules = appViewModel.service.schedules(for: assignedVehicleIDs.isEmpty ? nil : assignedVehicleIDs)
        return schedules.filter { $0.status != .completed }
    }
