import SwiftUI

struct FleetUtilizationDetailView: View {
    @Environment(AppViewModel.self) private var appViewModel

    private var summary: FleetUtilizationSummary {
        appViewModel.service.fleetUtilizationSummary()
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                overviewCard
                
                statusBreakdownCard
                
                efficiencyMetricsCard
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .navigationTitle("Fleet Utilization")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Overview
    private var overviewCard: some View {
        GlassCard {
            VStack(alignment: .center, spacing: 16) {
                Text("Overall Utilization")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textSecondary)
                
                ZStack {
                    Circle()
                        .trim(from: 0.1, to: 0.9)
                        .stroke(AppTheme.surfaceSecondary, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                        .rotationEffect(.degrees(90))
                        .frame(width: 140, height: 140)
                    
                    Circle()
                        .trim(from: 0.1, to: 0.1 + (0.8 * Double(summary.averageUtilization) / 100.0))
                        .stroke(
                            AngularGradient(gradient: Gradient(colors: [.green, .orange]), center: .center, startAngle: .degrees(90), endAngle: .degrees(90 + 360)),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .rotationEffect(.degrees(90))
                        .frame(width: 140, height: 140)
                    
                    VStack {
                        Text("\(summary.averageUtilization)%")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(utilizationStatus)
                            .font(.caption)
                            .foregroundStyle(utilizationStatusColor)
                    }
                }
                .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity)
        }
    }
    
    // MARK: - Status Breakdown
    private var statusBreakdownCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Current Status Breakdown")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                VStack(spacing: 16) {
                    utilizationRow(color: .green, label: "Active", value: summary.activePercent, count: summary.activeVehicles, detail: "Vehicles on the road")
                    utilizationRow(color: .orange, label: "Idle", value: summary.idlePercent, count: summary.idleVehicles, detail: "Available but not in use")
                    utilizationRow(color: Color(UIColor.systemBlue), label: "Maintenance", value: summary.maintenancePercent, count: summary.maintenanceVehicles, detail: "Vehicles with open work orders or out of service")
                }
            }
        }
    }
    
    // MARK: - Efficiency Metrics
    private var efficiencyMetricsCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Efficiency Metrics")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                HStack(spacing: 12) {
                    metricBox(title: "Active Trips", value: "\(summary.activeTrips)", icon: "truck.box.fill", tint: AppTheme.brand)
                    metricBox(title: "Completed Trips", value: "\(summary.completedTrips)", icon: "checkmark.seal.fill", tint: AppTheme.success)
                }
                
                HStack(spacing: 12) {
                    metricBox(title: "Avg. Distance", value: "\(Int(summary.averageTripDistance.rounded())) km", icon: "road.lanes", tint: Color(UIColor.systemTeal))
                    metricBox(title: "Total Distance", value: "\(Int(summary.totalTripDistance.rounded())) km", icon: "speedometer", tint: Color(UIColor.systemPurple))
                }
            }
        }
    }
    
    // MARK: - Helpers
    private var utilizationStatus: String {
        switch summary.averageUtilization {
        case 80...: return "High"
        case 50..<80: return "Optimal"
        case 1..<50: return "Low"
        default: return "No Data"
        }
    }

    private var utilizationStatusColor: Color {
        switch summary.averageUtilization {
        case 80...: return AppTheme.warning
        case 50..<80: return AppTheme.success
        case 1..<50: return Color(UIColor.systemBlue)
        default: return AppTheme.textSecondary
        }
    }

    private func utilizationRow(color: Color, label: String, value: Int, count: Int, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 8, height: 8)
                
                Text(label)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                
                Spacer()
                
                Text("\(value)%")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            
            Text("\(count) vehicle\(count == 1 ? "" : "s") - \(detail)")
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.leading, 16)
                
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.surfaceSecondary)
                        .frame(height: 8)
                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * CGFloat(value) / 100.0, height: 8)
                }
            }
            .frame(height: 8)
            .padding(.top, 4)
        }
    }
    
    private func metricBox(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(AppTheme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(AppTheme.surfaceSecondary.opacity(0.5))
        )
    }
}

#Preview {
    NavigationStack {
        FleetUtilizationDetailView()
            .environment(AppViewModel())
    }
}
