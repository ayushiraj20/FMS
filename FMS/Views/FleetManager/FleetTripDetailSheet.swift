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
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var routeDistanceKM: Double = 0
    @State private var routeETAMinutes: Double = 0

    private var originCoordinate: CLLocationCoordinate2D? {
        guard let lat = trip.originLat, let lng = trip.originLng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
    private var destinationCoordinate: CLLocationCoordinate2D? {
        guard let lat = trip.destinationLat, let lng = trip.destinationLng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                AppTheme.background.ignoresSafeArea()
                
                // Real Map with Route
                VStack(spacing: 0) {
                    ZStack {
                        Map(position: $cameraPosition) {
                            if !routeCoordinates.isEmpty {
                                MapPolyline(coordinates: routeCoordinates)
                                    .stroke(
                                        AppTheme.brand,
                                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
                                    )
                            }

                            if let coord = originCoordinate {
                                Annotation(trip.origin, coordinate: coord) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.blue)
                                            .frame(width: 18, height: 18)
                                            .overlay(Circle().stroke(Color.white, lineWidth: 3))
                                            .shadow(color: Color.blue.opacity(0.4), radius: 4)
                                    }
                                }
                            }

                            if let coord = destinationCoordinate {
                                Annotation(trip.destination, coordinate: coord) {
                                    ZStack {
                                        Circle()
                                            .fill(Color.orange)
                                            .frame(width: 18, height: 18)
                                            .overlay(Circle().stroke(Color.white, lineWidth: 3))
                                            .shadow(color: Color.orange.opacity(0.4), radius: 4)
                                    }
                                }
                            }
                        }
                        .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))

                        // Route info badge
                        if routeDistanceKM > 0 {
                            VStack {
                                Spacer()
                                HStack(spacing: 12) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "road.lanes")
                                            .font(.system(size: 11, weight: .semibold))
                                        Text("\(Int(routeDistanceKM)) km")
                                            .font(.system(size: 12, weight: .bold))
                                    }
                                    Divider().frame(height: 14)
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock.fill")
                                            .font(.system(size: 11, weight: .semibold))
                                        Text(formatETA(routeETAMinutes))
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
                                value: routeDistanceKM > 0 ? "\(Int(routeDistanceKM)) km" : "\(Int(trip.distanceKM)) km",
                                label: "Distance",
                                icon: "road.lanes"
                            )
                            Spacer()
                            metricView(
                                value: routeETAMinutes > 0 ? formatETA(routeETAMinutes) : "--",
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
        guard let origin = originCoordinate, let dest = destinationCoordinate else {
            // Center on India as fallback
            cameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 22.5, longitude: 79.0),
                span: MKCoordinateSpan(latitudeDelta: 8.0, longitudeDelta: 8.0)
            ))
            return
        }

        Task {
            let request = MKDirections.Request()
            request.source = MKMapItem(location: CLLocation(latitude: origin.latitude, longitude: origin.longitude), address: nil as MKAddress?)
            request.destination = MKMapItem(location: CLLocation(latitude: dest.latitude, longitude: dest.longitude), address: nil as MKAddress?)
            request.transportType = .automobile

            do {
                let directions = MKDirections(request: request)
                let response = try await directions.calculate()
                if let route = response.routes.first {
                    let pointCount = route.polyline.pointCount
                    let points = route.polyline.points()
                    var coords: [CLLocationCoordinate2D] = []
                    coords.reserveCapacity(pointCount)
                    for i in 0..<pointCount {
                        coords.append(points[i].coordinate)
                    }
                    routeCoordinates = coords
                    routeDistanceKM = route.distance / 1000.0
                    routeETAMinutes = route.expectedTravelTime / 60.0
                }
            } catch {
                print("[FleetTripDetail] Route error: \(error.localizedDescription)")
            }

            // Fit camera
            let midLat = (origin.latitude + dest.latitude) / 2
            let midLng = (origin.longitude + dest.longitude) / 2
            let latDelta = abs(origin.latitude - dest.latitude) * 1.5 + 0.05
            let lngDelta = abs(origin.longitude - dest.longitude) * 1.5 + 0.05
            withAnimation(.easeInOut(duration: 0.6)) {
                cameraPosition = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: midLat, longitude: midLng),
                    span: MKCoordinateSpan(latitudeDelta: max(latDelta, 0.1), longitudeDelta: max(lngDelta, 0.1))
                ))
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
