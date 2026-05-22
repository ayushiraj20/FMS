import SwiftUI

struct DriverDashboardView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var viewModel = DriverDashboardViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if viewModel.isLoading {
                    LoadingStateView(title: "Loading driver workspace...")
                        .frame(height: 320)
                } else {
                    header
                    assignedVehicleCard
                    documentsSection
                    latestTripCard
                    quickActions
                }
            }
            .padding(20)
        }
        .navigationTitle("Driver")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink(destination: NotificationsView()) {
                    Image(systemName: "bell")
                        .foregroundStyle(AppTheme.textPrimary)
                }
                .buttonStyle(.plain)
            }
        }
        .task {
            await viewModel.load()
        }
    }

    private var currentUser: User? { appViewModel.currentUser }
    private var assignedVehicle: Vehicle? { appViewModel.service.vehicle(for: currentUser?.assignedVehicleID) }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Driver Workspace")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
            Text("Review your assigned asset, trip status, and compliance items before heading out.")
                .foregroundStyle(AppTheme.textSecondary)
        }
    }

    private var assignedVehicleCard: some View {
        Group {
            if let vehicle = assignedVehicle {
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle(title: "Assigned Vehicle", subtitle: vehicle.plateNumber)
                        Text(vehicle.displayName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        HStack {
                            infoPill(title: "Fuel", value: "\(vehicle.fuelLevel)%")
                            infoPill(title: "Odometer", value: "\(vehicle.odometer) km")
                            infoPill(title: "Status", value: vehicle.status.rawValue)
                        }
                    }
                }
            } else {
                EmptyStateView(icon: "car.circle", title: "No vehicle assigned", message: "Ask your fleet manager to assign a vehicle before starting trips.")
            }
        }
    }

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Vehicle Documents", subtitle: "Always available in demo mode")
            if let vehicle = assignedVehicle {
                ForEach(appViewModel.service.documents(for: vehicle.id)) { document in
                    GlassCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(document.type.rawValue)
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text(document.documentNumber)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Spacer()
                            Text(document.expiryDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(document.isVerified ? AppTheme.success : AppTheme.warning)
                        }
                    }
                }
            }
        }
    }

    private var latestTripCard: some View {
        let trip = currentUser.flatMap { appViewModel.service.trips(for: $0.id).first }
        return GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title: "Latest Trip", subtitle: trip?.status.rawValue ?? "No active trip")
                if let trip {
                    Text("\(trip.origin) to \(trip.destination)")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("\(trip.distanceKM.formatted(.number.precision(.fractionLength(0)))) km planned distance")
                        .foregroundStyle(AppTheme.textSecondary)
                } else {
                    Text("Trip history will appear here once routes are started.")
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Quick Actions", subtitle: "Daily driver workflows")
            NavigationLink(destination: InspectionsView()) {
                quickLink(title: "Run Inspection", subtitle: "Pre-trip and post-trip checklist capture", icon: "checkmark.shield.fill")
            }
            NavigationLink(destination: DriverTripsView()) {
                quickLink(title: "Manage Trips", subtitle: "Start or end trips and review route history", icon: "map.fill")
            }
        }
    }

    private func infoPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .padding(10)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func quickLink(title: String, subtitle: String, icon: String) -> some View {
        GlassCard {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(AppTheme.brand)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }
}

#Preview {
    NavigationStack {
        DriverDashboardView()
            .environment(AppViewModel())
    }
}
