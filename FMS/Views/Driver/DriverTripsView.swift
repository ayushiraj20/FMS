import SwiftUI
import MapKit

struct DriverTripTabView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(DriverViewModel.self) private var driverVM

    private var currentUser: User? { appViewModel.currentUser }

    var body: some View {
        Group {
            if let user = currentUser, let activeTrip = appViewModel.service.activeTrip(for: user.id) {
                ActiveTripMapView(trip: activeTrip)
                    .toolbar(.hidden, for: .navigationBar)
            } else {
                AssignedRoutesView()
            }
        }
    }
}

// MARK: - Active Trip Map View

struct ActiveTripMapView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(DriverViewModel.self) private var driverVM
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showReportSheet = false

    let trip: Trip

    // Mumbai to Pune route coordinates
    private let routeCoordinates: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 19.0760, longitude: 72.8777), // Mumbai
        CLLocationCoordinate2D(latitude: 19.0330, longitude: 73.0297), // Panvel
        CLLocationCoordinate2D(latitude: 18.7557, longitude: 73.4091), // Lonavala
        CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567)  // Pune
    ]

    private var currentPosition: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: 18.9000, longitude: 73.2500)
    }

    var body: some View {
        ZStack {
            // Map
            Map(position: $cameraPosition) {
                // Route polyline
                MapPolyline(coordinates: routeCoordinates)
                    .stroke(DriverTheme.accent, lineWidth: 6)

                // Origin marker
                Annotation("Start", coordinate: routeCoordinates.first ?? currentPosition) {
                    Circle()
                        .fill(DriverTheme.successGreen)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }

                // Destination marker
                Annotation("End", coordinate: routeCoordinates.last ?? currentPosition) {
                    Circle()
                        .fill(DriverTheme.criticalRed)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }

                // Current position
                Annotation("Current", coordinate: currentPosition) {
                    Image(systemName: "truck.box.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Circle().fill(DriverTheme.accent))
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .ignoresSafeArea()

            // Overlays
            VStack {
                topOverlays
                Spacer()
                bottomButtons
            }

            // Left info card
            VStack {
                HStack {
                    leftInfoCard
                    Spacer()
                }
                .padding(.top, 100)
                Spacer()
            }

            // Speed limit indicator
            VStack {
                HStack {
                    Spacer()
                    speedLimitIndicator
                }
                .padding(.top, 100)
                .padding(.trailing, 16)
                Spacer()
            }
        }
        .onAppear {
            let center = CLLocationCoordinate2D(latitude: 18.8, longitude: 73.15)
            cameraPosition = .region(MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
            ))
        }
        .sheet(isPresented: $showReportSheet) {
            DefectReportView()
                .environment(appViewModel)
        }
    }

    // MARK: - Top Overlays

    private var topOverlays: some View {
        HStack(alignment: .top) {
            // Active Trip pill
            HStack(spacing: 8) {
                Circle()
                    .fill(DriverTheme.accent)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(DriverTheme.accent.opacity(0.3), lineWidth: 4)
                            .scaleEffect(1.5)
                    )
                Text("Active Trip")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(DriverTheme.textPrimary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().stroke(DriverTheme.cardBorder, lineWidth: 0.5))
            )

            Spacer()

            // Route pill
            HStack(spacing: 6) {
                Image(systemName: "arrow.turn.up.right")
                    .font(.system(size: 12, weight: .semibold))
                VStack(alignment: .leading, spacing: 1) {
                    Text("Route")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Next: NH48 - 4.2 km")
                        .font(.system(size: 11))
                        .foregroundStyle(DriverTheme.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(.ultraThinMaterial)
                    .overlay(Capsule().stroke(DriverTheme.cardBorder, lineWidth: 0.5))
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 60)
    }

    // MARK: - Left Info Card

    private var leftInfoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(trip.destination)
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(DriverTheme.textPrimary)

            Text("1h 23m")
                .font(.system(size: 40, weight: .bold))
                .foregroundStyle(DriverTheme.textPrimary)

            Text("\(Int(driverVM.currentSpeed)) km/h")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(DriverTheme.textPrimary)

            // Speed bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(driverVM.currentSpeed > driverVM.speedLimit ? DriverTheme.criticalRed : DriverTheme.accent)
                        .frame(width: geometry.size.width * min(driverVM.currentSpeed / driverVM.speedLimit, 1.0), height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .frame(width: 180)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(DriverTheme.cardBorder, lineWidth: 0.5)
                )
        )
        .padding(.leading, 16)
    }

    // MARK: - Speed Limit

    private var speedLimitIndicator: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 50, height: 50)
                .overlay(
                    Circle().stroke(DriverTheme.criticalRed, lineWidth: 4)
                )
            Text("\(Int(driverVM.speedLimit))")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(DriverTheme.textPrimary)
        }
        .shadow(color: DriverTheme.cardShadow, radius: 4)
    }

    // MARK: - Bottom Buttons

    private var bottomButtons: some View {
        HStack(spacing: 12) {
            // Navigate
            Button {
                // Open Apple Maps
                let destination = MKMapItem(placemark: MKPlacemark(coordinate: routeCoordinates.last ?? currentPosition))
                destination.name = trip.destination
                destination.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14))
                    Text("Navigate")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Capsule().fill(DriverTheme.accent))
            }
            .accessibilityIdentifier("NAV_BUTTON_NAVIGATE")

            // Report Issue
            Button {
                showReportSheet = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 14))
                    Text("Report Issue")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Capsule().fill(Color(hex: "333333")))
            }
            .accessibilityIdentifier("NAV_BUTTON_REPORT")

            // SOS
            Button {
                driverVM.startSOSCountdown(service: appViewModel.service, user: appViewModel.currentUser)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sos")
                        .font(.system(size: 14, weight: .bold))
                    Text("SOS")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(width: 80)
                .frame(height: 56)
                .background(Capsule().fill(DriverTheme.criticalRed))
            }
            .accessibilityIdentifier("NAV_BUTTON_SOS")
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 30)
    }
}

#Preview {
    DriverTripTabView()
        .environment(AppViewModel())
        .environment(DriverViewModel())
}
