import SwiftUI

struct AssignedRoutesView: View {
    @Environment(AppViewModel.self) private var appViewModel: AppViewModel

    private var currentUser: User? { appViewModel.currentUser }

    private var allTrips: [Trip] {
        guard let user = currentUser else { return [] }
        return appViewModel.service.trips(for: user.id)
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                Text("Assigned Routes")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(DriverTheme.textPrimary)
                    .padding(.top, 8)

                if allTrips.isEmpty {
                    emptyState
                } else {
                    ForEach(allTrips) { trip in
                        NavigationLink(destination: TripDetailView(trip: trip)) {
                            routeCard(trip)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(DriverTheme.background.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "map.fill")
                .font(.system(size: 48))
                .foregroundStyle(DriverTheme.accent.opacity(0.4))
            Text("No routes assigned")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DriverTheme.textSecondary)
            Text("New route assignments will appear here")
                .font(.system(size: 15))
                .foregroundStyle(DriverTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private func routeCard(_ trip: Trip) -> some View {
        DriverGlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Route")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DriverTheme.accent)

                    Spacer()

                    StatusBadge(
                        title: trip.status.rawValue,
                        color: statusColor(for: trip.status),
                        icon: "circle.fill"
                    )
                }

                // Route line
                HStack(spacing: 8) {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(DriverTheme.successGreen)
                            .frame(width: 8, height: 8)
                        Rectangle()
                            .fill(DriverTheme.accent)
                            .frame(width: 2, height: 20)
                        Circle()
                            .fill(DriverTheme.criticalRed)
                            .frame(width: 8, height: 8)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        Text(trip.origin)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DriverTheme.textPrimary)
                        Text(trip.destination)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DriverTheme.textPrimary)
                    }
                }

                Divider().foregroundStyle(DriverTheme.separator)

                // Info row
                HStack(spacing: 20) {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                        Text(trip.startDate.formatted(date: .abbreviated, time: .shortened))
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(DriverTheme.textSecondary)

                    HStack(spacing: 4) {
                        Image(systemName: "road.lanes")
                            .font(.system(size: 12))
                        Text("\(Int(trip.distanceKM)) km")
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(DriverTheme.textSecondary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DriverTheme.textSecondary)
                }
            }
        }
    }

    private func statusColor(for status: TripStatus) -> Color {
        switch status {
        case .scheduled: return .gray
        case .inProgress: return DriverTheme.accent
        case .completed: return DriverTheme.successGreen
        case .cancelled: return DriverTheme.criticalRed
        }
    }
}

#Preview {
    NavigationStack {
        AssignedRoutesView()
            .environment(AppViewModel())
    }
}
