import SwiftUI
import MapKit

struct TripDetailView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss
    private let initialTrip: Trip

    private var trip: Trip {
        appViewModel.service.trips.first(where: { $0.id == initialTrip.id }) ?? initialTrip
    }

    init(trip: Trip) {
        self.initialTrip = trip
    }

    private var currentUser: User? { appViewModel.currentUser }
    private var checkpoints: [TripCheckpoint] { appViewModel.service.checkpoints(for: trip.id) }
    private var driver: User? { appViewModel.service.user(for: trip.driverID) }

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var sheetHeight: PresentationDetent = .medium
    @State private var showPostTripInspectionSheet = false
    @State private var showBreakLogSheet = false

    // Real route data
    @State private var routeCoordinates: [CLLocationCoordinate2D] = []
    @State private var routeDistanceKM: Double = 0
    @State private var routeETAMinutes: Double = 0
    @State private var isLoadingRoute: Bool = false

    // Computed origin/destination coordinates
    private var originCoordinate: CLLocationCoordinate2D? {
        guard let lat = trip.originLat, let lng = trip.originLng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
    private var destinationCoordinate: CLLocationCoordinate2D? {
        guard let lat = trip.destinationLat, let lng = trip.destinationLng else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                // Route polyline
                if !routeCoordinates.isEmpty {
                    MapPolyline(coordinates: routeCoordinates)
                        .stroke(DriverTheme.accent.opacity(0.8), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                }

                // Origin marker
                if let coord = originCoordinate {
                    Annotation(trip.origin, coordinate: coord) {
                        Circle()
                            .fill(DriverTheme.successGreen)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                            .shadow(radius: 4)
                    }
                }

                // Destination marker
                if let coord = destinationCoordinate {
                    Annotation(trip.destination, coordinate: coord) {
                        Circle()
                            .fill(DriverTheme.criticalRed)
                            .frame(width: 16, height: 16)
                            .overlay(Circle().stroke(.white, lineWidth: 3))
                            .shadow(radius: 4)
                    }
                }

                // Current position marker (when in progress)
                if trip.status == .inProgress, !routeCoordinates.isEmpty {
                    let midIndex = routeCoordinates.count / 3
                    let currentCoord = routeCoordinates[min(midIndex, routeCoordinates.count - 1)]
                    Annotation("Current", coordinate: currentCoord) {
                        ZStack {
                            Circle()
                                .fill(DriverTheme.accent.opacity(0.3))
                                .frame(width: 60, height: 60)
                                .symbolEffect(.pulse, options: .repeating)
                            
                            Image(systemName: "box.truck.fill")
                                .font(.title2)
                                .foregroundStyle(.white)
                                .padding(12)
                                .background(DriverTheme.accent, in: Circle())
                                .overlay(Circle().stroke(.white, lineWidth: 3))
                                .shadow(radius: 6)
                        }
                    }
                }
            }
            .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
            .ignoresSafeArea()
            .frame(maxHeight: .infinity)
        }
        .navigationTitle("Trip \(String(trip.id.uuidString.prefix(4)).uppercased())")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        .onAppear {
            loadRoute()
        }
        .sheet(isPresented: .constant(true)) {
            sheetOverlaySection
                .presentationDetents([.height(300), .medium, .large], selection: $sheetHeight)
                .presentationBackgroundInteraction(.enabled)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(40)
                .interactiveDismissDisabled()
                .sheet(isPresented: $showPostTripInspectionSheet) {
                    TripEndInspectionSheet(trip: trip) {
                        dismiss()
                    }
                    .environment(appViewModel)
                }
                .sheet(isPresented: $showBreakLogSheet) {
                    TripBreakLogSheet(trip: trip)
                        .environment(appViewModel)
                }
        }
    }

    // MARK: - Load Route
    private func loadRoute() {
        guard let origin = originCoordinate, let dest = destinationCoordinate else {
            // Fallback: if no coordinates, just center on India
            cameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 22.5, longitude: 79.0),
                span: MKCoordinateSpan(latitudeDelta: 8.0, longitudeDelta: 8.0)
            ))
            return
        }

        isLoadingRoute = true
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
                print("[TripDetail] Route calculation failed: \(error.localizedDescription)")
            }

            // Fit camera to show the route
            let midLat = (origin.latitude + dest.latitude) / 2
            let midLng = (origin.longitude + dest.longitude) / 2
            let latDelta = abs(origin.latitude - dest.latitude) * 1.6 + 0.05
            let lngDelta = abs(origin.longitude - dest.longitude) * 1.6 + 0.05
            withAnimation(.easeInOut(duration: 0.6)) {
                cameraPosition = .region(MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: midLat, longitude: midLng),
                    span: MKCoordinateSpan(latitudeDelta: max(latDelta, 0.1), longitudeDelta: max(lngDelta, 0.1))
                ))
            }
            isLoadingRoute = false
        }
    }

    // MARK: - Format ETA
    private func formatETA(_ minutes: Double) -> String {
        let total = Int(minutes)
        if total < 60 { return "\(total) min" }
        let h = total / 60, m = total % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    // MARK: - Sheet Overlay Section
    private var sheetOverlaySection: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // Header & Progress Ring
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(trip.origin) → \(trip.destination)")
                            .font(.system(.title2, design: .rounded).bold())
                        Text("Trip #\(String(trip.id.uuidString.prefix(8)).uppercased())")
                            .font(.caption)
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    let completed = checkpoints.filter { $0.status == .completed }.count
                    let total = max(checkpoints.count, 1)
                    let progress = trip.status == .completed ? 1.0 : (trip.status == .inProgress ? Double(completed) / Double(total) : 0.0)
                    
                    ZStack {
                        CircularProgressRing(progress: progress, size: 70, strokeWidth: 8)
                        Text("\(Int(progress * 100))%")
                            .font(.system(.subheadline, design: .rounded).bold())
                    }
                }
                .padding(.top, 24)

                // Metrics Bar
                metricsBarSection

                // Timeline
                checkpointTimelineSection

                // Driver card
                if let driver = driver {
                    driverContactCard(driver: driver)
                }

                // Actions
                actionButtonSection
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Metrics Bar
    private var metricsBarSection: some View {
        HStack {
            metricItem(title: "Distance", value: routeDistanceKM > 0 ? "\(Int(routeDistanceKM)) km" : "\(Int(trip.distanceKM)) km")
            Divider().frame(height: 30)
            metricItem(title: "ETA", value: routeETAMinutes > 0 ? formatETA(routeETAMinutes) : "--")
            Divider().frame(height: 30)
            metricItem(title: "Status", value: trip.status.rawValue)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }
    
    private func metricItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(DriverTheme.textSecondary)
            Text(value).font(.system(.headline, design: .rounded).bold())
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Timeline Section
    private var checkpointTimelineSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Route Progress")
                .font(.system(.title3, design: .rounded).bold())
                .padding(.bottom, 16)
            
            ForEach(Array(checkpoints.enumerated()), id: \.element.id) { index, checkpoint in
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 0) {
                        if checkpoint.status == .completed {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white, DriverTheme.accent)
                        } else if checkpoint.status == .inTransit {
                            Image(systemName: "circle.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.white, DriverTheme.accent)
                                .symbolEffect(.pulse)
                        } else {
                            Circle().stroke(DriverTheme.textSecondary, lineWidth: 2).frame(width: 20, height: 20)
                        }

                        if index < checkpoints.count - 1 {
                            Rectangle()
                                .fill(checkpoint.status == .completed ? DriverTheme.accent : DriverTheme.textSecondary.opacity(0.3))
                                .frame(width: 2, height: 40)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(checkpoint.name)
                            .font(.system(.headline, design: .rounded))
                            .foregroundStyle(checkpoint.status == .upcoming ? DriverTheme.textSecondary : DriverTheme.textPrimary)
                        
                        if checkpoint.status == .completed, let dep = checkpoint.departureTime {
                            Text(dep.formatted(date: .omitted, time: .shortened))
                                .font(.caption).foregroundStyle(DriverTheme.textSecondary)
                        } else if checkpoint.status == .inTransit {
                            Text("In Transit").font(.caption.bold()).foregroundStyle(DriverTheme.accent)
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Driver Card
    private func driverContactCard(driver: User) -> some View {
        HStack(spacing: 16) {
            Image(systemName: "person.circle.fill")
                .font(.system(size: 40))
                .foregroundStyle(DriverTheme.accent)
            
            VStack(alignment: .leading) {
                Text(driver.name).font(.system(.headline, design: .rounded))
                HStack(spacing: 2) {
                    ForEach(0..<5) { _ in Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow) }
                }
            }
            Spacer()
            
            Button {
                if let url = URL(string: "tel://\(driver.phone.replacingOccurrences(of: " ", with: ""))") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Image(systemName: "phone.fill")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(DriverTheme.accent, in: Circle())
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Action Button Section
    @ViewBuilder
    private var actionButtonSection: some View {
        if trip.status == .scheduled {
            let inspDone = currentUser.flatMap { appViewModel.service.todayInspection(for: $0.id) } != nil
            
            Button {
                if inspDone { appViewModel.service.startScheduledTrip(id: trip.id) }
            } label: {
                Text(inspDone ? "Start Trip" : "Complete Inspection First")
                    .font(.system(.headline, design: .rounded).bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(inspDone ? DriverTheme.accent : Color.gray, in: Capsule())
            }
            .disabled(!inspDone)
        } else if trip.status == .inProgress {
            Button {
                showBreakLogSheet = true
            } label: {
                Text("Log Break")
                    .font(.system(.headline, design: .rounded).bold())
                    .foregroundStyle(DriverTheme.accent)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(DriverTheme.accent.opacity(0.15), in: Capsule())
            }
            
            Button {
                showPostTripInspectionSheet = true
            } label: {
                Text("End Trip")
                    .font(.system(.headline, design: .rounded).bold())
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(DriverTheme.criticalRed, in: Capsule())
            }
        }
    }
}

#Preview {
    NavigationStack {
        TripDetailView(trip: Trip(
            id: UUID(), driverID: UUID(), vehicleID: UUID(),
            origin: "Mumbai", destination: "Pune",
            startDate: .now, endDate: nil, distanceKM: 148, status: .inProgress
        ))
        .environment(AppViewModel())
    }
}
