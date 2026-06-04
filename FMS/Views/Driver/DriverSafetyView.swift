import SwiftUI
import MapKit

struct DriverSafetyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(DriverViewModel.self) private var driverVM

    private var currentUser: User? { appViewModel.currentUser }

    // Computed from actual completed trips
    private var completedTrips: [Trip] {
        guard let user = currentUser else { return [] }
        return appViewModel.service.trips(for: user.id).filter { $0.status == .completed }
    }

    private var averageSafetyScore: Int? {
        let scored = completedTrips.compactMap(\.safetyScore)
        guard !scored.isEmpty else { return nil }
        return scored.reduce(0, +) / scored.count
    }

    private var currentShift: ShiftInfo? {
        currentUser.flatMap { appViewModel.service.currentShift(for: $0.id) }
    }

    private var hoursDriven: Double {
        currentShift?.elapsedHours ?? 0.0
    }

    private var fatigueLevel: (label: String, color: Color, bars: Int) {
        switch hoursDriven {
        case 0..<1:    return ("Inactive", DriverTheme.textSecondary, 0)
        case 1..<4:    return ("Fully Alert", DriverTheme.successGreen, 1)
        case 4..<6:    return ("Moderate", DriverTheme.warningAmber, 3)
        case 6..<8:    return ("High", DriverTheme.criticalRed, 4)
        default:       return ("Critical", DriverTheme.criticalRed, 5)
        }
    }

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
                
                Spacer().frame(height: 40)
            }
            .padding(20)
        }
        .background(DriverScreenBackground())
        .navigationTitle("Safety")
        .navigationBarTitleDisplayMode(.inline)

    }

    private var drivingScoreSection: some View {
        VStack(spacing: 16) {
            let score = averageSafetyScore
            let scoreValue = Double(score ?? 0)
            
            ZStack {
                Circle()
                    .trim(from: 0.15, to: 0.85)
                    .stroke(DriverTheme.textSecondary.opacity(0.1), style: StrokeStyle(lineWidth: 24, lineCap: .round))
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(90))

                if score != nil {
                    Circle()
                        .trim(from: 0.15, to: 0.15 + 0.7 * (scoreValue / 100.0))
                        .stroke(
                            DriverTheme.accent,
                            style: StrokeStyle(lineWidth: 24, lineCap: .round)
                        )
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(90))
                        .shadow(color: DriverTheme.accent.opacity(0.4), radius: 10, y: 5)
                }

                VStack(spacing: -4) {
                    Text(score != nil ? "\(score!)" : "--")
                        .font(.system(size: 64, weight: .heavy, design: .rounded))
                        .foregroundStyle(DriverTheme.textPrimary)
                    Text(score != nil ? "of 100" : "No data")
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(DriverTheme.textSecondary)
                }
            }
            .frame(height: 160)
            .padding(.top, 20)

            Text(scoreMessage)
                .font(.system(.headline, design: .rounded))
                .foregroundStyle(DriverTheme.textSecondary)
        }
    }

    private var scoreMessage: String {
        guard let score = averageSafetyScore else { return "Complete trips to build your score" }
        switch score {
        case 90...100: return "Excellent driving this week"
        case 75..<90:  return "Good driving — keep it up!"
        case 50..<75:  return "Room for improvement"
        default:       return "Focus on safe driving practices"
        }
    }

    private var fatigueAndHoursGrid: some View {
        HStack(spacing: 16) {
            // Fatigue Level Card
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "eye.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(fatigueLevel.color)
                        .frame(width: 28, height: 28)
                        .background(fatigueLevel.color.opacity(0.12), in: Circle())
                    
                    Spacer()
                    
                    Text(hoursDriven > 0 ? (fatigueLevel.bars <= 2 ? "Low" : "High") : "N/A")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(fatigueLevel.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(fatigueLevel.color.opacity(0.12), in: Capsule())
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fatigue Level")
                        .font(.system(.caption2, design: .rounded).bold())
                        .foregroundStyle(DriverTheme.textSecondary)
                    
                    Text(fatigueLevel.label)
                        .font(.system(.headline, design: .rounded).bold())
                        .foregroundStyle(DriverTheme.textPrimary)
                }
                
                HStack(spacing: 5) {
                    ForEach(0..<5, id: \.self) { idx in
                        Capsule()
                            .fill(idx < fatigueLevel.bars ? fatigueLevel.color : DriverTheme.textSecondary.opacity(0.15))
                            .frame(height: 6)
                    }
                }
                .padding(.top, 4)
            }
            .padding(16)
            .background(DriverTheme.elevatedCard)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(DriverTheme.accent.opacity(0.1), lineWidth: 1)
            )

            // Hours Driven Card
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Image(systemName: "clock.badge.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(DriverTheme.accent)
                        .frame(width: 28, height: 28)
                        .background(DriverTheme.accent.opacity(0.12), in: Circle())
                    
                    Spacer()
                    
                    Text("Limit: 8h")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(DriverTheme.textSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(DriverTheme.textSecondary.opacity(0.1), in: Capsule())
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hours Driven")
                        .font(.system(.caption2, design: .rounded).bold())
                        .foregroundStyle(DriverTheme.textSecondary)
                    
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text(String(format: "%.1f", hoursDriven))
                            .font(.system(.title2, design: .rounded).bold())
                            .foregroundStyle(DriverTheme.textPrimary)
                        Text("hrs")
                            .font(.caption.bold())
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                }
                
                // Linear Progress bar representing hours driven vs limit
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(DriverTheme.textSecondary.opacity(0.15))
                            .frame(height: 6)
                        Capsule()
                            .fill(hoursDriven > 7 ? DriverTheme.criticalRed : DriverTheme.accent)
                            .frame(width: geo.size.width * min(hoursDriven / 8.0, 1.0), height: 6)
                    }
                }
                .frame(height: 6)
                .padding(.top, 4)
            }
            .padding(16)
            .background(DriverTheme.elevatedCard)
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .strokeBorder(DriverTheme.accent.opacity(0.1), lineWidth: 1)
            )
        }
    }

    private var crashDetectionStatusCard: some View {
        HStack(spacing: 16) {
            ZStack {
                // Glowing background radar ring
                Circle()
                    .stroke(DriverTheme.successGreen.opacity(0.2), lineWidth: 2)
                    .frame(width: 48, height: 48)
                
                Image(systemName: "checkmark.shield.fill")
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(DriverTheme.successGreen, in: Circle())
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Crash Detection Status")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(DriverTheme.textPrimary)
                Text("Active & Monitoring in real-time")
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(DriverTheme.successGreen)
            }
            
            Spacer()
            
            Text("SECURE")
                .font(.system(size: 9, weight: .black))
                .foregroundStyle(DriverTheme.successGreen)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(DriverTheme.successGreen.opacity(0.12))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .strokeBorder(DriverTheme.successGreen.opacity(0.3), lineWidth: 1)
                )
        }
        .padding(16)
        .background(DriverTheme.elevatedCard)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(DriverTheme.successGreen.opacity(0.15), lineWidth: 1.5)
        )
    }

    private var recentEventsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Events")
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(DriverTheme.textPrimary)

            if completedTrips.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "shield.checkered")
                        .font(.system(size: 40))
                        .foregroundStyle(DriverTheme.textSecondary.opacity(0.5))
                    Text("No safety events recorded")
                        .font(.headline)
                        .foregroundStyle(DriverTheme.textSecondary)
                    Text("Complete trips to see safety event data")
                        .font(.caption)
                        .foregroundStyle(DriverTheme.textSecondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(DriverTheme.elevatedCard, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(DriverTheme.accent.opacity(0.1), lineWidth: 1))
            } else {
                Text("Safety monitoring active for \(completedTrips.count) trip(s)")
                    .font(.subheadline)
                    .foregroundStyle(DriverTheme.textSecondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DriverTheme.elevatedCard, in: RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(DriverTheme.accent.opacity(0.1), lineWidth: 1))
            }
        }
    }

    private var sparklineSpeedChart: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Weekly Score Trend")
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(DriverTheme.textPrimary)

            let scored = completedTrips.compactMap(\.safetyScore).map { CGFloat($0) }

            if scored.count >= 2 {
                GeometryReader { geo in
                    let width = geo.size.width
                    let height = geo.size.height
                    let dataPoints = Array(scored.suffix(7))
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
                        .fill(DriverTheme.accent.opacity(0.15))

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
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.system(size: 36))
                        .foregroundStyle(DriverTheme.textSecondary.opacity(0.4))
                    Text("No trend data available")
                        .font(.subheadline.bold())
                        .foregroundStyle(DriverTheme.textSecondary)
                    Text("Complete 2+ trips with safety scores to see trends")
                        .font(.caption)
                        .foregroundStyle(DriverTheme.textSecondary.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            }
        }
        .padding(20)
        .background(DriverTheme.elevatedCard, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(DriverTheme.accent.opacity(0.1), lineWidth: 1))
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
        .background(DriverTheme.elevatedCard, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(DriverTheme.warningAmber.opacity(0.15), lineWidth: 1))
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
                    .background(DriverTheme.elevatedCard, in: RoundedRectangle(cornerRadius: 24))
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(DriverTheme.accent.opacity(0.1), lineWidth: 1))
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
}

#Preview {
    NavigationStack {
        DriverSafetyView()
            .environment(AppViewModel())
            .environment(DriverViewModel())
    }
}
