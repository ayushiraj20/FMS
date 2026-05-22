import SwiftUI

struct AssignedRoutesView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var lastRefreshed = Date.now

    private var currentUser: User? { appViewModel.currentUser }
    private var routes: [Route] {
        guard let currentUser else { return [] }
        return appViewModel.service.routes(for: currentUser.id)
    }

    var body: some View {
        List {
            if routes.isEmpty {
                EmptyStateView(icon: "map.circle", title: "No assigned routes", message: "Routes assigned by your fleet manager will appear here.")
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            } else {
                // Active routes
                let activeRoutes = routes.filter { $0.status == .active }
                if !activeRoutes.isEmpty {
                    Section {
                        ForEach(activeRoutes) { route in
                            NavigationLink(destination: RouteDetailView(route: route)) {
                                RouteCardView(route: route, service: appViewModel.service)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    } header: {
                        Text("Active Route")
                    }
                }

                // Upcoming assigned routes
                let assignedRoutes = routes.filter { $0.status == .assigned }
                if !assignedRoutes.isEmpty {
                    Section {
                        ForEach(assignedRoutes) { route in
                            NavigationLink(destination: RouteDetailView(route: route)) {
                                RouteCardView(route: route, service: appViewModel.service)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    } header: {
                        Text("Upcoming Routes")
                    }
                }

                // Completed routes
                let completedRoutes = routes.filter { $0.status == .completed }
                if !completedRoutes.isEmpty {
                    Section {
                        ForEach(completedRoutes) { route in
                            NavigationLink(destination: RouteDetailView(route: route)) {
                                RouteCardView(route: route, service: appViewModel.service)
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                        }
                    } header: {
                        Text("Completed")
                    }
                }
            }
        }
        .appListStyle()
        .navigationTitle("Assigned Routes")
        .refreshable {
            lastRefreshed = .now
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                VStack(spacing: 2) {
                    Text("Updated")
                    Text(lastRefreshed.formatted(date: .omitted, time: .shortened))
                }
                .font(.caption2)
                .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}

// MARK: - Route Card (List Item)

private struct RouteCardView: View {
    let route: Route
    let service: MockDataService

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(route.name)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Spacer()
                    RouteStatusBadge(status: route.status)
                }

                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.swap")
                        .font(.caption)
                        .foregroundStyle(AppTheme.brand)
                    Text("\(route.origin) → \(route.destination)")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .lineLimit(1)
                }

                HStack(spacing: 16) {
                    routeInfoPill(icon: "clock", value: formattedDuration(route.estimatedDurationMinutes))
                    routeInfoPill(icon: "road.lanes", value: "\(route.distanceKM.formatted(.number.precision(.fractionLength(0)))) km")
                    routeInfoPill(icon: "mappin.and.ellipse", value: "\(route.stops.count) stops")
                }

                if let vehicle = service.vehicle(for: route.vehicleID) {
                    Text(vehicle.displayName)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.brand)
                }
            }
        }
    }

    private func routeInfoPill(icon: String, value: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(value)
                .font(.caption)
        }
        .foregroundStyle(AppTheme.textSecondary)
    }
}

// MARK: - Route Status Badge

struct RouteStatusBadge: View {
    let status: RouteStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.14))
            .foregroundStyle(statusColor)
            .clipShape(Capsule())
    }

    private var statusColor: Color {
        switch status {
        case .active: AppTheme.brand
        case .assigned: AppTheme.warning
        case .completed: AppTheme.success
        }
    }
}

// MARK: - Route Detail View

struct RouteDetailView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    let route: Route

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Route header
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(route.name)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Spacer()
                            RouteStatusBadge(status: route.status)
                        }

                        if let vehicle = appViewModel.service.vehicle(for: route.vehicleID) {
                            HStack(spacing: 8) {
                                Image(systemName: "car.side.fill")
                                    .foregroundStyle(AppTheme.brand)
                                Text(vehicle.displayName)
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text("•")
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(vehicle.plateNumber)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .font(.subheadline)
                        }

                        HStack(spacing: 20) {
                            detailStat(icon: "clock.fill", label: "Est. Time", value: formattedDuration(route.estimatedDurationMinutes))
                            detailStat(icon: "road.lanes", label: "Distance", value: "\(route.distanceKM.formatted(.number.precision(.fractionLength(0)))) km")
                            detailStat(icon: "mappin.and.ellipse", label: "Stops", value: "\(route.stops.count)")
                        }
                    }
                }

                // Scheduled time
                GlassCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Scheduled Start")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                            Text(route.scheduledStart.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Assigned")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                            Text(route.assignedDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                    }
                }

                // Route timeline
                SectionTitle(title: "Route Stops", subtitle: "Destination, stops, and estimated times")

                // Origin
                stopTimelineRow(
                    name: route.origin,
                    subtitle: "Origin",
                    time: route.scheduledStart.formatted(date: .omitted, time: .shortened),
                    isCompleted: route.status == .active || route.status == .completed,
                    isFirst: true,
                    isLast: false
                )

                // Intermediate stops
                ForEach(route.stops.sorted(by: { $0.order < $1.order })) { stop in
                    stopTimelineRow(
                        name: stop.name,
                        subtitle: stop.address,
                        time: stop.estimatedArrival.formatted(date: .omitted, time: .shortened),
                        isCompleted: stop.isCompleted,
                        isFirst: false,
                        isLast: false
                    )
                }

                // Destination
                stopTimelineRow(
                    name: route.destination,
                    subtitle: "Destination",
                    time: estimatedArrivalTime(),
                    isCompleted: route.status == .completed,
                    isFirst: false,
                    isLast: true
                )

                // Notes
                if !route.notes.isEmpty {
                    SectionTitle(title: "Notes", subtitle: "Route instructions and updates")
                    GlassCard {
                        Text(route.notes)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }

                // Navigation button
                if route.status != .completed {
                    SectionTitle(title: "Navigation", subtitle: "Open route in Apple Maps")
                    Button {
                        openNavigationInMaps()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "location.fill")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Navigate to Next Stop")
                                    .font(.headline)
                                Text(nextStopName())
                                    .font(.subheadline)
                                    .opacity(0.8)
                            }
                            Spacer()
                            Image(systemName: "arrow.up.right.square")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
            }
            .padding(20)
        }
        .navigationTitle("Route Detail")
    }

    private func detailStat(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(AppTheme.brand)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func stopTimelineRow(name: String, subtitle: String, time: String, isCompleted: Bool, isFirst: Bool, isLast: Bool) -> some View {
        HStack(alignment: .top, spacing: 16) {
            // Timeline indicator
            VStack(spacing: 0) {
                if !isFirst {
                    Rectangle()
                        .fill(isCompleted ? AppTheme.brand : AppTheme.border)
                        .frame(width: 2, height: 16)
                } else {
                    Spacer()
                        .frame(width: 2, height: 16)
                }

                ZStack {
                    Circle()
                        .fill(isCompleted ? AppTheme.brand : AppTheme.surface)
                        .frame(width: 24, height: 24)
                    Circle()
                        .stroke(isCompleted ? AppTheme.brand : AppTheme.border, lineWidth: 2)
                        .frame(width: 24, height: 24)
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                    } else if isFirst || isLast {
                        Circle()
                            .fill(isFirst ? AppTheme.brand : AppTheme.warning)
                            .frame(width: 8, height: 8)
                    }
                }

                if !isLast {
                    Rectangle()
                        .fill(AppTheme.border)
                        .frame(width: 2, height: 16)
                } else {
                    Spacer()
                        .frame(width: 2, height: 16)
                }
            }
            .frame(width: 24)

            // Stop details
            GlassCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(name)
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(subtitle)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(time)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(isCompleted ? AppTheme.success : AppTheme.textPrimary)
                        if isCompleted {
                            Text("Completed")
                                .font(.caption2)
                                .foregroundStyle(AppTheme.success)
                        }
                    }
                }
            }
        }
    }

    private func estimatedArrivalTime() -> String {
        let arrivalDate = route.scheduledStart.addingTimeInterval(Double(route.estimatedDurationMinutes) * 60)
        return arrivalDate.formatted(date: .omitted, time: .shortened)
    }

    private func nextStopName() -> String {
        if let nextStop = route.stops.sorted(by: { $0.order < $1.order }).first(where: { !$0.isCompleted }) {
            return nextStop.name
        }
        return route.destination
    }

    private func openNavigationInMaps() {
        let destination: String
        if let nextStop = route.stops.sorted(by: { $0.order < $1.order }).first(where: { !$0.isCompleted }) {
            destination = nextStop.address
        } else {
            destination = route.destination
        }
        let encoded = destination.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let url = URL(string: "maps://?daddr=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Duration Formatter

func formattedDuration(_ minutes: Int) -> String {
    let hours = minutes / 60
    let mins = minutes % 60
    if hours > 0 && mins > 0 {
        return "\(hours)h \(mins)m"
    } else if hours > 0 {
        return "\(hours)h"
    }
    return "\(mins)m"
}

#Preview {
    NavigationStack {
        AssignedRoutesView()
            .environmentObject(AppViewModel())
    }
}
