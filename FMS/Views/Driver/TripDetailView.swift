import SwiftUI
import MapKit

struct TripDetailView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(DriverViewModel.self) private var driverVM
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
    private var isOnDuty: Bool {
        guard let user = currentUser else { return false }
        return appViewModel.service.dutyStatus(for: user.id) == .onDuty
    }

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var sheetHeight: PresentationDetent = .medium
    @State private var showPreTripInspectionSheet = false
    @State private var showPostTripInspectionSheet = false
    @State private var showBreakLogSheet = false

    @State private var routePlan: TripRoutePlan?
    @State private var isLoadingRoute: Bool = false

    private var originCoordinate: CLLocationCoordinate2D? { trip.originCoordinate }
    private var destinationCoordinate: CLLocationCoordinate2D? { trip.destinationCoordinate }

    private var assignedVehicle: Vehicle? {
        appViewModel.service.vehicles.first { $0.id == trip.vehicleID }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                if let routePlan {
                    TripRoutesMapContent(plan: routePlan)
                } else if let originCoordinate, let destinationCoordinate {
                    MapPolyline(coordinates: [originCoordinate, destinationCoordinate])
                        .stroke(DriverTheme.accent.opacity(0.8), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                }

                if trip.status == .inProgress,
                   let originCoordinate,
                   let vehicle = assignedVehicle {
                    let midIndex = (routePlan?.mainRouteCoordinates.count ?? 2) / 3
                    let fallbackCoords = [originCoordinate, destinationCoordinate].compactMap { $0 }
                    let coords = routePlan?.mainRouteCoordinates ?? fallbackCoords
                    let currentCoord = coords[min(midIndex, max(coords.count - 1, 0))]
                    Annotation("Current", coordinate: currentCoord) {
                        ZStack {
                            Circle()
                                .fill(DriverTheme.accent.opacity(0.3))
                                .frame(width: 60, height: 60)
                                .symbolEffect(.pulse, options: .repeating)

                            VehicleMapMarker(
                                symbolName: vehicle.fleetMapSymbolName,
                                tint: DriverTheme.accent,
                                isMoving: true,
                                size: 24
                            )
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
        .overlay(alignment: .top) {
            if routePlan != nil {
                TripRouteLegendView()
                    .padding(.top, 8)
            }
        }
        .task {
            await loadRoutePlan()
        }
        .sheet(isPresented: .constant(true)) {
            sheetOverlaySection
                .presentationDetents([.height(300), .medium, .large], selection: $sheetHeight)
                .presentationBackgroundInteraction(.enabled)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(40)
                .interactiveDismissDisabled()
                .sheet(isPresented: $showPreTripInspectionSheet) {
                    TripStartInspectionSheet(trip: trip) {
                        driverVM.showToastMessage("Trip started. Have a safe journey.")
                    }
                    .environment(appViewModel)
                    .environment(driverVM)
                }
                .sheet(isPresented: $showPostTripInspectionSheet) {
                    TripStartInspectionSheet(trip: trip, inspectionType: .postTrip) {
                        dismiss()
                    }
                    .environment(appViewModel)
                    .environment(driverVM)
                }
                .sheet(isPresented: $showBreakLogSheet) {
                    TripBreakLogSheet(trip: trip)
                        .environment(appViewModel)
                }
        }
    }

    private func loadRoutePlan() async {
        guard originCoordinate != nil, destinationCoordinate != nil else {
            cameraPosition = .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 22.5, longitude: 79.0),
                span: MKCoordinateSpan(latitudeDelta: 8.0, longitudeDelta: 8.0)
            ))
            return
        }

        isLoadingRoute = true
        let plan = await appViewModel.service.tripRoutePlan(for: trip)
        routePlan = plan
        withAnimation(.easeInOut(duration: 0.6)) {
            if let plan {
                cameraPosition = TripRouteMapCamera.position(for: plan)
            } else if let origin = originCoordinate, let dest = destinationCoordinate {
                cameraPosition = .region(FleetMapRegion.region(for: [origin, dest]))
            }
        }
        isLoadingRoute = false
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
            metricItem(
                title: "Distance",
                value: (routePlan?.mainDistanceKM ?? 0) > 0
                    ? "\(Int(routePlan?.mainDistanceKM ?? trip.distanceKM)) km"
                    : "\(Int(trip.distanceKM)) km"
            )
            Divider().frame(height: 30)
            metricItem(
                title: "ETA",
                value: (routePlan?.mainETAMinutes ?? 0) > 0
                    ? formatETA(routePlan?.mainETAMinutes ?? 0)
                    : "--"
            )
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
            }
            .buttonStyle(.borderedProminent)
            .tint(DriverTheme.accent)
            .buttonBorderShape(.circle)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    // MARK: - Action Button Section
    @ViewBuilder
    private var actionButtonSection: some View {
        if trip.status == .scheduled {
            Button {
                if isOnDuty {
                    showPreTripInspectionSheet = true
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill")
                    Text("Start Trip")
                        .font(.system(.headline, design: .rounded).bold())
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isOnDuty ? DriverTheme.accent : Color.gray.opacity(0.5))
            .controlSize(.large)
            .buttonBorderShape(.capsule)
            .disabled(!isOnDuty)
        } else if trip.status == .inProgress {
            Button {
                showBreakLogSheet = true
            } label: {
                Text("Log Break")
                    .font(.system(.headline, design: .rounded).bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(DriverTheme.accent)
            .controlSize(.large)
            .buttonBorderShape(.capsule)
            
            Button {
                showPostTripInspectionSheet = true
            } label: {
                Text("End Trip")
                    .font(.system(.headline, design: .rounded).bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(DriverTheme.criticalRed)
            .controlSize(.large)
            .buttonBorderShape(.capsule)
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
        .environment(DriverViewModel())
    }
}
