import SwiftUI

struct AssignedRoutesView: View {
    @Environment(AppViewModel.self) private var appViewModel: AppViewModel

    private var currentUser: User? { appViewModel.currentUser }

    private var assignedTrips: [Trip] {
        guard let user = currentUser else { return [] }
        return appViewModel.service.trips(for: user.id)
            .filter { $0.status == .scheduled || $0.status == .inProgress }
            .sorted { $0.startDate < $1.startDate }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {

                if assignedTrips.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(assignedTrips) { trip in
                            NavigationLink(destination: TripDetailView(trip: trip)) {
                                routeCard(trip)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .refreshable {
            await appViewModel.service.syncWithDatabase()
        }
        .task(id: assignedTrips.map(\.id)) {
            for trip in assignedTrips where trip.hasRoutableEndpoints {
                _ = await appViewModel.service.tripRoutePlan(for: trip)
            }
        }
        .background(
            ZStack {
                DriverTheme.background.ignoresSafeArea()
                GeometryReader { geo in
                    Circle()
                        .fill(DriverTheme.accent.opacity(0.1))
                        .frame(width: geo.size.width)
                        .blur(radius: 60)
                        .offset(x: -geo.size.width * 0.3, y: geo.size.height * 0.2)
                }
                .ignoresSafeArea()
            }
        )
        .navigationTitle("Assigned Routes")
        .navigationBarTitleDisplayMode(.large)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "map.fill")
                .font(.system(size: 60))
                .foregroundStyle(DriverTheme.accent.opacity(0.4))
                .symbolEffect(.pulse)
            Text("No routes assigned")
                .font(.system(.title3, design: .rounded).bold())
            Text("New route assignments will appear here")
                .font(.subheadline)
                .foregroundStyle(DriverTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32))
    }

    private func routeCard(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Route", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                    .font(.subheadline.bold())
                    .foregroundStyle(DriverTheme.accent)
                Spacer()
                Text(trip.status.rawValue.uppercased())
                    .font(.caption2.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(statusColor(for: trip.status).opacity(0.15), in: Capsule())
                    .foregroundStyle(statusColor(for: trip.status))
            }

            HStack(spacing: 12) {
                VStack(spacing: 0) {
                    Circle().fill(DriverTheme.successGreen).frame(width: 10, height: 10)
                    Rectangle().fill(DriverTheme.textSecondary.opacity(0.3)).frame(width: 2, height: 24)
                    Circle().fill(DriverTheme.criticalRed).frame(width: 10, height: 10)
                }
                VStack(alignment: .leading, spacing: 14) {
                    Text(trip.origin).font(.system(.headline, design: .rounded).bold())
                    Text(trip.destination).font(.system(.headline, design: .rounded).bold())
                }
                Spacer()
            }

            Divider().background(DriverTheme.textSecondary.opacity(0.3))

            HStack(spacing: 16) {
                Label(trip.startDate.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    .font(.caption.bold())
                    .foregroundStyle(DriverTheme.textSecondary)
                Label("\(Int(trip.distanceKM)) km", systemImage: "road.lanes")
                    .font(.caption.bold())
                    .foregroundStyle(DriverTheme.textSecondary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(DriverTheme.textSecondary)
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .scrollTransition { content, phase in
            content.scaleEffect(phase.isIdentity ? 1 : 0.95).opacity(phase.isIdentity ? 1 : 0.8)
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
