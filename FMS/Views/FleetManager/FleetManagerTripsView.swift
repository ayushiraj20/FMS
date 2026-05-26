import SwiftUI

struct FleetManagerTripsView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var searchText = ""
    @State private var isPresentingAssignDriverTripModal = false
    
    var filteredTrips: [Trip] {
        if searchText.isEmpty {
            return appViewModel.service.trips
        } else {
            return appViewModel.service.trips.filter { trip in
                trip.destination.localizedCaseInsensitiveContains(searchText) ||
                trip.origin.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // MARK: - Trips List
                List {
                    if filteredTrips.isEmpty {
                        EmptyStateView(
                            icon: "map.slash",
                            title: "No trips found",
                            message: "Try adjusting your search or assign a new trip."
                        )
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(filteredTrips) { trip in
                            tripCard(trip)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 8, leading: 20, bottom: 8, trailing: 20))
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            
            // MARK: - Floating Add Button
            Button {
                isPresentingAssignDriverTripModal = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(AppTheme.brand)
                    .clipShape(Circle())
                    .shadow(color: AppTheme.brand.opacity(0.4), radius: 10, y: 4)
            }
            .padding(.trailing, 24)
            .padding(.bottom, 24)
        }
        .background(AppTheme.background)
        .navigationTitle("Trips")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Search trips by location...")
        .sheet(isPresented: $isPresentingAssignDriverTripModal) {
            AssignDriverTripView(service: appViewModel.service)
        }
    }
    
    // MARK: - Trip Card
    private func tripCard(_ trip: Trip) -> some View {
        let driver = appViewModel.service.user(for: trip.driverID)
        let vehicle = appViewModel.service.vehicle(for: trip.vehicleID)
        
        return GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    StatusBadgeView(
                        text: trip.status.rawValue,
                        color: statusColor(trip.status)
                    )
                    Spacer()
                    Text(formattedDate(trip.startDate))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(trip.origin)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Origin")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "arrow.right")
                        .foregroundStyle(AppTheme.textSecondary)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(trip.destination)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Destination")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                
                Divider()
                
                HStack {
                    if let driver = driver {
                        Label(driver.name, systemImage: "person.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    Spacer()
                    if let vehicle = vehicle {
                        Label(vehicle.plateNumber, systemImage: "car.fill")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
            }
        }
    }
    
    private func statusColor(_ status: TripStatus) -> Color {
        switch status {
        case .inProgress: return AppTheme.brand
        case .completed: return AppTheme.success
        case .scheduled: return AppTheme.warning
        case .cancelled: return AppTheme.error
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
