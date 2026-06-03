import SwiftUI
import MapKit

struct FleetTripDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel
    private let initialTrip: Trip

    private var trip: Trip {
        appViewModel.service.trips.first(where: { $0.id == initialTrip.id }) ?? initialTrip
    }

    init(trip: Trip) {
        self.initialTrip = trip
    }

    // Route state
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var routePlan: TripRoutePlan?

    private var originCoordinate: CLLocationCoordinate2D? { trip.originCoordinate }
    private var destinationCoordinate: CLLocationCoordinate2D? { trip.destinationCoordinate }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppTheme.background.ignoresSafeArea()
                
                // Real Map with Route
                VStack(spacing: 0) {
                    ZStack {
                        Map(position: $cameraPosition) {
                            if let routePlan {
                                TripRoutesMapContent(plan: routePlan)
                            } else if let originCoordinate, let destinationCoordinate {
                                MapPolyline(coordinates: [originCoordinate, destinationCoordinate])
                                    .stroke(AppTheme.brand, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
                            }
                        }
                        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))

                        // Route info badge
                        if let routePlan {
                            VStack {
                                Spacer()
                                HStack(spacing: 12) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "road.lanes")
                                            .font(.system(size: 11, weight: .semibold))
                                        Text("\(Int(routePlan.mainDistanceKM)) km")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                    Divider().frame(height: 14)
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock.fill")
                                            .font(.system(size: 11, weight: .semibold))
                                        Text(formatETA(routePlan.mainETAMinutes))
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .background(AppTheme.brand.opacity(0.7))
                                .clipShape(Capsule())
                                .padding(.bottom, 12)

                                if trip.status != .completed {
                                    TripRouteLegendView()
                                        .padding(.bottom, 8)
                                }
                            }
                        }
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
                                        .lineLimit(2)
                                    Text(formattedDate(trip.startDate))
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(trip.destination)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                        .lineLimit(2)
                                    Text(trip.endDate != nil ? formattedDate(trip.endDate!) : "End time TBD")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                            }
                            Spacer()
                        }
                        
                        Divider().background(Color.white.opacity(0.1))
                        
                        // Metrics
                        HStack(spacing: 0) {
                            metricView(
                                value: (routePlan?.mainDistanceKM ?? 0) > 0 ? "\(Int(routePlan?.mainDistanceKM ?? trip.distanceKM)) km" : "\(Int(trip.distanceKM)) km",
                                label: "Distance",
                                icon: "road.lanes"
                            )
                            Spacer()
                            metricView(
                                value: (routePlan?.mainETAMinutes ?? 0) > 0 ? formatETA(routePlan?.mainETAMinutes ?? 0) : "--",
                                label: "Est. Time",
                                icon: "clock.fill"
                            )
                            Spacer()
                            metricView(
                                value: trip.safetyScore != nil ? "\(trip.safetyScore!)/100" : "--",
                                label: "Safety Score",
                                icon: "shield.fill"
                            )
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
            .onAppear {
                loadRoute()
            }
        }
    }

    // MARK: - Load Route
    private func loadRoute() {
        guard originCoordinate != nil, destinationCoordinate != nil else {
            cameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 22.5, longitude: 79.0),
                span: MKCoordinateSpan(latitudeDelta: 8.0, longitudeDelta: 8.0)
            ))
            return
        }

        Task {
            let plan = await appViewModel.service.tripRoutePlan(for: trip)
            routePlan = plan
            withAnimation(.easeInOut(duration: 0.6)) {
                if let plan {
                    let coordinates = trip.status == .completed
                        ? plan.mainRouteCoordinates
                        : plan.allRoutes.flatMap { $0 }
                    cameraPosition = .region(FleetMapRegion.region(for: coordinates))
                } else if let origin = originCoordinate, let dest = destinationCoordinate {
                    cameraPosition = .region(FleetMapRegion.region(for: [origin, dest]))
                }
            }
        }
    }

    // MARK: - Helpers
    private func formatETA(_ minutes: Double) -> String {
        let total = Int(minutes)
        if total < 60 { return "\(total) min" }
        let h = total / 60, m = total % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }
    
    private func metricView(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
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
