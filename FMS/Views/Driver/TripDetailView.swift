import SwiftUI
import MapKit

struct TripDetailView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss
    let trip: Trip

    private var currentUser: User? { appViewModel.currentUser }
    private var checkpoints: [TripCheckpoint] { appViewModel.service.checkpoints(for: trip.id) }
    private var driver: User? { appViewModel.service.user(for: trip.driverID) }

    private let routeCoordinates: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 19.0760, longitude: 72.8777), // Mumbai
        CLLocationCoordinate2D(latitude: 19.0330, longitude: 73.0297), // Panvel
        CLLocationCoordinate2D(latitude: 18.7557, longitude: 73.4091), // Lonavala
        CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567)  // Pune
    ]

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var sheetHeight: PresentationDetent = .medium
    @State private var showPostTripInspectionSheet = false
    @State private var showBreakLogSheet = false

    var body: some View {
        ZStack(alignment: .bottom) {
            Map(position: $cameraPosition) {
                MapPolyline(coordinates: routeCoordinates)
                    .stroke(DriverTheme.accent.opacity(0.8), style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))

                Annotation("Start", coordinate: routeCoordinates.first ?? routeCoordinates[0]) {
                    Circle()
                        .fill(DriverTheme.successGreen)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .shadow(radius: 4)
                }

                Annotation("End", coordinate: routeCoordinates.last ?? routeCoordinates[0]) {
                    Circle()
                        .fill(DriverTheme.criticalRed)
                        .frame(width: 16, height: 16)
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .shadow(radius: 4)
                }

                if trip.status == .inProgress {
                    Annotation("Current", coordinate: CLLocationCoordinate2D(latitude: 18.9, longitude: 73.25)) {
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
            let center = CLLocationCoordinate2D(latitude: 18.8, longitude: 73.15)
            cameraPosition = .region(MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)))
        }
        .sheet(isPresented: .constant(true)) {
            sheetOverlaySection
                .presentationDetents([.height(300), .medium, .large], selection: $sheetHeight)
                .presentationBackgroundInteraction(.enabled)
                .presentationBackground(.ultraThinMaterial)
                .presentationCornerRadius(40)
                .interactiveDismissDisabled()
                .sheet(isPresented: $showPostTripInspectionSheet) {
                    TripStartInspectionSheet(trip: trip, inspectionType: .postTrip) {
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
            metricItem(title: "Distance", value: "\(Int(trip.distanceKM))km")
            Divider().frame(height: 30)
            metricItem(title: "ETA", value: "2:15 PM")
            Divider().frame(height: 30)
            metricItem(title: "Speed", value: "72 km/h")
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
