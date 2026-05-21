import SwiftUI

struct MaintenanceDashboardView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var viewModel = MaintenanceDashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if viewModel.isLoading {
                    LoadingStateView(title: "Loading workshop queue...")
                        .frame(height: 320)
                } else {
                    header
                    activeOrders
                    schedulePreview
                }
            }
            .padding(20)
        }
        .navigationTitle("Maintenance")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: NotificationsView()) {
                    Image(systemName: "bell")
                        .foregroundStyle(AppTheme.textPrimary)
                }
            }
        }
        .task {
            await viewModel.load()
        }
    }

    private var currentUser: User? { appViewModel.currentUser }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workshop Command")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Track assigned work, close repairs quickly, and keep preventive maintenance on schedule.")
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var activeOrders: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Assigned Work Orders", subtitle: "Your active workshop queue")
            ForEach(appViewModel.service.workOrders(for: currentUser?.id).prefix(3)) { order in
                GlassCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(order.title)
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(order.details)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(order.status.rawValue)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(order.status == .completed ? AppTheme.success : AppTheme.warning)
                    }
                }
            }
        }
    }

    private var schedulePreview: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Maintenance Schedule", subtitle: "Upcoming and overdue service")
            ForEach(appViewModel.service.schedules().prefix(3)) { schedule in
                let vehicle = appViewModel.service.vehicle(for: schedule.vehicleID)
                GlassCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(schedule.serviceType)
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(vehicle?.displayName ?? "Vehicle")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        Text(schedule.dueDate.formatted(date: .abbreviated, time: .omitted))
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(schedule.status == .overdue ? AppTheme.error : AppTheme.brand)
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        MaintenanceDashboardView()
            .environmentObject(AppViewModel())
    }
}
