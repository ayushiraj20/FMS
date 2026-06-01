import Charts
import SwiftUI

/// Renders Swift Charts snapshots for embedding in PDF reports (Apple Charts + ImageRenderer).
@MainActor
enum FleetReportChartRenderer {

    static func fleetOverviewChart(active: Int, total: Int, utilizationPercent: Int) -> UIImage? {
        let inactive = max(0, total - active)
        return render(width: 500, height: 200) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Fleet activity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Chart {
                    BarMark(x: .value("Status", "Active"), y: .value("Count", active))
                        .foregroundStyle(Color.blue.gradient)
                    BarMark(x: .value("Status", "Inactive"), y: .value("Count", inactive))
                        .foregroundStyle(Color.gray.opacity(0.45).gradient)
                }
                .chartYAxis { AxisMarks(position: .leading) }
                HStack {
                    Label("\(utilizationPercent)% avg utilization", systemImage: "gauge.with.needle.fill")
                    Spacer()
                    Text("\(active)/\(total) vehicles active")
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
            .padding(12)
        }
    }

    static func maintenanceChart(open: Int, overdue: Int, completed: Int, critical: Int) -> UIImage? {
        render(width: 500, height: 200) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Maintenance workload")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Chart {
                    BarMark(x: .value("Type", "Open"), y: .value("Count", open))
                        .foregroundStyle(Color.orange.gradient)
                    BarMark(x: .value("Type", "Overdue"), y: .value("Count", overdue))
                        .foregroundStyle(Color.red.gradient)
                    BarMark(x: .value("Type", "Completed"), y: .value("Count", completed))
                        .foregroundStyle(Color.green.gradient)
                    BarMark(x: .value("Type", "Critical"), y: .value("Count", critical))
                        .foregroundStyle(Color.purple.gradient)
                }
                .chartYAxis { AxisMarks(position: .leading) }
            }
            .padding(12)
        }
    }

    static func complianceChart(expired: Int, expiring: Int, missing: Int, valid: Int) -> UIImage? {
        let slices: [(String, Int, Color)] = [
            ("Expired", expired, .red),
            ("Expiring", expiring, .orange),
            ("Missing", missing, .purple),
            ("Valid", valid, .green)
        ].filter { $0.1 > 0 }

        guard !slices.isEmpty else { return nil }

        return render(width: 500, height: 220) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Document compliance")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Chart(slices, id: \.0) { item in
                    SectorMark(
                        angle: .value("Count", item.1),
                        innerRadius: .ratio(0.55),
                        angularInset: 1.5
                    )
                    .foregroundStyle(item.2.gradient)
                    .annotation(position: .overlay) {
                        if item.1 > 0 {
                            Text("\(item.1)")
                                .font(.caption2.bold())
                                .foregroundStyle(.white)
                        }
                    }
                }
                .chartLegend(position: .bottom, spacing: 8)
            }
            .padding(12)
        }
    }

    static func fuelChart(verifiedSpend: Double, totalSpend: Double, pendingCount: Int) -> UIImage? {
        let pendingSpend = max(0, totalSpend - verifiedSpend)
        return render(width: 500, height: 200) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Fuel spend (INR)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Chart {
                    BarMark(x: .value("Type", "Verified"), y: .value("Amount", verifiedSpend))
                        .foregroundStyle(Color.teal.gradient)
                    BarMark(x: .value("Type", "Unverified"), y: .value("Amount", pendingSpend))
                        .foregroundStyle(Color.yellow.gradient)
                }
                .chartYAxis { AxisMarks(position: .leading) }
                Text("\(pendingCount) transactions pending verification")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(12)
        }
    }

    static func topRoutesChart(routes: [(name: String, trips: Int)]) -> UIImage? {
        let top = Array(routes.prefix(5))
        guard !top.isEmpty else { return nil }

        return render(width: 500, height: min(260, CGFloat(48 + top.count * 36))) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Top routes by trip volume")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Chart(top, id: \.name) { route in
                    BarMark(
                        x: .value("Trips", route.trips),
                        y: .value("Route", route.name)
                    )
                    .foregroundStyle(Color.indigo.gradient)
                    .annotation(position: .trailing) {
                        Text("\(route.trips)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis { AxisMarks(position: .bottom) }
            }
            .padding(12)
        }
    }

    private static func render<V: View>(width: CGFloat, height: CGFloat, @ViewBuilder content: () -> V) -> UIImage? {
        let view = content()
            .frame(width: width, height: height)
            .background(Color(.systemBackground))
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.uiImage
    }
}
