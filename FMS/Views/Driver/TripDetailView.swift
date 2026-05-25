import SwiftUI
import MapKit

struct TripDetailView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let trip: Trip

    private var currentUser: User? { appViewModel.currentUser }

    private var checkpoints: [TripCheckpoint] {
        appViewModel.service.checkpoints(for: trip.id)
    }

    private var vehicle: Vehicle? {
        appViewModel.service.vehicle(for: trip.vehicleID)
    }

    private var driver: User? {
        appViewModel.service.user(for: trip.driverID)
    }

    // Coordinates mapping Mumbai to Pune
    private let routeCoordinates: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 19.0760, longitude: 72.8777), // Mumbai
        CLLocationCoordinate2D(latitude: 19.0330, longitude: 73.0297), // Panvel
        CLLocationCoordinate2D(latitude: 18.7557, longitude: 73.4091), // Lonavala
        CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567)  // Pune
    ]

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        ZStack(alignment: .bottom) {
            // 1. Map Background taking full screen
            mapSection
                .ignoresSafeArea(edges: .top)

            // 2. Sliding sheet overlay
            sheetOverlaySection
        }
        .background(DriverTheme.background.ignoresSafeArea())
        .navigationTitle("Trip Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Settings or gear option
                }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(DriverTheme.textPrimary)
                }
            }
        }
        .onAppear {
            let center = CLLocationCoordinate2D(latitude: 18.8, longitude: 73.15)
            cameraPosition = .region(MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
            ))
        }
    }

    // MARK: - Map Section

    private var mapSection: some View {
        Map(position: $cameraPosition) {
            MapPolyline(coordinates: routeCoordinates)
                .stroke(DriverTheme.accent, lineWidth: 5)

            // Start Location Dot
            Annotation("", coordinate: routeCoordinates.first ?? routeCoordinates[0]) {
                Circle()
                    .fill(DriverTheme.successGreen)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
            }

            // End Location Dot
            Annotation("", coordinate: routeCoordinates.last ?? routeCoordinates[0]) {
                Circle()
                    .fill(DriverTheme.criticalRed)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
            }

            // Real-time Vehicle position along the route (near Lonavala if in progress)
            if trip.status == .inProgress {
                Annotation("", coordinate: CLLocationCoordinate2D(latitude: 18.9, longitude: 73.25)) {
                    Image(systemName: "truck.box.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Circle().fill(DriverTheme.accent))
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .shadow(color: .black.opacity(0.3), radius: 3)
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .frame(maxHeight: .infinity)
    }

    // MARK: - Sheet Overlay Section

    private var sheetOverlaySection: some View {
        VStack(spacing: 0) {
            // Drag handle
            Capsule()
                .fill(Color(UIColor { t in t.userInterfaceStyle == .dark ? UIColor.white.withAlphaComponent(0.20) : UIColor.black.withAlphaComponent(0.15) }))
                .frame(width: 40, height: 5)
                .padding(.vertical, 10)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    // Header & Progress Ring
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Trip #\(String(trip.id.uuidString.prefix(4)).uppercased())")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(DriverTheme.textPrimary)
                            Text("\(trip.origin) → \(trip.destination)")
                                .font(.system(size: 15))
                                .foregroundStyle(DriverTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        let completedCheckpoints = checkpoints.filter { $0.status == .completed }.count
                        let totalCheckpoints = max(checkpoints.count, 1)
                        let displayProgress = trip.status == .completed ? 1.0 : (trip.status == .inProgress ? Double(completedCheckpoints) / Double(totalCheckpoints) : 0.0)
                        
                        ZStack {
                            Circle()
                                .stroke(DriverTheme.cardBorder, lineWidth: 8)
                                .frame(width: 70, height: 70)
                            
                            Circle()
                                .trim(from: 0, to: CGFloat(displayProgress))
                                .stroke(
                                    DriverTheme.accentGradient,
                                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))
                                .frame(width: 70, height: 70)
                            
                            Text("\(Int(displayProgress * 100))%")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(DriverTheme.textPrimary)
                        }
                    }
                    .padding(.top, 5)

                    // 2. Checkpoints Timeline
                    checkpointTimelineSection

                    // 3. Driver card
                    if let driver = driver {
                        driverContactCard(driver: driver)
                    }

                    // 4. Metrics Bar
                    metricsBarSection

                    // 5. Actions
                    actionButtonSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .frame(height: 520)
        .background(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(DriverTheme.background.opacity(0.97))
                .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: -8)
        )
    }

    // MARK: - Checkpoints Timeline Section

    private var checkpointTimelineSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(checkpoints.enumerated()), id: \.element.id) { index, checkpoint in
                HStack(alignment: .top, spacing: 16) {
                    VStack(spacing: 0) {
                        // Check Circle
                        if checkpoint.status == .completed {
                            ZStack {
                                Circle()
                                    .fill(DriverTheme.accent)
                                    .frame(width: 22, height: 22)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        } else if checkpoint.status == .inTransit {
                            ZStack {
                                Circle()
                                    .fill(DriverTheme.accent.opacity(0.25))
                                    .frame(width: 22, height: 22)
                                Circle()
                                    .fill(DriverTheme.accent)
                                    .frame(width: 12, height: 12)
                            }
                        } else {
                            Circle()
                                .stroke(DriverTheme.separator, lineWidth: 2)
                                .frame(width: 22, height: 22)
                        }

                        // Connecting vertical line
                        if index < checkpoints.count - 1 {
                            Rectangle()
                                .fill(checkpoint.status == .completed ? DriverTheme.accent : DriverTheme.cardBorder)
                                .frame(width: 2)
                                .frame(height: 38)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(checkpoint.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(checkpoint.status == .upcoming ? DriverTheme.textSecondary : DriverTheme.textPrimary)
                        
                        if checkpoint.status == .completed, let departure = checkpoint.departureTime {
                            Text(departure.formatted(date: .omitted, time: .shortened))
                                .font(.system(size: 12))
                                .foregroundStyle(DriverTheme.textSecondary)
                        } else if checkpoint.status == .inTransit {
                            Text("In Transit")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(DriverTheme.accent)
                        }
                    }
                    Spacer()
                }
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Driver Contact Card

    private func driverContactCard(driver: User) -> some View {
        HStack(spacing: 12) {
            // Driver Profile Photo or Initials Icon
            ZStack {
                if driver.name.contains("Rajesh") {
                    Image("driver_profile")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 50, height: 50)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(DriverTheme.accent.opacity(0.15))
                        .frame(width: 50, height: 50)
                    let initials = driver.name.components(separatedBy: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
                    Text(initials)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(DriverTheme.accent)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(driver.name)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(DriverTheme.textPrimary)
                
                // 5 stars rating
                HStack(spacing: 3) {
                    ForEach(0..<5) { _ in
                        Image(systemName: "star.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(.yellow)
                    }
                }
            }
            
            Spacer()
            
            // Phone call button
            Button {
                guard let url = URL(string: "tel://\(driver.phone.replacingOccurrences(of: " ", with: ""))") else { return }
                UIApplication.shared.open(url)
            } label: {
                Image(systemName: "phone.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(DriverTheme.glassWhite))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(DriverTheme.cardFill))
    }

    // MARK: - Metrics Bar Section

    private var metricsBarSection: some View {
        HStack(spacing: 0) {
            VStack(spacing: 4) {
                Text("Distance")
                    .font(.system(size: 12))
                    .foregroundStyle(DriverTheme.textSecondary)
                Text("\(Int(trip.distanceKM))km")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DriverTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            
            Rectangle()
                .fill(DriverTheme.separator)
                .frame(width: 1, height: 30)
            
            VStack(spacing: 4) {
                Text("ETA")
                    .font(.system(size: 12))
                    .foregroundStyle(DriverTheme.textSecondary)
                Text("2:15 PM")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DriverTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
            
            Rectangle()
                .fill(DriverTheme.separator)
                .frame(width: 1, height: 30)
            
            VStack(spacing: 4) {
                Text("Speed")
                    .font(.system(size: 12))
                    .foregroundStyle(DriverTheme.textSecondary)
                Text("72 km/h")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(DriverTheme.textPrimary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DriverTheme.cardFill.opacity(0.6)))
    }

    // MARK: - Action Button Section

    @ViewBuilder
    private var actionButtonSection: some View {
        if trip.status == .scheduled {
            let inspectionDone = currentUser.flatMap { appViewModel.service.todayInspection(for: $0.id) } != nil
            
            Button {
                if inspectionDone {
                    appViewModel.service.startScheduledTrip(id: trip.id)
                }
            } label: {
                Text(inspectionDone ? "Start Trip" : "Complete Inspection First")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Capsule().fill(inspectionDone ? DriverTheme.accent : Color.gray))
            }
            .disabled(!inspectionDone)
        } else if trip.status == .inProgress {
            Button {
                appViewModel.service.endTrip(trip)
                dismiss()
            } label: {
                Text("End Trip")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Capsule().fill(DriverTheme.criticalRed))
            }
        }
    }
}

#Preview {
    NavigationStack {
        TripDetailView(trip: Trip(
            id: UUID(),
            driverID: UUID(),
            vehicleID: UUID(),
            origin: "Mumbai",
            destination: "Pune",
            startDate: .now,
            endDate: nil,
            distanceKM: 148,
            status: .inProgress
        ))
        .environment(AppViewModel())
    }
}
