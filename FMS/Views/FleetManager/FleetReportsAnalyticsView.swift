import SwiftUI
import UIKit

struct FleetReportsAnalyticsView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var snapshot: FleetReportSnapshot?
    @State private var spareParts: [SparePart] = []
    @State private var fuelTransactions: [FuelTransaction] = []
    @State private var selectedSection: ReportSection = .overview
    @State private var isLoading = false
    @State private var loadMessage: String?
    @State private var generatedPDFURL: URL?
    @State private var showShareSheet = false

    private let reportService = FleetReportService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                sectionPicker

                if isLoading && snapshot == nil {
                    LoadingStateView(title: "Generating fleet reports...")
                        .frame(height: 260)
                } else if let snapshot {
                    sectionContent(snapshot)
                } else {
                    EmptyStateView(
                        icon: "doc.text.magnifyingglass",
                        title: "No report generated",
                        message: "Generate a report to review maintenance, fuel, inventory, compliance, and routing signals."
                    )
                }

                if let loadMessage {
                    Label(loadMessage, systemImage: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                        .padding(.top, 4)
                }
            }
            .padding(20)
            .padding(.bottom, 24)
        }
        .background(AppTheme.background)
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await generateReport(exportPDF: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .disabled(isLoading)
            }
        }
        .refreshable {
            await generateReport(exportPDF: true)
        }
        .sheet(isPresented: $showShareSheet, onDismiss: { generatedPDFURL = nil }) {
            if let generatedPDFURL {
                ShareSheet(items: [generatedPDFURL])
                    .registersSheetPresentation()
            }
        }
        .hidesTabBarWhileSheet(isPresented: showShareSheet)
    }

    private var header: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "chart.bar.doc.horizontal.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(AppTheme.brand, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(AppBranding.name) Reports")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Professional PDF export with charts, built from live vehicles, trips, fuel, work orders, inventory, and compliance.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }

                HStack(spacing: 12) {
                    Button {
                        Task { await generateReport(exportPDF: true) }
                    } label: {
                        Label("Generate Report", systemImage: "doc.badge.gearshape.fill")
                            .lineLimit(1)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.brand)
                    .disabled(isLoading)

                    if let snapshot {
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("Last Generated")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                            Text(snapshot.generatedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
            }
        }
    }

    private var sectionPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ReportSection.allCases) { section in
                    Button {
                        withAnimation(.snappy(duration: 0.18)) {
                            selectedSection = section
                        }
                    } label: {
                        Label(section.rawValue, systemImage: section.iconName)
                            .font(.caption.weight(.semibold))
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(selectedSection == section ? .white : AppTheme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(selectedSection == section ? AppTheme.brand : AppTheme.surfaceSecondary, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    @ViewBuilder
    private func sectionContent(_ snapshot: FleetReportSnapshot) -> some View {
        switch selectedSection {
        case .overview:
            overviewSection(snapshot)
        case .maintenance:
            maintenanceSection(snapshot.maintenance)
        case .inventory:
            inventorySection(snapshot.inventory)
        case .fuel:
            fuelSection(snapshot.fuel)
        case .compliance:
            complianceSection(snapshot.compliance)
        case .routing:
            routingSection(snapshot.routing)
        }
    }

    private func overviewSection(_ snapshot: FleetReportSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                reportMetric("Vehicles", "\(snapshot.summary.totalVehicles)", "Active \(snapshot.summary.activeVehicles)", "truck.box.fill", .blue)
                reportMetric("Utilization", "\(Int(snapshot.summary.averageUtilization.rounded()))%", "Fleet average", "gauge.with.dots.needle.67percent", AppTheme.success)
                reportMetric("Open Orders", "\(snapshot.summary.openWorkOrders)", "\(snapshot.summary.unresolvedDefects) unresolved defects", "wrench.and.screwdriver.fill", AppTheme.warning)
                reportMetric("Compliance", "\(snapshot.compliance.alerts.count)", "Alerts", "doc.text.fill", snapshot.compliance.expiredCount > 0 ? AppTheme.error : AppTheme.brand)
            }

            reportGroup(title: "Recommendations", icon: "sparkles") {
                VStack(spacing: 10) {
                    ForEach(snapshot.recommendations) { recommendation in
                        recommendationRow(recommendation)
                    }
                }
            }
        }
    }

    private func maintenanceSection(_ report: MaintenanceReportSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                reportMetric("Total Orders", "\(report.totalWorkOrders)", "\(report.completedWorkOrders) completed", "list.clipboard.fill", .blue)
                reportMetric("Critical", "\(report.criticalWorkOrders)", "\(report.overdueWorkOrders) overdue", "exclamationmark.triangle.fill", report.criticalWorkOrders > 0 ? AppTheme.error : AppTheme.success)
                reportMetric("Est. Cost", currency(report.totalEstimatedCost), "Avg \(currency(report.averageEstimatedCost))", "indianrupeesign.circle.fill", AppTheme.warning)
                reportMetric("Due Soon", "\(report.rows.filter { $0.severity.rank >= FleetReportSeverity.action.rank }.count)", "Vehicles", "calendar.badge.clock", AppTheme.brand)
            }

            reportGroup(title: "Vehicle Maintenance Report", icon: "wrench.and.screwdriver.fill") {
                if report.rows.isEmpty {
                    EmptyStateView(icon: "checkmark.seal.fill", title: "No maintenance risk", message: "No active maintenance signals are present for the selected fleet.")
                } else {
                    VStack(spacing: 10) {
                        ForEach(report.rows.prefix(12)) { row in
                            maintenanceRow(row)
                        }
                    }
                }
            }
        }
    }

    private func inventorySection(_ report: InventoryReportSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                reportMetric("Part Types", "\(report.totalPartTypes)", "\(report.totalQuantity) units", "shippingbox.fill", .blue)
                reportMetric("Low Stock", "\(report.lowStockCount)", "\(report.outOfStockCount) out", "exclamationmark.triangle.fill", report.outOfStockCount > 0 ? AppTheme.error : AppTheme.warning)
            }

            reportGroup(title: "Inventory Reorder Plan", icon: "shippingbox.fill") {
                let reorderRows = report.forecastRows.filter { $0.reorderQuantity > 0 }
                if reorderRows.isEmpty {
                    EmptyStateView(icon: "checkmark.seal.fill", title: "No reorders needed", message: "All spare parts are above forecasted reorder thresholds.")
                } else {
                    VStack(spacing: 10) {
                        ForEach(reorderRows.prefix(12)) { row in
                            sparePartForecastRow(row)
                        }
                    }
                }
            }

            reportGroup(title: "Inventory Overview", icon: "list.bullet.rectangle") {
                if report.forecastRows.isEmpty {
                    EmptyStateView(icon: "shippingbox", title: "No inventory data", message: "Spare parts inventory will appear after records are loaded from the database.")
                } else {
                    VStack(spacing: 10) {
                        ForEach(report.forecastRows.prefix(12)) { row in
                            sparePartForecastRow(row)
                        }
                    }
                }
            }
        }
    }

    private func fuelSection(_ report: FuelReportSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                reportMetric("Fuel Spend", currency(report.totalSpend), "\(currency(report.verifiedSpend)) verified", "fuelpump.fill", AppTheme.warning)
                reportMetric("Pending", "\(report.pendingTransactions)", "Transactions", "clock.badge.exclamationmark.fill", report.pendingTransactions > 0 ? AppTheme.warning : AppTheme.success)
                reportMetric("Avg Use", fuelText(report.averageConsumption), "Target \(fuelText(report.benchmarkConsumption))", "speedometer", .blue)
                reportMetric("Saving", "\(Int(report.potentialLitresSavedMonthly.rounded())) L", "Monthly potential", "leaf.fill", AppTheme.success)
            }

            reportGroup(title: "Fuel Consumption Optimization", icon: "fuelpump.fill") {
                if report.highConsumptionVehicles.isEmpty {
                    EmptyStateView(icon: "checkmark.seal.fill", title: "Fuel use near target", message: "No vehicle is materially above its benchmark consumption.")
                } else {
                    VStack(spacing: 10) {
                        ForEach(report.highConsumptionVehicles.prefix(10)) { row in
                            fuelVehicleRow(row)
                        }
                    }
                }
            }
        }
    }

    private func complianceSection(_ report: ComplianceReportSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                reportMetric("Documents", "\(report.totalDocuments)", "Uploaded", "doc.text.fill", .blue)
                reportMetric("Expired", "\(report.expiredCount)", "Critical", "xmark.seal.fill", report.expiredCount > 0 ? AppTheme.error : AppTheme.success)
                reportMetric("Expiring", "\(report.expiringSoonCount)", "Next 30 days", "calendar.badge.exclamationmark", AppTheme.warning)
                reportMetric("Missing", "\(report.missingCount)", "Required", "questionmark.folder.fill", report.missingCount > 0 ? AppTheme.warning : AppTheme.success)
            }

            reportGroup(title: "Automated Compliance Alerts", icon: "bell.badge.fill") {
                if report.alerts.isEmpty {
                    EmptyStateView(icon: "checkmark.seal.fill", title: "Compliance clear", message: "No expired, expiring, or missing document alerts were generated.")
                } else {
                    VStack(spacing: 10) {
                        ForEach(report.alerts.prefix(16)) { alert in
                            complianceAlertRow(alert)
                        }
                    }
                }
            }
        }
    }

    private func routingSection(_ report: RoutingReportSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                reportMetric("Avg Trip", "\(Int(report.averageTripDistance.rounded())) km", "Recorded routes", "map.fill", .blue)
                reportMetric("Idle", "\(report.idleVehicles)", "Available capacity", "parkingsign.circle.fill", AppTheme.success)
                reportMetric("Overloaded", "\(report.overloadedVehicles)", "Above 85%", "gauge.open.with.lines.needle.84percent.exclamation", report.overloadedVehicles > 0 ? AppTheme.warning : AppTheme.success)
                reportMetric("Repeat Routes", "\(report.repeatedRoutes.count)", "Optimization candidates", "point.topleft.down.to.point.bottomright.curvepath", AppTheme.brand)
            }

            reportGroup(title: "Intelligent Routing", icon: "point.topleft.down.to.point.bottomright.curvepath") {
                VStack(alignment: .leading, spacing: 12) {
                    Text(report.recommendation)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if report.repeatedRoutes.isEmpty {
                        EmptyStateView(icon: "map", title: "No repeated route pattern", message: "Route candidates appear after repeated trips share the same origin and destination.")
                    } else {
                        VStack(spacing: 10) {
                            ForEach(report.repeatedRoutes.prefix(10)) { row in
                                routeRow(row)
                            }
                        }
                    }
                }
            }
        }
    }

    private func reportGroup<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                Label(title, systemImage: icon)
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)
                content()
            }
        }
    }

    private func reportMetric(_ title: String, _ value: String, _ subtitle: String, _ icon: String, _ tint: Color) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(tint)
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }

    private func recommendationRow(_ recommendation: FleetReportRecommendation) -> some View {
        reportListRow(
            icon: recommendation.iconName,
            tint: recommendation.severity.color,
            title: recommendation.title,
            subtitle: recommendation.detail,
            trailing: recommendation.severity.rawValue
        )
    }

    private func maintenanceRow(_ row: MaintenanceReportRow) -> some View {
        reportListRow(
            icon: "car.side.fill",
            tint: row.severity.color,
            title: "\(row.vehicleName) - \(row.plateNumber)",
            subtitle: "\(serviceDueText(row.daysToService)) | \(row.openWorkOrders) open | \(row.unresolvedDefects) defects | \(currency(row.estimatedCost))",
            trailing: row.severity.rawValue
        )
    }

    private func sparePartForecastRow(_ row: SparePartForecastReport) -> some View {
        let whenText = row.orderByDate?.formatted(date: .abbreviated, time: .omitted) ?? "Not required"
        return reportListRow(
            icon: "shippingbox.fill",
            tint: row.severity.color,
            title: row.name,
            subtitle: "\(row.onHand) on hand | order \(row.reorderQuantity) by \(whenText) | forecast \(String(format: "%.1f", row.forecastMonthlyUsage))/mo",
            trailing: row.reorderQuantity > 0 ? "Order \(row.reorderQuantity)" : row.severity.rawValue
        )
    }

    private func fuelVehicleRow(_ row: FuelVehicleReport) -> some View {
        reportListRow(
            icon: "fuelpump.fill",
            tint: row.severity.color,
            title: "\(row.vehicleName) - \(row.plateNumber)",
            subtitle: "\(fuelText(row.consumption)) vs \(fuelText(row.benchmark)) target | save \(Int(row.potentialLitresSaved.rounded())) L/mo",
            trailing: row.severity.rawValue
        )
    }

    private func complianceAlertRow(_ alert: ComplianceAlertReport) -> some View {
        let dateText = alert.dueDate?.formatted(date: .abbreviated, time: .omitted) ?? "No document"
        return reportListRow(
            icon: "doc.text.fill",
            tint: alert.severity.color,
            title: "\(alert.documentType.rawValue) - \(alert.plateNumber)",
            subtitle: "\(alert.vehicleName) | \(alert.status) | \(dateText)",
            trailing: alert.severity.rawValue
        )
    }

    private func routeRow(_ row: RouteOptimizationReport) -> some View {
        reportListRow(
            icon: "map.fill",
            tint: row.severity.color,
            title: row.routeName,
            subtitle: "\(row.tripCount) trips | \(Int(row.averageDistance.rounded())) km avg | \(row.assignedVehicleCount) vehicles",
            trailing: row.severity.rawValue
        )
    }

    private func reportListRow(icon: String, tint: Color, title: String, subtitle: String, trailing: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text(trailing)
                .font(.caption2.weight(.bold))
                .foregroundStyle(tint)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(tint.opacity(0.12), in: Capsule())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func generateReport(exportPDF: Bool) async {
        isLoading = true
        loadMessage = nil
        await appViewModel.service.syncWithDatabase()
        let remoteLoaded = await loadRemoteInputs()

        guard remoteLoaded else {
            snapshot = nil
            isLoading = false
            return
        }

        let snapshot = reportService.generateFleetSnapshot(
            vehicles: appViewModel.service.vehicles,
            trips: appViewModel.service.trips,
            workOrders: appViewModel.service.workOrders,
            defects: appViewModel.service.defects,
            documents: appViewModel.service.documents,
            maintenanceSchedules: appViewModel.service.maintenanceSchedules,
            spareParts: spareParts,
            fuelReceipts: appViewModel.service.fuelReceipts,
            fuelTransactions: fuelTransactions
        )
        self.snapshot = snapshot
        publishComplianceAlertsIfNeeded(snapshot.compliance.alerts)

        if exportPDF {
            let orgName = appViewModel.currentOrganization?.name ?? "Fleet"
            if let pdfURL = FleetReportPDFGenerator().generate(snapshot: snapshot, organizationName: orgName) {
                generatedPDFURL = pdfURL
                showShareSheet = true
                loadMessage = "PDF report generated from live database records."
            } else {
                loadMessage = "Report generated, but PDF export failed."
            }
        }

        isLoading = false
    }

    @discardableResult
    private func loadRemoteInputs() async -> Bool {
        guard SupabaseConfig.isConfigured else {
            loadMessage = "Reports require Supabase. Configure the database to load actual fleet numbers."
            spareParts = []
            fuelTransactions = []
            return false
        }

        guard let orgID = appViewModel.currentOrganization?.id else {
            loadMessage = "Organization not found. Sign in again to generate reports."
            return false
        }

        do {
            spareParts = try await SupabaseService.shared.fetchSpareParts(organizationID: orgID)
        } catch {
            loadMessage = "Could not load spare parts inventory from the database."
            spareParts = []
            return false
        }

        do {
            let repo = FuelRepository(service: FuelService(client: SupabaseService.shared.client))
            fuelTransactions = try await repo.allTransactions()
        } catch {
            loadMessage = "Could not load fuel transactions from the database."
            fuelTransactions = []
            return false
        }

        return true
    }

    private func publishComplianceAlertsIfNeeded(_ alerts: [ComplianceAlertReport]) {
        let today = Date.now.formatted(.dateTime.year().month().day())
        var fired = Set(UserDefaults.standard.stringArray(forKey: "fleetReportComplianceAlertsFired") ?? [])
        let actionable = alerts.filter { $0.severity == .critical || $0.severity == .action }

        for alert in actionable.prefix(12) {
            let key = "\(today)-\(alert.alertKey)"
            guard !fired.contains(key) else { continue }
            fired.insert(key)
            appViewModel.service.addNotification(
                userID: nil,
                roleTarget: .fleetManager,
                title: "\(alert.documentType.rawValue) \(alert.status)",
                message: "\(alert.vehicleName) (\(alert.plateNumber)) requires compliance review.",
                category: alert.severity == .critical ? .critical : .warning
            )
        }

        UserDefaults.standard.set(Array(fired.suffix(200)), forKey: "fleetReportComplianceAlertsFired")
    }

    private func currency(_ value: Double) -> String {
        value.formatted(.currency(code: "INR").precision(.fractionLength(0)))
    }

    private func fuelText(_ value: Double) -> String {
        value > 0 ? "\(String(format: "%.1f", value)) L/100km" : "N/A"
    }

    private func serviceDueText(_ days: Int) -> String {
        if days < 0 { return "\(abs(days)) days overdue" }
        if days == 0 { return "Due today" }
        return "\(days) days to service"
    }
}

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private enum ReportSection: String, CaseIterable, Identifiable {
    case overview = "Overview"
    case maintenance = "Maintenance"
    case inventory = "Inventory"
    case fuel = "Fuel"
    case compliance = "Compliance"
    case routing = "Routing"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .overview: return "chart.bar.fill"
        case .maintenance: return "wrench.and.screwdriver.fill"
        case .inventory: return "shippingbox.fill"
        case .fuel: return "fuelpump.fill"
        case .compliance: return "doc.text.fill"
        case .routing: return "map.fill"
        }
    }
}

private extension FleetReportSeverity {
    var color: Color {
        switch self {
        case .normal: return AppTheme.success
        case .watch: return Color(UIColor.systemBlue)
        case .action: return AppTheme.warning
        case .critical: return AppTheme.error
        }
    }
}

#Preview {
    NavigationStack {
        FleetReportsAnalyticsView()
            .environment(AppViewModel())
    }
}
