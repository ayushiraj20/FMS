import SwiftUI
import MapKit

struct DriverTripTabView: View {
    @Environment(AppViewModel.self) private var appViewModel: AppViewModel
    @Environment(DriverViewModel.self) private var driverVM: DriverViewModel

    private var currentUser: User? { appViewModel.currentUser }

    var body: some View {
        let activeTrip = currentUser.flatMap { appViewModel.service.activeTrip(for: $0.id) }

        Group {
            if let activeTrip {
                ActiveTripMapView(trip: activeTrip)
            } else {
                AssignedRoutesView()
            }
        }
        .toolbar(activeTrip != nil ? .hidden : .visible, for: .navigationBar)
    }
}

// MARK: - Active Trip Map View
struct ActiveTripMapView: View {
    @Environment(AppViewModel.self) private var appViewModel: AppViewModel
    @Environment(DriverViewModel.self) private var driverVM: DriverViewModel
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showReportSheet = false

    let trip: Trip

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
            Map(position: $cameraPosition) {
                MapPolyline(coordinates: routeCoordinates)
                    .stroke(DriverTheme.accent.opacity(0.8), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))

                Annotation("Start", coordinate: routeCoordinates.first ?? currentPosition) {
                    Circle()
                        .fill(DriverTheme.successGreen)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .shadow(radius: 4)
                }

                Annotation("End", coordinate: routeCoordinates.last ?? currentPosition) {
                    Circle()
                        .fill(DriverTheme.criticalRed)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .shadow(radius: 4)
                }

                Annotation("Current", coordinate: currentPosition) {
                    ZStack {
                        Circle()
                            .fill(DriverTheme.accent.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .symbolEffect(.pulse, options: .repeating)
                        
                        Image(systemName: "location.north.fill")
                            .font(.title2)
                            .foregroundStyle(.white)
                            .padding(12)
                            .background(DriverTheme.accent, in: Circle())
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                            .shadow(radius: 6)
                            .rotationEffect(.degrees(45))
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            .ignoresSafeArea()

            VStack {
                topOverlays
                Spacer()
                HStack(alignment: .bottom) {
                    leftInfoCard
                    Spacer()
                    speedLimitIndicator
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                bottomButtons
            }
        }
        .onAppear {
            let center = CLLocationCoordinate2D(latitude: 18.8, longitude: 73.15)
            cameraPosition = .region(MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)))
        }
        .sheet(isPresented: $showReportSheet) {
            DefectReportView().environment(appViewModel)
        }
    }

    // MARK: - Top Overlays
    private var topOverlays: some View {
        HStack {
            Label("Active Trip", systemImage: "circle.fill")
                .font(.system(.subheadline, design: .rounded).bold())
                .foregroundStyle(DriverTheme.textPrimary)
                .symbolEffect(.pulse, options: .repeating)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(radius: 5)

            Spacer()

            HStack(spacing: 8) {
                Image(systemName: "arrow.turn.up.right")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .padding(8)
                    .background(DriverTheme.accent, in: Circle())
                
                VStack(alignment: .leading) {
                    Text("Next: NH48")
                        .font(.system(.headline, design: .rounded).bold())
                    Text("4.2 km")
                        .font(.caption.bold())
                        .foregroundStyle(DriverTheme.textSecondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial, in: Capsule())
            .shadow(radius: 5)
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
    }

    // MARK: - Left Info Card
    private var leftInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(trip.destination)
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(DriverTheme.textPrimary)

            Text("1h 23m")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(DriverTheme.textPrimary)
                .contentTransition(.numericText())

            Text("\(Int(driverVM.currentSpeed)) km/h")
                .font(.title2.bold())
                .foregroundStyle(DriverTheme.textPrimary)
                .contentTransition(.numericText())

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.3)).frame(height: 8)
                    Capsule()
                        .fill(driverVM.currentSpeed > driverVM.speedLimit ? DriverTheme.criticalRed : DriverTheme.accent)
                        .frame(width: geometry.size.width * min(driverVM.currentSpeed / driverVM.speedLimit, 1.0), height: 8)
                }
            }
            .frame(height: 8)
        }
        .padding(20)
        .frame(width: 200)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.15), radius: 10, x: 0, y: 5)
    }

    // MARK: - Speed Limit
    private var speedLimitIndicator: some View {
        ZStack {
            Circle().fill(.ultraThinMaterial).frame(width: 60, height: 60)
            Circle().stroke(DriverTheme.criticalRed, lineWidth: 6).frame(width: 60, height: 60)
            Text("\(Int(driverVM.speedLimit))")
                .font(.system(.title2, design: .rounded).bold())
                .foregroundStyle(DriverTheme.textPrimary)
        }
        .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }

    // MARK: - Bottom Buttons
    private var bottomButtons: some View {
        HStack(spacing: 16) {
            Button {
                let dest = routeCoordinates.last ?? currentPosition
                if let url = URL(string: "http://maps.apple.com/?daddr=\(dest.latitude),\(dest.longitude)&dirflg=d") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Label("Navigate", systemImage: "location.fill")
                    .font(.system(.headline, design: .rounded).bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 60)
                    .background(DriverTheme.accent, in: Capsule())
            }

            Button {
                showReportSheet = true
            } label: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 60, height: 60)
                    .background(.regularMaterial, in: Circle())
            }

            Button {
                driverVM.startSOSCountdown(service: appViewModel.service, user: appViewModel.currentUser)
            } label: {
                Text("SOS")
                    .font(.system(.headline, design: .rounded).bold())
                    .foregroundStyle(.white)
                    .frame(width: 80, height: 60)
                    .background(DriverTheme.criticalRed, in: Capsule())
                    .symbolEffect(.pulse)
            }
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
