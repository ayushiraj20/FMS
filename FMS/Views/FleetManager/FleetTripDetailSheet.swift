import SwiftUI
import MapKit

struct FleetTripDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel
    let trip: Trip
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showDetailSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                Map(position: $cameraPosition) {
                    MapPolyline(coordinates: mapRoute)
                        .stroke(AppTheme.brand, style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round))
                    
                    Annotation("Destination", coordinate: destinationCoordinate) {
                        markerView(color: .orange, icon: "flag.fill")
                    }
                    
                    Annotation("Current", coordinate: currentCoordinate) {
                        markerView(color: .blue, icon: "location.fill")
                    }

                    Annotation("Origin", coordinate: originCoordinate) {
                        markerView(color: AppTheme.brand, icon: "circle.fill")
                    }
                }
                .ignoresSafeArea()

                detailsSheet
                    .offset(y: showDetailSheet ? 0 : 420)
                    .animation(.spring(response: 0.35, dampingFraction: 0.86), value: showDetailSheet)
            }
            .onAppear(perform: configureMap)
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
    
    private var detailsSheet: some View {
        VStack(spacing: 24) {
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

            HStack(alignment: .top, spacing: 16) {
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
                        Text(trip.endDate.map(formattedDate) ?? "End time TBD")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                }
                Spacer()
            }

            Divider().background(Color.white.opacity(0.1))

            HStack(spacing: 0) {
                metricView(value: distanceText, label: "Distance", icon: "point.topleft.down.curvedto.point.bottomright.up")
                Spacer()
                metricView(value: safetyText, label: "Safety Score", icon: "shield.fill")
                Spacer()
                metricView(value: routePointCountText, label: "Route Points", icon: "mappin.circle.fill")
            }

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

            if let routeDetails = trip.routeDetails, !routeDetails.isEmpty {
                detailRow(title: "Route", value: routeDetails)
            }
            if let notes = trip.notes, !notes.isEmpty {
                detailRow(title: "Notes", value: notes)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .background(AppTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
        .frame(height: 500)
    }
    
    private var fleetLocation: FleetVehicleLocation? {
        appViewModel.service.allFleetLocations().first { $0.vehicle.id == trip.vehicleID }
    }
    
    private var mapRoute: [CLLocationCoordinate2D] {
        if let coordinates = fleetLocation?.route.coordinates, !coordinates.isEmpty {
            return coordinates
        }
        return [originCoordinate, currentCoordinate, destinationCoordinate]
    }
    
    private var originCoordinate: CLLocationCoordinate2D {
        mapRoute.first ?? CLLocationCoordinate2D(latitude: 19.0760, longitude: 72.8777)
    }
    
    private var destinationCoordinate: CLLocationCoordinate2D {
        mapRoute.last ?? CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567)
    }
    
    private var currentCoordinate: CLLocationCoordinate2D {
        fleetLocation?.coordinate ?? mapRoute.dropFirst().first ?? originCoordinate
    }
    
    private var distanceText: String {
        guard trip.distanceKM > 0 else { return "-- km" }
        return "\(Int(trip.distanceKM.rounded())) km"
    }
    
    private var safetyText: String {
        if let safety = trip.safetyScore { return "\(safety)/100" }
        return "--/100"
    }
    
    private var routePointCountText: String {
        "\(mapRoute.count)"
    }
    
    private func configureMap() {
        cameraPosition = .region(FleetMapRegion.region(for: mapRoute))
        DispatchQueue.main.async {
            showDetailSheet = true
        }
    }
    
    private func markerView(color: Color, icon: String) -> some View {
        ZStack {
            Circle()
                .fill(color)
                .frame(width: 22, height: 22)
            Image(systemName: icon)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
        }
        .overlay(
            Circle()
                .stroke(.white, lineWidth: 2)
        )
    }
    
    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func metricView(value: String, label: String, icon: String?) -> some View {
        VStack(spacing: 4) {
            if let icon = icon {
                Image(systemName: icon)
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
