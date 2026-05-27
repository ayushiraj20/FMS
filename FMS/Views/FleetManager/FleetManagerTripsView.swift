import SwiftUI

struct FleetManagerTripsView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var searchText = ""
    @State private var isPresentingAssignDriverTripModal = false
    
    enum TripFilter: String, CaseIterable {
        case ongoing = "Ongoing"
        case scheduled = "Scheduled"
        case completed = "Completed"
    }
    
    @State private var selectedFilter: TripFilter = .ongoing
    @State private var selectedTrip: Trip? = nil
    
    var filteredTrips: [Trip] {
        let trips = appViewModel.service.trips.filter { trip in
            switch selectedFilter {
            case .ongoing: return trip.status == .inProgress
            case .scheduled: return trip.status == .scheduled
            case .completed: return trip.status == .completed
            }
        }
        
        if searchText.isEmpty {
            return trips
        } else {
            return trips.filter { trip in
                trip.destination.localizedCaseInsensitiveContains(searchText) ||
                trip.origin.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private func countForFilter(_ filter: TripFilter) -> Int {
        return appViewModel.service.trips.filter { trip in
            switch filter {
            case .ongoing: return trip.status == .inProgress
            case .scheduled: return trip.status == .scheduled
            case .completed: return trip.status == .completed
            }
        }.count
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(appViewModel.service.trips.count) total trips")
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textSecondary)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(TripFilter.allCases, id: \.self) { filter in
                            Button {
                                selectedFilter = filter
                            } label: {
                                Text("\(filter.rawValue) (\(countForFilter(filter)))")
                                    .font(.subheadline)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(selectedFilter == filter ? Color.white.opacity(0.2) : Color.white.opacity(0.05))
                                    .foregroundStyle(selectedFilter == filter ? .white : AppTheme.textSecondary)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 10)
                
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
                            Button {
                                selectedTrip = trip
                            } label: {
                                tripCard(trip)
                            }
                            .buttonStyle(.plain)
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
        .fullScreenCover(item: $selectedTrip) { trip in
            FleetTripDetailSheet(trip: trip)
        }
    }
    
    // MARK: - Trip Card
    private func tripCard(_ trip: Trip) -> some View {
        let driver = appViewModel.service.user(for: trip.driverID)
        let vehicle = appViewModel.service.vehicle(for: trip.vehicleID)
        
        return GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                // Top row: Status and Date
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: statusIcon(trip.status))
                            .font(.system(size: 10, weight: .bold))
                        Text(trip.status.rawValue)
                            .font(.caption.weight(.bold))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(statusColor(trip.status).opacity(0.15))
                    .foregroundStyle(statusColor(trip.status))
                    .clipShape(Capsule())
                    
                    Spacer()
                    
                    Text(formattedDate(trip.startDate))
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                
                // Middle row: Timeline and Distance
                HStack(alignment: .center, spacing: 16) {
                    // Timeline
                    HStack(alignment: .top, spacing: 16) {
                        VStack(spacing: 0) {
                            Circle().fill(Color.blue).frame(width: 8, height: 8)
                            Rectangle().fill(Color.blue).frame(width: 2, height: 42)
                            Circle().fill(trip.status == .completed ? Color.green : Color.blue).frame(width: 8, height: 8)
                        }
                        .padding(.top, 6)
                        
                        VStack(alignment: .leading, spacing: 16) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trip.origin)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("Pickup")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(trip.destination)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("Drop-off")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    // Distance metric
                    VStack(spacing: 4) {
                        Text("/ \\") // Mock icon resembling road perspective
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.gray)
                        Text("123 km") // Mock distance
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppTheme.textPrimary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.05))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                
                Divider().background(Color.white.opacity(0.1))
                
                // Bottom row: Driver and Vehicle chips
                HStack {
                    if let driver = driver {
                        HStack(spacing: 8) {
                            Text(String(driver.name.prefix(1)).uppercased())
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                            
                            Text(driver.name)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(AppTheme.textPrimary)
                        }
                    }
                    
                    Spacer()
                    
                    if let vehicle = vehicle {
                        HStack(spacing: 6) {
                            Image(systemName: "car.fill")
                                .font(.caption)
                            Text(vehicle.plateNumber)
                                .font(.caption.weight(.medium))
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                        }
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.05))
                        .clipShape(Capsule())
                    }
                }
            }
        }
    }
    
    private func statusColor(_ status: TripStatus) -> Color {
        switch status {
        case .inProgress: return AppTheme.brand
        case .completed: return AppTheme.success
        case .scheduled: return Color.blue
        case .cancelled: return AppTheme.error
        }
    }
    
    private func statusIcon(_ status: TripStatus) -> String {
        switch status {
        case .inProgress: return "circle.fill"
        case .completed: return "checkmark.seal.fill"
        case .scheduled: return "clock.fill"
        case .cancelled: return "xmark.circle.fill"
        }
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d · h:mm a"
        return formatter.string(from: date)
    }
}
