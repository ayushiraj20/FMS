import SwiftUI
import MapKit

// Force indexing refresh
struct DriverSafetyView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel
    @EnvironmentObject private var driverVM: DriverViewModel

    private var currentUser: User? { appViewModel.currentUser }

    // Recent events sample data
    private struct SafetyEvent: Identifiable {
        let id = UUID()
        let title: String
        let time: String
        let location: String
        let severity: String // "Low", "Medium", "High"
        let coordinate: CLLocationCoordinate2D
    }

    private let recentEvents = [
        SafetyEvent(title: "Harsh Braking", time: "2:15 PM", location: "Industrial Area", severity: "Low", coordinate: CLLocationCoordinate2D(latitude: 19.0330, longitude: 73.0297)),
        SafetyEvent(title: "Rapid Acceleration", time: "11:30 AM", location: "Main Street", severity: "Medium", coordinate: CLLocationCoordinate2D(latitude: 18.7557, longitude: 73.4091))
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                // Driving Score Ring
                drivingScoreSection

                // Fatigue & Hours grid
                fatigueAndHoursGrid

                // Crash Detection Status card
                crashDetectionStatusCard

                // Recent Events section
                recentEventsSection

                // Sparkline speed chart
                sparklineSpeedChart

                // Driving Tips card
                drivingTipsCard

                // Trip History Done by Driver
                tripHistoryDoneByDriver

                // Quick SOS Button
                quickSOSButton
            }
            .padding(20)
        }
        .background(DriverTheme.background.ignoresSafeArea())
        .navigationTitle("Safety")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    // Placeholder for safety alerts notification trigger
                }) {
                    Image(systemName: "bell")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(DriverTheme.textPrimary)
                }
            }
        }
    }

    // MARK: - Driving Score Gauge Section

    private var drivingScoreSection: some View {
        VStack(spacing: 12) {
            ZStack {
                // Background Track
                Circle()
                    .trim(from: 0.15, to: 0.85)
                    .stroke(Color.white.opacity(0.08), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(90))

                // Active Track
                Circle()
                    .trim(from: 0.15, to: 0.15 + 0.7 * (92.0 / 100.0))
                    .stroke(
                        LinearGradient(
                            colors: [DriverTheme.accent, Color(hex: "FF3B30")],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .frame(width: 180, height: 180)
                    .rotationEffect(.degrees(90))

                VStack(spacing: 0) {
                    Text("92")
                        .font(.system(size: 54, weight: .bold))
                        .foregroundStyle(.white)
                    Text("of 100")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(DriverTheme.textSecondary)
                }
            }
            .frame(height: 140)

            Text("Driving Score")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(DriverTheme.textSecondary)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Fatigue & Hours Grid

    private var fatigueAndHoursGrid: some View {
        HStack(spacing: 12) {
            // Fatigue Level
            VStack(alignment: .leading, spacing: 10) {
                Text("Fatigue Level: Low")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(DriverTheme.textSecondary)
                
                // Block progress bar
                HStack(spacing: 4) {
                    ForEach(0..<8, id: \.self) { idx in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(idx < 2 ? DriverTheme.successGreen : Color.white.opacity(0.1))
                            .frame(width: 6, height: 12)
                    }
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DriverTheme.cardFill))

            // Hours Driven
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hours driven:")
                        .font(.system(size: 12))
                        .foregroundStyle(DriverTheme.textSecondary)
                    Text("4.5h")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(DriverTheme.textPrimary)
                }
                Spacer()
                Image(systemName: "clock.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(DriverTheme.accent.opacity(0.6))
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DriverTheme.cardFill))
        }
    }

    // MARK: - Crash Detection Status Card

    private var crashDetectionStatusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(DriverTheme.successGreen)

            VStack(alignment: .leading, spacing: 2) {
                Text("Crash Detection Status")
                    .font(.system(size: 13))
                    .foregroundStyle(DriverTheme.textSecondary)
                Text("• Active")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(DriverTheme.successGreen)
            }
            Spacer()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DriverTheme.cardFill))
    }

    // MARK: - Recent Events Section

    private var recentEventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Events")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(DriverTheme.textPrimary)

            ForEach(recentEvents) { event in
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(event.title)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(DriverTheme.textPrimary)
                            
                            Text(event.severity)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(severityColor(event.severity))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(severityColor(event.severity).opacity(0.15)))
                        }
                        
                        Text(event.time)
                            .font(.system(size: 12))
                            .foregroundStyle(DriverTheme.textSecondary)
                        
                        Text("Location: \(event.location)")
                            .font(.system(size: 13))
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                    
                    Spacer()

                    // Mini Map Thumbnail
                    let center = event.coordinate
                    let region = MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                    
                    Map(initialPosition: .region(region)) {
                        Annotation("", coordinate: center) {
                            Circle()
                                .fill(DriverTheme.accent)
                                .frame(width: 8, height: 8)
                                .overlay(Circle().stroke(.white, lineWidth: 1.5))
                        }
                    }
                    .mapStyle(.standard(elevation: .realistic))
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .disabled(true)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DriverTheme.cardFill))
            }
        }
    }

    // MARK: - Sparkline Speed Chart

    private var sparklineSpeedChart: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("100")
                    .font(.system(size: 10))
                    .foregroundStyle(DriverTheme.textSecondary)
                Spacer()
            }
            .frame(height: 10)

            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let dataPoints: [CGFloat] = [88, 92, 85, 96, 92, 94, 92] // score sequence
                let stepX = width / CGFloat(dataPoints.count - 1)

                ZStack {
                    // Horizontal Grid Lines
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height * 0.2))
                        path.addLine(to: CGPoint(x: width, y: height * 0.2))
                        path.move(to: CGPoint(x: 0, y: height * 0.5))
                        path.addLine(to: CGPoint(x: width, y: height * 0.5))
                        path.move(to: CGPoint(x: 0, y: height * 0.8))
                        path.addLine(to: CGPoint(x: width, y: height * 0.8))
                    }
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)

                    // Gradient Under Fill
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height))
                        for i in 0..<dataPoints.count {
                            let x = CGFloat(i) * stepX
                            let y = height * (1.0 - (dataPoints[i] / 100.0))
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [DriverTheme.accent.opacity(0.3), DriverTheme.accent.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                    // Line Path
                    Path { path in
                        let firstY = height * (1.0 - (dataPoints[0] / 100.0))
                        path.move(to: CGPoint(x: 0, y: firstY))
                        for i in 1..<dataPoints.count {
                            let x = CGFloat(i) * stepX
                            let y = height * (1.0 - (dataPoints[i] / 100.0))
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    .stroke(DriverTheme.accentGradient, lineWidth: 3)

                    // Interactive points
                    ForEach(0..<dataPoints.count, id: \.self) { idx in
                        let x = CGFloat(idx) * stepX
                        let y = height * (1.0 - (dataPoints[idx] / 100.0))
                        
                        Circle()
                            .fill(Color.white)
                            .frame(width: 6, height: 6)
                            .position(x: x, y: y)
                            .shadow(color: .black.opacity(0.3), radius: 2)
                    }
                }
            }
            .frame(height: 100)

            HStack {
                Text("0")
                    .font(.system(size: 10))
                    .foregroundStyle(DriverTheme.textSecondary)
                Spacer()
                ForEach(1...7, id: \.self) { day in
                    Text("\(day)")
                        .font(.system(size: 10))
                        .foregroundStyle(DriverTheme.textSecondary)
                    if day < 7 {
                        Spacer()
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DriverTheme.cardFill))
    }

    // MARK: - Driving Tips Card

    private var drivingTipsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Driving Tips")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DriverTheme.textPrimary)

            Text("Maintain a steady speed for smoother driving and better fuel efficiency.")
                .font(.system(size: 14))
                .foregroundStyle(DriverTheme.textSecondary)
                .lineSpacing(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DriverTheme.cardFill))
    }

    // MARK: - Complete Trip History Done by Driver Section

    private var tripHistoryDoneByDriver: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trip History & Vehicles")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(DriverTheme.textPrimary)
                .padding(.top, 8)

            if let user = currentUser {
                let trips = appViewModel.service.trips(for: user.id)
                if trips.isEmpty {
                    Text("No trip history available")
                        .font(.system(size: 14))
                        .foregroundStyle(DriverTheme.textSecondary)
                        .padding(.vertical, 8)
                } else {
                    ForEach(trips) { trip in
                        let vehicle = appViewModel.service.vehicle(for: trip.vehicleID)
                        
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(trip.origin) → \(trip.destination)")
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundStyle(DriverTheme.textPrimary)
                                    Text(trip.startDate.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(size: 13))
                                        .foregroundStyle(DriverTheme.textSecondary)
                                }
                                
                                Spacer()
                                
                                if let score = trip.safetyScore {
                                    HStack(spacing: 4) {
                                        Image(systemName: "shield.checkerboard")
                                            .font(.system(size: 11))
                                            .foregroundStyle(DriverTheme.successGreen)
                                        Text("Score: \(score)")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundStyle(DriverTheme.successGreen)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(DriverTheme.successGreen.opacity(0.15)))
                                } else {
                                    Text(trip.status.rawValue)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(trip.status == .completed ? DriverTheme.successGreen : trip.status == .inProgress ? DriverTheme.accent : DriverTheme.textSecondary)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 5)
                                        .background(Capsule().fill(Color.white.opacity(0.06)))
                                }
                            }

                            Divider().background(DriverTheme.separator)

                            HStack {
                                if let vehicle = vehicle {
                                    Label(
                                        title: { Text("\(vehicle.displayName) (\(vehicle.plateNumber))") },
                                        icon: { Image(systemName: "truck.box.fill") }
                                    )
                                    .font(.system(size: 13))
                                    .foregroundStyle(DriverTheme.textSecondary)
                                } else {
                                    Label("Unknown Vehicle", systemImage: "questionmark.circle.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(DriverTheme.textSecondary)
                                }

                                Spacer()

                                Text("\(Int(trip.distanceKM)) km")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundStyle(DriverTheme.textPrimary)
                            }
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DriverTheme.cardFill))
                    }
                }
            }
        }
    }

    private var quickSOSButton: some View {
        Button(action: {
            driverVM.startSOSCountdown(service: appViewModel.service, user: currentUser)
        }) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .font(.system(size: 16, weight: .bold))
                Text("QUICK SOS")
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(DriverTheme.criticalRed))
        }
        .padding(.top, 10)
    }

    // MARK: - Helpers

    private func severityColor(_ severity: String) -> Color {
        switch severity {
        case "Low": return DriverTheme.successGreen
        case "Medium": return DriverTheme.warningAmber
        default: return Color(hex: "FF3B30")
        }
    }
}

#Preview {
    NavigationStack {
        DriverSafetyView()
            .environmentObject(AppViewModel())
            .environmentObject(DriverViewModel())
    }
}
