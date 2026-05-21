import SwiftUI

struct DriverTripsView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var isPresentingStartTrip = false

    private var currentUser: User? { appViewModel.currentUser }
    private var trips: [Trip] {
        guard let currentUser else { return [] }
        return appViewModel.service.trips(for: currentUser.id)
    }

    var body: some View {
        List {
            Section {
                if let activeTrip = trips.first(where: { $0.status == .inProgress }) {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Active Trip")
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("\(activeTrip.origin) to \(activeTrip.destination)")
                                .foregroundStyle(AppTheme.textSecondary)
                            Button("End Trip") {
                                appViewModel.service.endTrip(activeTrip)
                            }
                            .buttonStyle(PrimaryButtonStyle())
                        }
                    }
                } else {
                    Button("Start New Trip") {
                        isPresentingStartTrip = true
                    }
                    .foregroundStyle(AppTheme.brand)
                }
            }

            Section("Trip History") {
                if trips.isEmpty {
                    EmptyStateView(icon: "map", title: "No trips yet", message: "Route history will appear once you begin operating trips.")
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(trips) { trip in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("\(trip.origin) to \(trip.destination)")
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                    Text(trip.status.rawValue)
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(trip.status == .completed ? AppTheme.success : AppTheme.brand)
                                }
                                Text("\(trip.distanceKM.formatted(.number.precision(.fractionLength(0)))) km")
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .appListStyle()
        .navigationTitle("Trips")
        .sheet(isPresented: $isPresentingStartTrip) {
            StartTripSheet()
                .environmentObject(appViewModel)
        }
    }
}

private struct StartTripSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var origin = "Distribution Hub A"
    @State private var destination = "Retail Node 12"

    var body: some View {
        NavigationStack {
            Form {
                TextField("Origin", text: $origin)
                TextField("Destination", text: $destination)
            }
            .navigationTitle("Start Trip")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        guard let user = appViewModel.currentUser,
                              let vehicleID = user.assignedVehicleID else { return }
                        appViewModel.service.startTrip(driverID: user.id, vehicleID: vehicleID, origin: origin, destination: destination)
                        dismiss()
                    }
                    .disabled(origin.isEmpty || destination.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        DriverTripsView()
            .environmentObject(AppViewModel())
    }
}
