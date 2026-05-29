import SwiftUI
import MapKit

// MARK: - Driver Trip Tab with Segmented Control
struct DriverTripTabView: View {
    @Environment(AppViewModel.self) private var appViewModel: AppViewModel
    @Environment(DriverViewModel.self) private var driverVM: DriverViewModel

    @State private var selectedSegment: TripSegment = .current

    private var currentUser: User? { appViewModel.currentUser }

    enum TripSegment: String, CaseIterable {
        case current = "Current Trip"
        case completed = "Completed"
    }

    var body: some View {
        let activeTrip = currentUser.flatMap { appViewModel.service.activeTrip(for: $0.id) }

        VStack(spacing: 0) {
            // Segmented Control
            if activeTrip == nil {
                Picker("Trip View", selection: $selectedSegment) {
                    ForEach(TripSegment.allCases, id: \.self) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }

            // Content
            Group {
                if let activeTrip {
                    ActiveTripMapView(trip: activeTrip)
                } else {
                    switch selectedSegment {
                    case .current:
                        AssignedRoutesView()
                    case .completed:
                        CompletedTripsView()
                    }
                }
            }
        }
        .toolbar(activeTrip != nil ? .hidden : .visible, for: .navigationBar)
    }
}

// MARK: - Completed Trips View
struct CompletedTripsView: View {
    @Environment(AppViewModel.self) private var appViewModel: AppViewModel

    private var currentUser: User? { appViewModel.currentUser }

    private var completedTrips: [Trip] {
        guard let user = currentUser else { return [] }
        return appViewModel.service.trips(for: user.id)
            .filter { $0.status == .completed }
            .sorted { $0.startDate > $1.startDate }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                if completedTrips.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(completedTrips) { trip in
                            NavigationLink(destination: TripDetailView(trip: trip)) {
                                completedTripCard(trip)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .refreshable {
            await appViewModel.service.syncWithDatabase()
        }
        .background(
            ZStack {
                DriverTheme.background.ignoresSafeArea()
                GeometryReader { geo in
                    Circle()
                        .fill(DriverTheme.successGreen.opacity(0.08))
                        .frame(width: geo.size.width)
                        .blur(radius: 60)
                        .offset(x: -geo.size.width * 0.3, y: geo.size.height * 0.2)
                }
                .ignoresSafeArea()
            }
        )
        .navigationTitle("Completed Trips")
        .navigationBarTitleDisplayMode(.large)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(DriverTheme.successGreen.opacity(0.4))
                .symbolEffect(.pulse)
            Text("No completed trips")
                .font(.system(.title3, design: .rounded).bold())
            Text("Your completed trips will appear here")
                .font(.subheadline)
                .foregroundStyle(DriverTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 32))
    }

    private func completedTripCard(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Completed", systemImage: "checkmark.circle.fill")
                    .font(.subheadline.bold())
                    .foregroundStyle(DriverTheme.successGreen)
                Spacer()
                if let score = trip.safetyScore {
                    HStack(spacing: 4) {
                        Image(systemName: "shield.checkerboard")
                        Text("\(score)")
                    }
                    .font(.caption2.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(DriverTheme.successGreen.opacity(0.15), in: Capsule())
                    .foregroundStyle(DriverTheme.successGreen)
                }
            }

            HStack(spacing: 12) {
                VStack(spacing: 0) {
                    Circle().fill(DriverTheme.successGreen).frame(width: 10, height: 10)
                    Rectangle().fill(DriverTheme.textSecondary.opacity(0.3)).frame(width: 2, height: 24)
                    Circle().fill(DriverTheme.criticalRed).frame(width: 10, height: 10)
                }
                VStack(alignment: .leading, spacing: 14) {
                    Text(trip.origin).font(.system(.headline, design: .rounded).bold())
                    Text(trip.destination).font(.system(.headline, design: .rounded).bold())
                }
                Spacer()
            }

            Divider().background(DriverTheme.textSecondary.opacity(0.3))

            HStack(spacing: 16) {
                Label(trip.startDate.formatted(date: .abbreviated, time: .shortened), systemImage: "calendar")
                    .font(.caption.bold())
                    .foregroundStyle(DriverTheme.textSecondary)
                Label("\(Int(trip.distanceKM)) km", systemImage: "road.lanes")
                    .font(.caption.bold())
                    .foregroundStyle(DriverTheme.textSecondary)
                Spacer()
                if let endDate = trip.endDate {
                    Label(endDate.formatted(date: .omitted, time: .shortened), systemImage: "flag.checkered")
                        .font(.caption.bold())
                        .foregroundStyle(DriverTheme.successGreen)
                }
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .scrollTransition { content, phase in
            content.scaleEffect(phase.isIdentity ? 1 : 0.95).opacity(phase.isIdentity ? 1 : 0.8)
        }
    }
}

// MARK: - Active Trip Map View
struct ActiveTripMapView: View {
    @Environment(AppViewModel.self) private var appViewModel: AppViewModel
    @Environment(DriverViewModel.self) private var driverVM: DriverViewModel
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var showReportSheet = false
    @State private var calculatedRoute: MKRoute?

    let trip: Trip

    // Use trip coordinates if available, otherwise fallback
    private var originCoordinate: CLLocationCoordinate2D {
        if let lat = trip.originLat, let lng = trip.originLng {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        return CLLocationCoordinate2D(latitude: 19.0760, longitude: 72.8777)
    }

    private var destinationCoordinate: CLLocationCoordinate2D {
        if let lat = trip.destinationLat, let lng = trip.destinationLng {
            return CLLocationCoordinate2D(latitude: lat, longitude: lng)
        }
        return CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567)
    }

    private var routeCoordinates: [CLLocationCoordinate2D] {
        if let route = calculatedRoute {
            // Extract polyline coordinates from MKRoute
            let polyline = route.polyline
            var coords = [CLLocationCoordinate2D](repeating: CLLocationCoordinate2D(), count: polyline.pointCount)
            polyline.getCoordinates(&coords, range: NSRange(location: 0, length: polyline.pointCount))
            return coords
        }
        return [originCoordinate, destinationCoordinate]
    }

    private var currentPosition: CLLocationCoordinate2D {
        driverVM.currentLocation ?? originCoordinate
    }

    var body: some View {
        ZStack {
            Map(position: $cameraPosition) {
                if let route = calculatedRoute {
                    MapPolyline(route.polyline)
                        .stroke(DriverTheme.accent.opacity(0.8), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                } else {
                    MapPolyline(coordinates: [originCoordinate, destinationCoordinate])
                        .stroke(DriverTheme.accent.opacity(0.8), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                }

                Annotation("Start", coordinate: originCoordinate) {
                    Circle()
                        .fill(DriverTheme.successGreen)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .shadow(radius: 4)
                }

                Annotation("End", coordinate: destinationCoordinate) {
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
            calculateRoute()
            driverVM.startLiveTracking()
        }
        .onDisappear {
            driverVM.stopLiveTracking()
        }
        .sheet(isPresented: $showReportSheet) {
            DefectReportView().environment(appViewModel)
        }
    }

    // MARK: - Route Calculation
    private func calculateRoute() {
        let request = MKDirections.Request()
        request.source = MKMapItem(location: CLLocation(latitude: originCoordinate.latitude, longitude: originCoordinate.longitude), address: nil as MKAddress?)
        request.destination = MKMapItem(location: CLLocation(latitude: destinationCoordinate.latitude, longitude: destinationCoordinate.longitude), address: nil as MKAddress?)
        request.transportType = .automobile

        Task {
            let directions = MKDirections(request: request)
            if let response = try? await directions.calculate(),
               let route = response.routes.first {
                await MainActor.run {
                    self.calculatedRoute = route
                    let rect = route.polyline.boundingMapRect
                    cameraPosition = .rect(rect.insetBy(dx: -rect.size.width * 0.2, dy: -rect.size.height * 0.2))
                }
            } else {
                // Fallback: center between origin and destination
                let center = CLLocationCoordinate2D(
                    latitude: (originCoordinate.latitude + destinationCoordinate.latitude) / 2,
                    longitude: (originCoordinate.longitude + destinationCoordinate.longitude) / 2
                )
                let span = MKCoordinateSpan(
                    latitudeDelta: abs(originCoordinate.latitude - destinationCoordinate.latitude) * 1.5,
                    longitudeDelta: abs(originCoordinate.longitude - destinationCoordinate.longitude) * 1.5
                )
                cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
            }
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

            if let route = calculatedRoute {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.turn.up.right")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(DriverTheme.accent, in: Circle())
                    
                    VStack(alignment: .leading) {
                        Text("\(String(format: "%.1f", route.distance / 1000)) km")
                            .font(.system(.headline, design: .rounded).bold())
                        Text("\(Int(route.expectedTravelTime / 60)) min")
                            .font(.caption.bold())
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial, in: Capsule())
                .shadow(radius: 5)
            }
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

            if let route = calculatedRoute {
                let minutes = Int(route.expectedTravelTime / 60)
                let hours = minutes / 60
                let remainingMins = minutes % 60
                Text(hours > 0 ? "\(hours)h \(remainingMins)m" : "\(remainingMins)m")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(DriverTheme.textPrimary)
                    .contentTransition(.numericText())
            } else {
                Text("--:--")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(DriverTheme.textSecondary)
            }

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
            // Native Apple Maps Navigation
            Button {
                launchAppleMapsNavigation()
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

    // MARK: - Launch Apple Maps with Optimized Route
    private func launchAppleMapsNavigation() {
        let startItem = MKMapItem(location: CLLocation(latitude: originCoordinate.latitude, longitude: originCoordinate.longitude), address: nil as MKAddress?)
        let endItem = MKMapItem(location: CLLocation(latitude: destinationCoordinate.latitude, longitude: destinationCoordinate.longitude), address: nil as MKAddress?)

        startItem.name = trip.origin
        endItem.name = trip.destination

        let launchOptions: [String: Any] = [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ]

        // Pass both startItem and endItem to suggest the optimized route of the trip
        MKMapItem.openMaps(with: [startItem, endItem], launchOptions: launchOptions)
    }
}

#Preview {
    DriverTripTabView()
        .environment(AppViewModel())
        .environment(DriverViewModel())
}
