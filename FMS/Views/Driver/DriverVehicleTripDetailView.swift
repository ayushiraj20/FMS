import SwiftUI

struct DriverVehicleTripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(DriverViewModel.self) private var driverVM

    private var currentUser: User? { appViewModel.currentUser }
    private var assignedVehicle: Vehicle? { appViewModel.assignedVehicle }
    private var activeTrip: Trip? { currentUser.flatMap { appViewModel.service.activeTrip(for: $0.id) } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                vehicleInfoCard
                
                HStack(spacing: 16) {
                    if let trip = activeTrip {
                        NavigationLink(destination: TripDetailView(trip: trip).hideTabBarOnPush()) {
                            actionButton(icon: "video.fill", title: "Live View")
                        }
                        .buttonStyle(.plain)
                        
                        NavigationLink(destination: TripDetailView(trip: trip).hideTabBarOnPush()) {
                            actionButton(icon: "map.fill", title: "Trip Map")
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button { driverVM.showToastMessage("No active trip is running") } label: {
                            actionButton(icon: "video.fill", title: "Live View")
                        }.buttonStyle(.plain)
                        
                        Button { driverVM.showToastMessage("No active trip details") } label: {
                            actionButton(icon: "map.fill", title: "Trip Map")
                        }.buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(
            ZStack {
                DriverTheme.background.ignoresSafeArea()
                GeometryReader { geo in
                    Circle()
                        .fill(DriverTheme.accent.opacity(0.1))
                        .frame(width: geo.size.width)
                        .blur(radius: 60)
                        .offset(x: geo.size.width * 0.4, y: geo.size.height * 0.1)
                }.ignoresSafeArea()
            }
        )
        .navigationTitle("Vehicle & Trip")
        .navigationBarTitleDisplayMode(.large)
    }

    private var vehicleInfoCard: some View {
        VStack(spacing: 0) {
            Image("truck_placeholder")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(height: 260)
                .frame(maxWidth: .infinity)
                .clipped()

            VStack(alignment: .leading, spacing: 20) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(assignedVehicle?.plateNumber ?? "No Vehicle")
                            .font(.system(.largeTitle, design: .rounded).bold())
                            .foregroundStyle(DriverTheme.textPrimary)
                        Text("Driver \(currentUser?.name ?? "No Driver")")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                    Spacer()
                    if let vehicle = assignedVehicle {
                        Label(vehicle.status.rawValue, systemImage: "bolt.fill")
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(vehicle.status == .active ? DriverTheme.successGreen.opacity(0.15) : DriverTheme.accent.opacity(0.15), in: Capsule())
                            .foregroundStyle(vehicle.status == .active ? DriverTheme.successGreen : DriverTheme.accent)
                    } else {
                        Label("Unassigned", systemImage: "exclamationmark.circle")
                            .font(.caption.bold())
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(DriverTheme.textSecondary.opacity(0.15), in: Capsule())
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                }

                // Only show trip alerts when an active trip exists
                if let trip = activeTrip {
                    VStack(spacing: 16) {
                        HStack {
                            Image(systemName: "clock.badge.exclamationmark").foregroundStyle(DriverTheme.accent)
                            Text("ETA:").font(.subheadline).foregroundStyle(DriverTheme.textSecondary)
                            if let endDate = trip.endDate {
                                Text(endDate.formatted(date: .omitted, time: .shortened)).font(.subheadline.bold()).foregroundStyle(DriverTheme.accent)
                            } else {
                                Text("On Schedule").font(.subheadline.bold()).foregroundStyle(DriverTheme.successGreen)
                            }
                            Spacer()
                        }
                        HStack {
                            Image(systemName: "location.fill").foregroundStyle(DriverTheme.accent)
                            Text("\(trip.origin) → \(trip.destination)").font(.subheadline).foregroundStyle(DriverTheme.textSecondary)
                            Spacer()
                        }
                    }
                    .padding()
                    .background(DriverTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))
                }

                if let vehicle = assignedVehicle {
                    VStack(alignment: .leading, spacing: 10) {
                        let fuelLevel = vehicle.fuelLevel
                        HStack {
                            Text("Fuel Level").font(.subheadline.bold()).foregroundStyle(DriverTheme.textSecondary)
                            Spacer()
                            Text("\(fuelLevel)%").font(.subheadline.bold()).foregroundStyle(fuelLevel < 35 ? DriverTheme.criticalRed : DriverTheme.textPrimary)
                        }
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.quaternary).frame(height: 10)
                                Capsule()
                                    .fill(fuelLevel < 35 ? DriverTheme.criticalRed : DriverTheme.accent)
                                    .frame(width: geometry.size.width * CGFloat(Double(fuelLevel) / 100.0), height: 10)
                            }
                        }
                        .frame(height: 10)
                    }
                } else {
                    HStack(spacing: 12) {
                        Image(systemName: "fuelpump.slash")
                            .font(.title3)
                            .foregroundStyle(DriverTheme.textSecondary)
                        Text("No vehicle assigned — fuel data unavailable")
                            .font(.subheadline)
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DriverTheme.textSecondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(24)
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .scrollTransition { content, phase in
            content.scaleEffect(phase.isIdentity ? 1 : 0.95).opacity(phase.isIdentity ? 1 : 0.8)
        }
    }

    private func actionButton(icon: String, title: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(DriverTheme.accent)
            Text(title)
                .font(.system(.subheadline, design: .rounded).bold())
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
    }
}

#Preview {
    NavigationStack {
        DriverVehicleTripDetailView()
            .environment(AppViewModel())
            .environment(DriverViewModel())
    }
}
