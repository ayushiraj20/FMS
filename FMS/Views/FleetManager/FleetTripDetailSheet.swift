import SwiftUI

struct FleetTripDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel
    let trip: Trip
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppTheme.background.ignoresSafeArea()
                
                // Map Placeholder
                VStack(spacing: 0) {
                    ZStack {
                        Color(red: 0.92, green: 0.94, blue: 0.96).ignoresSafeArea(edges: .top) // Map background color mockup
                        
                        // Mock route curve
                        Path { path in
                            path.move(to: CGPoint(x: 100, y: 150))
                            path.addQuadCurve(to: CGPoint(x: 280, y: 50), control: CGPoint(x: 150, y: 50))
                        }
                        .stroke(AppTheme.brand, style: StrokeStyle(lineWidth: 3, dash: [5]))
                        
                        // Origin dot
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .position(x: 100, y: 150)
                        
                        // Destination dot
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 14, height: 14)
                            .overlay(Circle().stroke(Color.white, lineWidth: 2))
                            .position(x: 280, y: 50)
                    }
                    .frame(height: 350)
                    
                    Spacer()
                }
                
                // Content Sheet
                VStack(spacing: 0) {
                    Spacer()
                    
                    VStack(spacing: 24) {
                        // Drag Indicator
                        Capsule()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 40, height: 4)
                            .padding(.top, 12)
                        
                        HStack {
                            StatusBadgeView(
                                text: trip.status.rawValue,
                                color: statusColor(trip.status)
                            )
                            Spacer()
                            Text("Trip - \(trip.id.uuidString.prefix(8).uppercased())")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        
                        // Timeline
                        HStack(alignment: .top, spacing: 16) {
                            // Timeline graphic
                            VStack(spacing: 0) {
                                Circle().fill(Color.blue).frame(width: 10, height: 10)
                                Rectangle().fill(Color.orange).frame(width: 2, height: 40)
                                Circle().fill(Color.orange).frame(width: 10, height: 10)
                            }
                            .padding(.top, 4)
                            
                            VStack(alignment: .leading, spacing: 20) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(trip.origin)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text(formattedDate(trip.startDate))
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(trip.destination)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text("End time TBD")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                            Spacer()
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        // Metrics
                        HStack(spacing: 0) {
                            metricView(value: "148 km", label: "Distance", icon: nil)
                            Spacer()
                            metricView(value: "87/100", label: "Safety Score", icon: "shield.fill")
                            Spacer()
                            metricView(value: "3", label: "Stops", icon: "mappin.circle.fill")
                        }
                        
                        // Driver and Vehicle Chips
                        HStack(spacing: 12) {
                            if let driver = appViewModel.service.user(for: trip.driverID) {
                                chipView(
                                    icon: "person.fill",
                                    iconColor: .blue,
                                    title: driver.name,
                                    subtitle: "Driver"
                                )
                            }
                            
                            if let vehicle = appViewModel.service.vehicle(for: trip.vehicleID) {
                                chipView(
                                    icon: "car.fill",
                                    iconColor: .orange,
                                    title: vehicle.plateNumber,
                                    subtitle: vehicle.displayName
                                )
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .background(AppTheme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                    .frame(height: 500)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.black)
                            .frame(width: 36, height: 36)
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                }
            }
        }
    }
    
    private func metricView(value: String, label: String, icon: String?) -> some View {
        VStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            } else {
                Text("--") // placeholder for distance icon graphic
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.textPrimary)
            Text(label)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
        }
    }
    
    private func chipView(icon: String, iconColor: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(iconColor)
                .frame(width: 32, height: 32)
                .background(iconColor.opacity(0.1))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d · h:mm a"
        return formatter.string(from: date)
    }
    
    private func statusColor(_ status: TripStatus) -> Color {
        switch status {
        case .inProgress: return AppTheme.brand
        case .completed: return AppTheme.success
        case .scheduled: return AppTheme.warning
        case .cancelled: return AppTheme.error
        }
    }
}
