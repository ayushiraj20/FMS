import SwiftUI

struct DriverVehicleTripDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel
    @EnvironmentObject private var driverVM: DriverViewModel

    private var currentUser: User? { appViewModel.currentUser }
    private var assignedVehicle: Vehicle? { appViewModel.service.vehicle(for: currentUser?.assignedVehicleID) }
    private var activeTrip: Trip? { currentUser.flatMap { appViewModel.service.activeTrip(for: $0.id) } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                // Card Container
                VStack(spacing: 0) {
                    // Vehicle Image
                    Image("truck_placeholder")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: 240)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    
                    // Vehicle Info Block
                    VStack(alignment: .leading, spacing: 16) {
                        // Title Row
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 4) {
                                let plateNumber = assignedVehicle?.plateNumber ?? "TRK-2847"
                                Text(plateNumber)
                                    .font(.system(size: 32, weight: .bold))
                                    .foregroundStyle(DriverTheme.textPrimary)
                                
                                let driverName = currentUser?.name ?? "Driver Rajesh Kumar"
                                Text("Driver \(driverName)")
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundStyle(DriverTheme.textSecondary)
                            }
                            
                            Spacer()
                            
                            // Status Badge
                            Text(assignedVehicle?.status.rawValue ?? "Active")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(assignedVehicle?.status == .active ? DriverTheme.successGreen : DriverTheme.accent)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill((assignedVehicle?.status == .active ? DriverTheme.successGreen : DriverTheme.accent).opacity(0.12))
                                        .overlay(
                                            Capsule()
                                                .stroke(assignedVehicle?.status == .active ? DriverTheme.successGreen : DriverTheme.accent, lineWidth: 1)
                                        )
                                )
                        }
                        
                        Divider().background(DriverTheme.separator)
                        
                        // Status & Trip details
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 10) {
                                Image(systemName: "clock.badge.exclamationmark")
                                    .font(.system(size: 16))
                                    .foregroundStyle(DriverTheme.accent)
                                
                                HStack(spacing: 4) {
                                    Text("ETA Delay")
                                        .font(.system(size: 15))
                                        .foregroundStyle(DriverTheme.textSecondary)
                                    Text("45 min")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(DriverTheme.accent)
                                }
                            }
                            
                            HStack(spacing: 10) {
                                Image(systemName: "arrow.triangle.turn.up.right.diamond")
                                    .font(.system(size: 16))
                                    .foregroundStyle(DriverTheme.accent)
                                
                                Text("Route Deviation Alert (Panvel Outer Bypass)")
                                    .font(.system(size: 15))
                                    .foregroundStyle(DriverTheme.textSecondary)
                            }
                        }
                        
                        Divider().background(DriverTheme.separator)
                        
                        // Fuel Level Progress Bar
                        VStack(alignment: .leading, spacing: 8) {
                            let fuelLevel = assignedVehicle?.fuelLevel ?? 32
                            HStack {
                                Text("Fuel Level")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(DriverTheme.textSecondary)
                                Spacer()
                                Text("\(fuelLevel)%")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(fuelLevel < 35 ? DriverTheme.criticalRed : DriverTheme.textPrimary)
                            }
                            
                            GeometryReader { geometry in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.white.opacity(0.08))
                                        .frame(height: 8)
                                    
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(
                                            LinearGradient(
                                                colors: fuelLevel < 35 ? [DriverTheme.criticalRed, .red] : [DriverTheme.accent, Color(hex: "FF7A45")],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: geometry.size.width * CGFloat(Double(fuelLevel) / 100.0), height: 8)
                                }
                            }
                            .frame(height: 8)
                        }
                    }
                    .padding(20)
                }
                .background(DriverTheme.cardFill)
                .cornerRadius(24)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(DriverTheme.cardBorder, lineWidth: 1)
                )
                
                // Bottom Quick Action Buttons
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        // Live View button
                        if let trip = activeTrip {
                            NavigationLink(destination: TripDetailView(trip: trip)) {
                                actionButtonLabel(icon: "video.fill", title: "Live View")
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                driverVM.showToastMessage("No active trip is running")
                            } label: {
                                actionButtonLabel(icon: "video.fill", title: "Live View")
                            }
                            .buttonStyle(.plain)
                        }
                        
                        // Trip Details button
                        if let trip = activeTrip {
                            NavigationLink(destination: TripDetailView(trip: trip)) {
                                actionButtonLabel(icon: "map.fill", title: "Trip Details")
                            }
                            .buttonStyle(.plain)
                        } else {
                            Button {
                                driverVM.showToastMessage("No active trip details available")
                            } label: {
                                actionButtonLabel(icon: "map.fill", title: "Trip Details")
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    
                    // Dispatch Ping button (fills full width)
                    Button {
                        driverVM.showToastMessage("Dispatch Ping sent to Fleet Manager")
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "antenna.radiowaves.left.and.right")
                                .font(.system(size: 16, weight: .bold))
                            Text("Ping Dispatcher")
                                .font(.system(size: 16, weight: .bold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(DriverTheme.accent)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(DriverTheme.background.ignoresSafeArea())
        .navigationTitle("Vehicle details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func actionButtonLabel(icon: String, title: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(DriverTheme.textPrimary)
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(DriverTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(DriverTheme.cardFill)
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(DriverTheme.cardBorder, lineWidth: 1)
        )
    }
}

#Preview {
    NavigationStack {
        DriverVehicleTripDetailView()
            .environmentObject(AppViewModel())
            .environmentObject(DriverViewModel())
    }
}
