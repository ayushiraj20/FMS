import SwiftUI

struct MaintenanceReportsView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var report: MaintenanceReportSummary?
    @State private var generatedAt: Date?
    @State private var isLoading = false
    @State private var loadMessage: String?
    @State private var generatedReportURL: URL?
    @State private var showReportShareSheet = false

    private let reportService = FleetReportService()
    private var currentUser: User? { appViewModel.currentUser }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if isLoading && report == nil {
                    LoadingStateView(title: "Generating maintenance report...")
                        .frame(height: 260)
                } else if let report {
                    reportContent(report)
                } else {
                    EmptyStateView(
                        icon: "doc.text.magnifyingglass",
                        title: "No maintenance report",
                        message: "Generate a report to review assigned work orders, cost, overdue jobs, and vehicle risk."
                    )
                }

                if let loadMessage {
                    Label(loadMessage, systemImage: "info.circle.fill")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .padding(16)
            .padding(.bottom, 20)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Reports")
        .navigationBarTitleDisplayMode(.large)

        .task {
            if report == nil {
                await generateMaintenanceSummary()
            }
        }
        .refreshable {
            await generateMaintenanceSummary()
        }
        .sheet(isPresented: $showReportShareSheet, onDismiss: { generatedReportURL = nil }) {
            if let generatedReportURL {
                ShareSheet(items: [generatedReportURL])
                    .registersSheetPresentation()
            }
        }
        .hidesTabBarWhileSheet(isPresented: showReportShareSheet)
    }

    private var header: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "wrench.and.screwdriver.fill")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(AppTheme.brand, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Maintenance Report")
                            .font(.title3.weight(.bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        
                        if let generatedAt {
                            HStack(spacing: 4) {
                                Text("Last Generated:")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(generatedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        } else {
                            Text("No report generated yet.")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
                
                Button {
                    Task { await generateReportAndPDF() }
                } label: {
                    HStack {
                        Spacer()
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Label("Generate Report", systemImage: "doc.badge.gearshape.fill")
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.brand)
                .controlSize(.large)
                .buttonBorderShape(.capsule)
                .disabled(isLoading)
            }
        }
    }

    private func reportContent(_ report: MaintenanceReportSummary) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                maintenanceMetric("Assigned", "\(report.totalWorkOrders)", "\(report.openWorkOrders) open", "list.clipboard.fill", .blue)
                maintenanceMetric("Critical", "\(report.criticalWorkOrders)", "\(report.overdueWorkOrders) overdue", "exclamationmark.triangle.fill", report.criticalWorkOrders > 0 ? AppTheme.error : AppTheme.success)
                maintenanceMetric("Completed", "\(report.completedWorkOrders)", "Closed jobs", "checkmark.seal.fill", AppTheme.success)
                maintenanceMetric("Est. Cost", currency(report.totalEstimatedCost), "Avg \(currency(report.averageEstimatedCost))", "indianrupeesign.circle.fill", AppTheme.warning)
            }

            GlassCard {
                VStack(alignment: .leading, spacing: 14) {
                    Label("Vehicle Maintenance Report", systemImage: "wrench.and.screwdriver.fill")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)

                    if report.rows.isEmpty {
                        EmptyStateView(
                            icon: "checkmark.seal.fill",
                            title: "No assigned vehicle risk",
                            message: "Your assigned queue does not currently show active maintenance risk."
                        )
                    } else {
                        VStack(spacing: 10) {
                            ForEach(report.rows.prefix(20)) { row in
                                maintenanceRiskRow(row)
                            }
                        }
                    }
                }
            }
        }
    }

    private func maintenanceMetric(_ title: String, _ value: String, _ subtitle: String, _ icon: String, _ tint: Color) -> some View {
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

    private func maintenanceRiskRow(_ row: MaintenanceReportRow) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "car.side.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(row.severity.maintenanceColor)
                .frame(width: 32, height: 32)
                .background(row.severity.maintenanceColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("\(row.vehicleName) - \(row.plateNumber)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("\(serviceDueText(row.daysToService)) | \(row.openWorkOrders) open | \(row.unresolvedDefects) defects")
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(row.recommendation)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Text(row.severity.rawValue)
                .font(.caption2.weight(.bold))
                .foregroundStyle(row.severity.maintenanceColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(row.severity.maintenanceColor.opacity(0.12), in: Capsule())
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
    }

    private func generateMaintenanceSummary() async {
        isLoading = true
        loadMessage = nil
        await appViewModel.service.syncDefectsAndWorkOrders()
        report = reportService.generateMaintenanceSummary(
            vehicles: appViewModel.service.vehicles,
            workOrders: appViewModel.service.workOrders,
            defects: appViewModel.service.defects,
            schedules: appViewModel.service.maintenanceSchedules,
            assignedMaintenanceID: currentUser?.role == .maintenance ? currentUser?.id : nil
        )
        generatedAt = .now
        isLoading = false
    }

    private func generateReportAndPDF() async {
        isLoading = true
        loadMessage = nil
        await appViewModel.service.syncDefectsAndWorkOrders()
        report = reportService.generateMaintenanceSummary(
            vehicles: appViewModel.service.vehicles,
            workOrders: appViewModel.service.workOrders,
            defects: appViewModel.service.defects,
            schedules: appViewModel.service.maintenanceSchedules,
            assignedMaintenanceID: currentUser?.role == .maintenance ? currentUser?.id : nil
        )
        generatedAt = .now

        guard let parts = await loadInventoryPartsForReport() else {
            isLoading = false
            return
        }

        guard !parts.isEmpty else {
            loadMessage = "No spare parts inventory found for the PDF report."
            isLoading = false
            return
        }

        let reportID = UUID()
        let document = InventoryReportBuilder.makeDocument(
            parts: parts,
            organizationName: appViewModel.currentOrganization?.name ?? "Fleet",
            generatedBy: appViewModel.currentUser?.name ?? "Maintenance",
            reportID: reportID
        )

        guard let pdfURL = InventoryReportPDFGenerator().generate(document: document) else {
            loadMessage = "Report generated, but PDF export failed."
            isLoading = false
            return
        }

        GeneratedReportStore.shared.register(reportID: reportID, url: pdfURL)
        generatedReportURL = pdfURL
        showReportShareSheet = true

        appViewModel.service.addNotification(
            userID: nil,
            roleTarget: .fleetManager,
            title: "Inventory Report Ready",
            message: "Maintenance generated an inventory reorder report. Urgent items: \(document.urgentCount). Medium priority: \(document.mediumCount). Report ID: \(reportID.uuidString)",
            category: document.urgentCount > 0 ? .warning : .maintenance
        )

        await appViewModel.loadNotifications()
        loadMessage = "Inventory PDF generated and sent to fleet manager."
        isLoading = false
    }

    private func loadInventoryPartsForReport() async -> [SparePart]? {
        guard SupabaseConfig.isConfigured else {
            loadMessage = "Inventory PDF reports require Supabase inventory records."
            return nil
        }

        guard let orgID = appViewModel.currentOrganization?.id else {
            loadMessage = "Organization not found. Sign in again to generate reports."
            return nil
        }

        do {
            return try await SupabaseService.shared.fetchSpareParts(organizationID: orgID)
        } catch {
            loadMessage = "Could not load spare parts inventory from the database."
            return nil
        }
    }

    private func currency(_ value: Double) -> String {
        value.formatted(.currency(code: "INR").precision(.fractionLength(0)))
    }

    private func serviceDueText(_ days: Int) -> String {
        if days < 0 { return "\(abs(days)) days overdue" }
        if days == 0 { return "Due today" }
        return "\(days) days to service"
    }
}

private extension FleetReportSeverity {
    var maintenanceColor: Color {
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
        MaintenanceReportsView()
            .environment(AppViewModel())
    }
}
