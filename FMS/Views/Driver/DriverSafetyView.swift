import SwiftUI
import MapKit

struct DriverSafetyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(DriverViewModel.self) private var driverVM

    private var currentUser: User? { appViewModel.currentUser }

    private struct SafetyEvent: Identifiable {
        let id = UUID()
        let title: String
        let time: String
        let location: String
        let severity: String
        let coordinate: CLLocationCoordinate2D
    }

    private let recentEvents = [
        SafetyEvent(title: "Harsh Braking", time: "2:15 PM", location: "Industrial Area", severity: "Low", coordinate: CLLocationCoordinate2D(latitude: 19.0330, longitude: 73.0297)),
        SafetyEvent(title: "Rapid Acceleration", time: "11:30 AM", location: "Main Street", severity: "Medium", coordinate: CLLocationCoordinate2D(latitude: 18.7557, longitude: 73.4091))
    ]

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                drivingScoreSection
                fatigueAndHoursGrid
                crashDetectionStatusCard
                recentEventsSection
                sparklineSpeedChart
                drivingTipsCard
                tripHistoryDoneByDriver
                quickSOSButton
                
                Spacer().frame(height: 40)
            }
            .padding(20)
        }
        .background(
            ZStack {
                DriverTheme.background.ignoresSafeArea()
                GeometryReader { geo in
                    Circle()
                        .fill(DriverTheme.accent.opacity(0.1))
                        .frame(width: geo.size.width)
                        .blur(radius: 80)
                        .offset(x: -geo.size.width * 0.2, y: geo.size.height * 0.1)
                }.ignoresSafeArea()
            }
        )
        .navigationTitle("Safety")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {}) {
                    Image(systemName: "bell.badge.fill")
                        .font(.headline)
                        .foregroundStyle(DriverTheme.accent)
                }
            }
        }
    }

    private var drivingScoreSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .trim(from: 0.15, to: 0.85)
                    .stroke(DriverTheme.textSecondary.opacity(0.1), style: StrokeStyle(lineWidth: 24, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(90))

                Circle()
                    .trim(from: 0.15, to: 0.15 + 0.7 * (92.0 / 100.0))
                    .stroke(
                        LinearGradient(colors: [DriverTheme.accent, DriverTheme.successGreen], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 24, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(90))
                    .shadow(color: DriverTheme.successGreen.opacity(0.4), radius: 10, y: 5)

                VStack(spacing: -4) {
                    Text("92")
                        .font(.system(size: 64, weight: .heavy, design: .rounded))
                        .foregroundStyle(DriverTheme.textPrimary)
                    Text("of 100")
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(DriverTheme.textSecondary)
                }
            }
            .frame(height: 160)
            .padding(.top, 20)

            Text("Excellent driving this week")
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(DriverTheme.textSecondary)
        }
    }

    private var fatigueAndHoursGrid: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Fatigue Level")
                    .font(.caption.bold())
                    .foregroundStyle(DriverTheme.textSecondary)
                
                HStack(spacing: 4) {
                    ForEach(0..<6, id: \.self) { idx in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(idx < 2 ? DriverTheme.successGreen : DriverTheme.textSecondary.opacity(0.2))
                            .frame(height: 24)
                    }
                }
                
                Text("Low")
                    .font(.system(.title3, design: .rounded).bold())
                    .foregroundStyle(DriverTheme.successGreen)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            VStack(alignment: .leading, spacing: 12) {
                Text("Hours Driven")
                    .font(.caption.bold())
                    .foregroundStyle(DriverTheme.textSecondary)
                
                HStack(alignment: .bottom, spacing: 4) {
                    Text("4.5")
                        .font(.system(.title, design: .rounded).bold())
                        .foregroundStyle(DriverTheme.textPrimary)
                    Text("h")
                        .font(.headline)
                        .foregroundStyle(DriverTheme.textSecondary)
                        .padding(.bottom, 4)
                }
                
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundStyle(DriverTheme.accent)
                    Text("Out of 8h")
                        .font(.caption.bold())
                        .foregroundStyle(DriverTheme.textSecondary)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private var crashDetectionStatusCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.title)
                .foregroundStyle(DriverTheme.successGreen)
                .frame(width: 48, height: 48)
                .background(DriverTheme.successGreen.opacity(0.15), in: Circle())
                .symbolEffect(.bounce, options: .nonRepeating)

            VStack(alignment: .leading, spacing: 4) {
                Text("Crash Detection Status")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(DriverTheme.textPrimary)
                Text("Active & Monitoring")
                    .font(.subheadline)
                    .foregroundStyle(DriverTheme.successGreen)
            }
            Spacer()
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(DriverTheme.successGreen.opacity(0.3), lineWidth: 1))
    }

    private var recentEventsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Events")
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(DriverTheme.textPrimary)

            LazyVStack(spacing: 12) {
                ForEach(recentEvents) { event in
                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(event.title)
                                    .font(.system(.headline, design: .rounded))
                                    .foregroundStyle(DriverTheme.textPrimary)
                                Spacer()
                                Text(event.severity)
                                    .font(.caption2.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(severityColor(event.severity).opacity(0.15), in: Capsule())
                                    .foregroundStyle(severityColor(event.severity))
                            }
                            
                            HStack {
                                Image(systemName: "clock")
                                Text(event.time)
                                Spacer()
                                Image(systemName: "mappin.and.ellipse")
                                Text(event.location)
                            }
                            .font(.caption)
                            .foregroundStyle(DriverTheme.textSecondary)
                        }
                        
                        let region = MKCoordinateRegion(center: event.coordinate, span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01))
                        Map(initialPosition: .region(region)) {
                            Annotation("", coordinate: event.coordinate) {
                                Circle()
                                    .fill(DriverTheme.accent)
                                    .frame(width: 12, height: 12)
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                                    .shadow(radius: 2)
                            }
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .disabled(true)
                    }
                    .padding(16)
                    .background(DriverTheme.cardFill, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
            }
        }
    }

    private var sparklineSpeedChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Score Trend")
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(DriverTheme.textPrimary)

            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let dataPoints: [CGFloat] = [88, 92, 85, 96, 92, 94, 92]
                let stepX = width / CGFloat(max(1, dataPoints.count - 1))

                ZStack {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height))
                        for i in 0..<dataPoints.count {
                            path.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: height * (1.0 - (dataPoints[i] / 100.0))))
                        }
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [DriverTheme.accent.opacity(0.3), DriverTheme.accent.opacity(0.0)], startPoint: .top, endPoint: .bottom))

                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height * (1.0 - (dataPoints[0] / 100.0))))
                        for i in 1..<dataPoints.count {
                            path.addLine(to: CGPoint(x: CGFloat(i) * stepX, y: height * (1.0 - (dataPoints[i] / 100.0))))
                        }
                    }
                    .stroke(DriverTheme.accent, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                    ForEach(0..<dataPoints.count, id: \.self) { idx in
                        Circle()
                            .fill(.white)
                            .frame(width: 8, height: 8)
                            .position(x: CGFloat(idx) * stepX, y: height * (1.0 - (dataPoints[idx] / 100.0)))
                            .shadow(radius: 2)
                    }
                }
            }
            .frame(height: 100)
            .padding(.top, 10)

            HStack {
                ForEach(["M", "T", "W", "T", "F", "S", "S"], id: \.self) { day in
                    Text(day)
                        .font(.caption.bold())
                        .foregroundStyle(DriverTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var drivingTipsCard: some View {
        HStack(spacing: 16) {
            Image(systemName: "lightbulb.fill")
                .font(.title)
                .foregroundStyle(DriverTheme.warningAmber)
                .frame(width: 48, height: 48)
                .background(DriverTheme.warningAmber.opacity(0.15), in: Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text("Pro Tip")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(DriverTheme.textPrimary)
                Text("Maintain a steady speed for smoother driving and better fuel efficiency.")
                    .font(.subheadline)
                    .foregroundStyle(DriverTheme.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var tripHistoryDoneByDriver: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Trip History")
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(DriverTheme.textPrimary)

            if let user = currentUser {
                let trips = appViewModel.service.trips(for: user.id)
                if trips.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "map")
                            .font(.system(size: 40))
                            .foregroundStyle(DriverTheme.textSecondary.opacity(0.5))
                        Text("No trips recorded yet")
                            .font(.headline)
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24))
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(trips) { trip in
                            let vehicle = appViewModel.service.vehicle(for: trip.vehicleID)
                            VStack(spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(trip.origin) → \(trip.destination)")
                                            .font(.system(.headline, design: .rounded))
                                        Text(trip.startDate.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption)
                                            .foregroundStyle(DriverTheme.textSecondary)
                                    }
                                    Spacer()
                                    if let score = trip.safetyScore {
                                        HStack(spacing: 4) {
                                            Image(systemName: "shield.checkerboard")
                                            Text("\(score)")
                                        }
                                        .font(.caption.bold())
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(DriverTheme.successGreen.opacity(0.15), in: Capsule())
                                        .foregroundStyle(DriverTheme.successGreen)
                                    } else {
                                        Text(trip.status.rawValue)
                                            .font(.caption.bold())
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 6)
                                            .background(DriverTheme.textSecondary.opacity(0.1), in: Capsule())
                                            .foregroundStyle(DriverTheme.textSecondary)
                                    }
                                }

                                Divider().background(DriverTheme.textSecondary.opacity(0.2))

                                HStack {
                                    HStack(spacing: 8) {
                                        Image(systemName: "truck.box.fill")
                                        Text(vehicle?.displayName ?? "Unknown Vehicle")
                                    }
                                    .font(.caption.bold())
                                    .foregroundStyle(DriverTheme.textSecondary)
                                    
                                    Spacer()
                                    Text("\(Int(trip.distanceKM)) km")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(DriverTheme.textPrimary)
                                }
                            }
                            .padding(16)
                            .background(DriverTheme.cardFill, in: RoundedRectangle(cornerRadius: 24))
                        }
                    }
                }
            }
        }
    }

    private var quickSOSButton: some View {
        Button {
            driverVM.startSOSCountdown(service: appViewModel.service, user: currentUser)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                Text("Emergency SOS")
                    .font(.system(.title3, design: .rounded).bold())
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 64)
            .background(DriverTheme.criticalRed, in: Capsule())
            .shadow(color: DriverTheme.criticalRed.opacity(0.4), radius: 15, y: 5)
        }
        .padding(.vertical, 10)
    }

    private func severityColor(_ severity: String) -> Color {
        switch severity {
        case "Low": return DriverTheme.successGreen
        case "Medium": return DriverTheme.warningAmber
        default: return DriverTheme.criticalRed
        }
    }
}

#Preview {
    NavigationStack {
        DriverSafetyView()
            .environment(AppViewModel())
            .environment(DriverViewModel())
    }
}
