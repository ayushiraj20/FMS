import SwiftUI

struct MaintenanceScheduleView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    var body: some View {
        List {
            ForEach(appViewModel.service.schedules()) { schedule in
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
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(schedule.status.rawValue)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(schedule.status == .overdue ? AppTheme.error : AppTheme.brand)
                            Text(schedule.dueDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.footnote)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .appListStyle()
        .navigationTitle("Schedules")
    }
}

#Preview {
    NavigationStack {
        MaintenanceScheduleView()
            .environmentObject(AppViewModel())
    }
}
