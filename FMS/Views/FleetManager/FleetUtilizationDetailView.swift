import SwiftUI

struct FleetUtilizationDetailView: View {
    @Environment(AppViewModel.self) private var appViewModel
    
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
                        .trim(from: 0.1, to: 0.1 + (0.8 * CGFloat(appViewModel.service.overallUtilization) / 100.0))
                        .stroke(
                            AngularGradient(gradient: Gradient(colors: [.green, .orange]), center: .center, startAngle: .degrees(90), endAngle: .degrees(90 + 360)),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .rotationEffect(.degrees(90))
                        .frame(width: 140, height: 140)
                    
                    VStack {
                        Text("\(appViewModel.service.overallUtilization)%")
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(appViewModel.service.overallUtilization >= 70 ? "Optimal" : "Sub-optimal")
                            .font(.caption)
                            .foregroundStyle(appViewModel.service.overallUtilization >= 70 ? .green : .red)
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
                    utilizationRow(color: .green, label: "Active", value: appViewModel.service.utilizationActivePercentage, detail: "Vehicles on the road")
                    utilizationRow(color: .orange, label: "Idle", value: appViewModel.service.utilizationIdlePercentage, detail: "Available but not in use")
                    utilizationRow(color: .red, label: "Maintenance", value: appViewModel.service.utilizationMaintenancePercentage, detail: "Currently being serviced")
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
                    metricBox(
                        title: "Avg. Hours/Day",
                        value: String(format: "%.1fh", appViewModel.service.avgHoursPerDay),
                        trend: String(format: "%+.1fh", appViewModel.service.avgHoursPerDayTrend),
                        isPositive: appViewModel.service.avgHoursPerDayTrend >= 0
                    )
                    metricBox(
                        title: "Idle Time",
                        value: String(format: "%.1fh", appViewModel.service.avgIdleTime),
                        trend: String(format: "%+.1fh", appViewModel.service.avgIdleTimeTrend),
                        isPositive: appViewModel.service.avgIdleTimeTrend <= 0
                    )
                }
                
                HStack(spacing: 12) {
                    metricBox(
                        title: "Avg. Distance",
                        value: String(format: "%.0f km", appViewModel.service.avgDistanceKM),
                        trend: String(format: "%+.0f km", appViewModel.service.avgDistanceTrend),
                        isPositive: appViewModel.service.avgDistanceTrend >= 0
                    )
                    metricBox(
                        title: "Fuel Efficiency",
                        value: String(format: "%.1f km/L", appViewModel.service.avgFuelEfficiency),
                        trend: String(format: "%+.1f km/L", appViewModel.service.avgFuelEfficiencyTrend),
                        isPositive: appViewModel.service.avgFuelEfficiencyTrend >= 0
                    )
                }
            }
        }
    }
    
    // MARK: - Helpers
    private func utilizationRow(color: Color, label: String, value: Int, detail: String) -> some View {
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
            
            Text(detail)
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
    
    private func metricBox(title: String, value: String, trend: String, isPositive: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            
            HStack(alignment: .bottom) {
                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                
                Spacer()
                
                HStack(spacing: 2) {
                    Image(systemName: isPositive ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2.weight(.bold))
                    Text(trend)
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(isPositive ? .green : .red)
                .padding(.bottom, 2)
            }
        }
        .padding()
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
