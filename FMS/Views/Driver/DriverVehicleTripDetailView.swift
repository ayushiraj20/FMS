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
                        NavigationLink(destination: TripDetailView(trip: trip)) {
                            actionButton(icon: "video.fill", title: "Live View")
                        }
                        .buttonStyle(.plain)
                        
                        NavigationLink(destination: TripDetailView(trip: trip)) {
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
                
                Button {
                    driverVM.showToastMessage("Dispatch Ping sent to Fleet Manager")
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                        Text("Ping Dispatcher")
                    }
                    .font(.system(.headline, design: .rounded).bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(DriverTheme.accent, in: Capsule())
                }
                .buttonStyle(.plain)
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
                        Text(assignedVehicle?.plateNumber ?? "TRK-2847")
                            .font(.system(.largeTitle, design: .rounded).bold())
                            .foregroundStyle(DriverTheme.textPrimary)
                        Text("Driver \(currentUser?.name ?? "Rajesh Kumar")")
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                    Spacer()
                    Label(assignedVehicle?.status.rawValue ?? "Active", systemImage: "bolt.fill")
                        .font(.caption.bold())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(assignedVehicle?.status == .active ? DriverTheme.successGreen.opacity(0.15) : DriverTheme.accent.opacity(0.15), in: Capsule())
                        .foregroundStyle(assignedVehicle?.status == .active ? DriverTheme.successGreen : DriverTheme.accent)
                }

                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "clock.badge.exclamationmark").foregroundStyle(DriverTheme.accent)
                        Text("ETA Delay:").font(.subheadline).foregroundStyle(DriverTheme.textSecondary)
                        Text("45 min").font(.subheadline.bold()).foregroundStyle(DriverTheme.accent)
                        Spacer()
                    }
                    HStack {
                        Image(systemName: "arrow.triangle.turn.up.right.diamond").foregroundStyle(DriverTheme.accent)
                        Text("Route Deviation Alert").font(.subheadline).foregroundStyle(DriverTheme.textSecondary)
                        Spacer()
                    }
                }
                .padding()
                .background(DriverTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 16))

                VStack(alignment: .leading, spacing: 10) {
                    let fuelLevel = assignedVehicle?.fuelLevel ?? 32
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
