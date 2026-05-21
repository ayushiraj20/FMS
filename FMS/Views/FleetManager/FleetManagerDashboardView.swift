import SwiftUI

struct FleetManagerDashboardView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = FleetManagerDashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if viewModel.isLoading {
                    LoadingStateView(title: "Loading live fleet KPIs...")
                        .frame(height: 280)
                } else {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                        ForEach(viewModel.stats(service: appViewModel.service)) { stat in
                            StatCardView(stat: stat)
                        }
                    }

                    SectionTitle(title: "Priority Alerts", subtitle: "Items requiring operational attention")

                    ForEach(priorityAlerts, id: \.id) { notification in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(notification.title)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text(notification.message)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }

                    SectionTitle(title: "Quick Access", subtitle: "Navigate to key management modules")

                    NavigationLink(destination: UserManagementView(service: appViewModel.service, currentOrgID: appViewModel.currentOrganization?.id)) {
                        quickLink(title: "User Management", subtitle: "Create and manage driver or maintenance accounts", icon: "person.2.fill")
                    }

                    NavigationLink(destination: VehicleManagementView(service: appViewModel.service, currentOrgID: appViewModel.currentOrganization?.id)) {
                        quickLink(title: "Vehicle Management", subtitle: "Track assets, assignments, and document health", icon: "car.side.fill")
                    }

                    NavigationLink(destination: WorkOrderManagementView(service: appViewModel.service, currentOrgID: appViewModel.currentOrganization?.id)) {
                        quickLink(title: "Maintenance Work Orders", subtitle: "Create, assign, and monitor workshop tasks", icon: "wrench.and.screwdriver.fill")
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Fleet Manager")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: NotificationsView()) {
                    notificationBadge
                }
            }
        }
        .task {
            await viewModel.load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Operations Overview")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
            Text("NorthStar Logistics is running with strong availability and a small set of actionable maintenance blockers.")
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var priorityAlerts: [AppNotification] {
        appViewModel.service.notifications(for: appViewModel.currentUser).prefix(3).map { $0 }
    }

    private func quickLink(title: String, subtitle: String, icon: String) -> some View {
        GlassCard {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(AppTheme.brand)
                    .frame(width: 46, height: 46)
                    .background(AppTheme.brand.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .foregroundStyle(AppTheme.textPrimary)
                        .font(.headline)
                    Text(subtitle)
                        .foregroundStyle(AppTheme.textSecondary)
                        .font(.subheadline)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    private var notificationBadge: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "bell")
                .foregroundStyle(AppTheme.textPrimary)
            if appViewModel.unreadNotificationsCount > 0 {
                Circle()
                    .fill(AppTheme.brand)
                    .frame(width: 8, height: 8)
                    .offset(x: 2, y: -2)
            }
        }
    }
}

#Preview {
    NavigationStack {
        FleetManagerDashboardView()
            .environmentObject(AppViewModel())
    }
}
