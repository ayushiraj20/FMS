import SwiftUI
import MapKit

struct TripDetailView: View {
    @Environment(AppViewModel.self) private var appViewModel
    let trip: Trip

    private var checkpoints: [TripCheckpoint] {
        appViewModel.service.checkpoints(for: trip.id)
    }

    private var vehicle: Vehicle? {
        appViewModel.service.vehicle(for: trip.vehicleID)
    }

    private var driver: User? {
        appViewModel.service.user(for: trip.driverID)
    }

    // Demo coordinates
    private let routeCoordinates: [CLLocationCoordinate2D] = [
        CLLocationCoordinate2D(latitude: 19.0760, longitude: 72.8777),
        CLLocationCoordinate2D(latitude: 19.0330, longitude: 73.0297),
        CLLocationCoordinate2D(latitude: 18.7557, longitude: 73.4091),
        CLLocationCoordinate2D(latitude: 18.5204, longitude: 73.8567)
    ]

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                mapSection
                detailSection
            }
        }
        .background(DriverTheme.background.ignoresSafeArea())
        .navigationTitle("Trip Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
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

            Annotation("", coordinate: routeCoordinates.first ?? routeCoordinates[0]) {
                Circle()
                    .fill(DriverTheme.successGreen)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
            }

            Annotation("", coordinate: routeCoordinates.last ?? routeCoordinates[0]) {
                Circle()
                    .fill(DriverTheme.criticalRed)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
            }

            if trip.status == .inProgress {
                Annotation("", coordinate: CLLocationCoordinate2D(latitude: 18.9, longitude: 73.25)) {
                    Image(systemName: "truck.box.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(Circle().fill(DriverTheme.accent))
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                }
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 0))
    }

    // MARK: - Detail Section

    private var detailSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Trip header
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Trip")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DriverTheme.accent)
                    Text("\(trip.origin) → \(trip.destination)")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(DriverTheme.textPrimary)
                }

                Spacer()

                StatusBadge(
                    title: trip.status.rawValue,
                    color: statusColor(for: trip.status),
                    icon: "circle.fill"
                )
            }

            // Completion progress
            if trip.status == .inProgress {
                let completedCheckpoints = checkpoints.filter { $0.status == .completed }.count
                let totalCheckpoints = max(checkpoints.count, 1)
                let progress = Double(completedCheckpoints) / Double(totalCheckpoints)

                HStack(spacing: 16) {
                    ZStack {
                        CircularProgressRing(
                            progress: progress,
                            size: 80,
                            strokeWidth: 8
                        )
                        Text("\(Int(progress * 100))%")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(DriverTheme.textPrimary)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trip Progress")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DriverTheme.textPrimary)
                        Text("\(completedCheckpoints)/\(totalCheckpoints) checkpoints")
                            .font(.system(size: 13))
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                }
            }

            // Stats row
            statsRow

            // Checkpoint Timeline
            if !checkpoints.isEmpty {
                checkpointTimeline
            }

            // Driver contact
            if let driver = driver {
                DriverGlassCard {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(DriverTheme.accent)
                                .frame(width: 44, height: 44)
                            let initials = driver.name.components(separatedBy: " ").prefix(2).compactMap { $0.first }.map(String.init).joined()
                            Text(initials)
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(driver.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(DriverTheme.textPrimary)
                            Text(driver.phone)
                                .font(.system(size: 13))
                                .foregroundStyle(DriverTheme.textSecondary)
                        }

                        Spacer()

                        Button {
                            guard let url = URL(string: "tel://\(driver.phone.replacingOccurrences(of: " ", with: ""))") else { return }
                            UIApplication.shared.open(url)
                        } label: {
                            Image(systemName: "phone.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(DriverTheme.accent)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(DriverTheme.cardFill)
                                )
                        }
                    }
                }
            }
        }
        .padding(20)
    }

    // MARK: - Stats

    private var statsRow: some View {
        HStack(spacing: 0) {
            statItem(icon: "road.lanes", label: "Distance", value: "\(Int(trip.distanceKM)) km")
            
            Rectangle()
                .fill(DriverTheme.separator)
                .frame(width: 1, height: 40)

            statItem(icon: "clock.fill", label: "ETA", value: "2:15 PM")

            Rectangle()
                .fill(DriverTheme.separator)
                .frame(width: 1, height: 40)

            statItem(icon: "speedometer", label: "Avg Speed", value: "68 km/h")
        }
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DriverTheme.elevatedCard)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(DriverTheme.cardBorder, lineWidth: 0.5)
                )
                .shadow(color: DriverTheme.cardShadow, radius: 8, x: 0, y: 2)
        )
    }

    private func statItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(DriverTheme.accent)
            Text(value)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(DriverTheme.textPrimary)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(DriverTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Checkpoint Timeline

    private var checkpointTimeline: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Checkpoints")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DriverTheme.textPrimary)
                .padding(.bottom, 12)

            ForEach(Array(checkpoints.enumerated()), id: \.element.id) { index, checkpoint in
                HStack(alignment: .top, spacing: 16) {
                    // Timeline column
                    VStack(spacing: 0) {
                        // Dot
                        Circle()
                            .fill(checkpointDotColor(checkpoint.status))
                            .frame(width: 12, height: 12)

                        // Line
                        if index < checkpoints.count - 1 {
                            Rectangle()
                                .fill(checkpoint.status == .completed ? DriverTheme.accent : DriverTheme.separator)
                                .frame(width: 2)
                                .frame(height: 50)
                        }
                    }

                    // Content
                    VStack(alignment: .leading, spacing: 4) {
                        Text(checkpoint.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DriverTheme.textPrimary)

                        if let arrival = checkpoint.arrivalTime {
                            Text("Arrived: \(arrival.formatted(date: .omitted, time: .shortened))")
                                .font(.system(size: 13))
                                .foregroundStyle(DriverTheme.textSecondary)
                        }

                        StatusBadge(
                            title: checkpoint.status.rawValue,
                            color: checkpointStatusColor(checkpoint.status),
                            icon: checkpointStatusIcon(checkpoint.status)
                        )
                    }
                    .padding(.bottom, index < checkpoints.count - 1 ? 20 : 0)

                    Spacer()
                }
            }
        }
    }

    // MARK: - Helpers

    private func statusColor(for status: TripStatus) -> Color {
        switch status {
        case .scheduled: return .gray
        case .inProgress: return DriverTheme.accent
        case .completed: return DriverTheme.successGreen
        case .cancelled: return DriverTheme.criticalRed
        }
    }

    private func checkpointDotColor(_ status: CheckpointStatus) -> Color {
        switch status {
        case .completed: return DriverTheme.successGreen
        case .inTransit: return DriverTheme.accent
        case .upcoming: return DriverTheme.separator
        }
    }

    private func checkpointStatusColor(_ status: CheckpointStatus) -> Color {
        switch status {
        case .completed: return DriverTheme.successGreen
        case .inTransit: return DriverTheme.accent
        case .upcoming: return .gray
        }
    }

    private func checkpointStatusIcon(_ status: CheckpointStatus) -> String {
        switch status {
        case .completed: return "checkmark.circle.fill"
        case .inTransit: return "truck.box.fill"
        case .upcoming: return "circle"
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
