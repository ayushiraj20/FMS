import SwiftUI
import Charts

// MARK: - Defects Board (Fleet Manager)

struct DefectReportsListView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var selectedDefect: DefectReport?
    @State private var filterTab: FilterOption = .all
    @State private var isLoading = false

    enum FilterOption: String, CaseIterable, Identifiable {
        case all = "All"
        case pending = "Pending"
        case approved = "Approved"
        case inRepair = "In Repair"
        case completed = "Completed"
        var id: String { rawValue }
    }

    private var filteredDefects: [DefectReport] {
        let all = appViewModel.service.defects.sorted { $0.reportedDate > $1.reportedDate }
        if filterTab == .all { return all }
        return all.filter { defect in
            switch filterTab {
            case .pending:   return defect.status == .pending
            case .approved:  return defect.status == .approved
            case .inRepair:  return defect.status == .inRepair
            case .completed: return defect.status == .completed
            case .all:       return true
            }
        }
    }

    private var issueSummaries: [DefectIssueSummary] {
        DefectIssueType.allCases.enumerated().map { index, issueType in
            DefectIssueSummary(
                issueType: issueType,
                count: appViewModel.service.defects.filter { defectIssueType(for: $0) == issueType }.count,
                color: chartColor(at: index)
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Pull-to-refresh status indicator
            if isLoading {
                HStack(spacing: 8) {
                    ProgressView()
                        .tint(AppTheme.brand)
                        .scaleEffect(0.8)
                    Text("Syncing defects…")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }
                .padding(.vertical, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {

                    ForEach(FilterOption.allCases) { option in

                        Button {

                            withAnimation(.snappy(duration: 0.18)) {
                                filterTab = option
                            }

                        } label: {

                            Text("\(option.rawValue) \(defectCount(for: option))")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(
                                    filterTab == option
                                    ? .white
                                    : AppTheme.textPrimary
                                )
                                .padding(.horizontal, 18)
                                .padding(.vertical, 12)
                                .background(
                                    filterTab == option
                                    ? Color("AccentColor")
                                    : AppTheme.surfaceSecondary,
                                    in: Capsule()
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal,20)
                .padding(.vertical,10)
            }

            if !appViewModel.service.defects.isEmpty {
                defectIssueChart
                    .padding(.horizontal, 20)
                    .padding(.bottom, 10)
            }

            Divider()
                .background(AppTheme.border)

            if filteredDefects.isEmpty {
                Spacer()
                EmptyStateView(
                    icon: filterTab == .pending ? "exclamationmark.triangle" : "checkmark.circle",
                    title: "No \(filterTab.rawValue.lowercased()) defects",
                    message: filterTab == .pending
                        ? "Drivers haven't submitted any new defect reports yet."
                        : "No defects match this filter category."
                )
                .padding(.horizontal, 20)
                Spacer()
            } else {
                List {
                    ForEach(filteredDefects) { defect in
                        DefectCard(defect: defect) {
                            selectedDefect = defect
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 6, leading: 20, bottom: 6, trailing: 20))
                    }
                }
                .listStyle(.plain)
                .refreshable {
                    await refreshDefects()
                }
            }
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Defect Reports")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await refreshDefects() }
                } label: {
                    if isLoading {
                        ProgressView().tint(AppTheme.brand)
                    } else {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(AppTheme.brand)
                    }
                }
            }
        }
        .task {
            // Auto-sync from Supabase whenever this view appears
            await refreshDefects()
        }
        .sheet(item: $selectedDefect) { defect in
            DefectReviewSheet(defect: defect)
                .environment(appViewModel)
                .registersSheetPresentation()
        }
        .animation(.easeInOut(duration: 0.25), value: isLoading)
    }

    // MARK: - Helpers

    private func refreshDefects() async {
        guard !isLoading else { return }
        withAnimation { isLoading = true }
        await appViewModel.service.syncDefectsAndWorkOrders()
        withAnimation { isLoading = false }
    }

    private func defectCount(for option: FilterOption) -> Int {
        let all = appViewModel.service.defects
        switch option {
        case .all:       return all.count
        case .pending:   return all.filter { $0.status == .pending }.count
        case .approved:  return all.filter { $0.status == .approved }.count
        case .inRepair:  return all.filter { $0.status == .inRepair }.count
        case .completed: return all.filter { $0.status == .completed }.count
        }
    }

    private var defectIssueChart: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Issues by Part")
                    .font(.headline)
                    .foregroundStyle(AppTheme.textPrimary)

                Chart(issueSummaries) { summary in
                    BarMark(
                        x: .value("Vehicle Part", summary.issueType.rawValue),
                        y: .value("Reports", summary.count)
                    )
                    .foregroundStyle(summary.color)
                    .annotation(position: .top) {
                        if summary.count > 0 {
                            Text("\(summary.count)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
                .chartXAxisLabel("Vehicle part")
                .chartYAxisLabel("Reports")
                .chartYAxis {
                    AxisMarks(position: .leading, values: .automatic(desiredCount: 4))
                }
                .frame(height: 220)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 8)], alignment: .leading, spacing: 8) {
                    ForEach(issueSummaries.filter { $0.count > 0 }) { summary in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(summary.color)
                                .frame(width: 8, height: 8)
                            Text(summary.issueType.rawValue)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
            }
        }
    }

    private func defectIssueType(for defect: DefectReport) -> DefectIssueType {
        let text = "\(defect.title ?? "") \(defect.description)".lowercased()
        return DefectIssueType.allCases.first { issueType in
            text.contains("[\(issueType.rawValue.lowercased())]") ||
            text.contains(issueType.rawValue.lowercased())
        } ?? .other
    }

    private func chartColor(at index: Int) -> Color {
        [
            Color(UIColor.systemBlue),
            Color(UIColor.systemRed),
            Color(UIColor.systemGreen),
            Color(UIColor.systemYellow),
            Color(UIColor.systemPurple),
            Color(UIColor.systemTeal),
            Color(UIColor.systemPink),
            Color(UIColor.systemGray)
        ][index % 8]
    }
}

private struct DefectIssueSummary: Identifiable {
    let issueType: DefectIssueType
    let count: Int
    let color: Color

    var id: String { issueType.rawValue }
}

// MARK: - Defect Card

struct DefectCard: View {
    let defect: DefectReport
    let action: () -> Void
    @Environment(AppViewModel.self) private var appViewModel

    var body: some View {
        let vehicle = appViewModel.service.vehicle(for: defect.vehicleID)
        let driver = appViewModel.service.users().first { $0.id == defect.driverID }

        Button(action: action) {
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(defect.title ?? "Defect Report")
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                                .multilineTextAlignment(.leading)

                            HStack(spacing: 6) {
                                Image(systemName: "truck.box")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(vehicle?.displayName ?? "Unknown Vehicle")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text("•")
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(vehicle?.plateNumber ?? "No Plate")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                        Spacer()

                        VStack(alignment: .trailing, spacing: 6) {
                            StatusBadgeView(
                                text: defect.severity.rawValue,
                                color: severityColor(defect.severity)
                            )
                            StatusBadgeView(
                                text: defect.status.rawValue,
                                color: statusColor(defect.status)
                            )
                        }
                    }

                    if !defect.description.isEmpty {
                        Text(defect.description)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Reported by")
                                .font(.system(size: 10))
                                .foregroundStyle(AppTheme.textSecondary)
                            HStack(spacing: 4) {
                                Image(systemName: "person.circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.brand)
                                Text(driver?.name ?? "Unknown Driver")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                        }

                        Spacer()

                        Text(formattedDate(defect.reportedDate))
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    if let imgs = defect.images, !imgs.isEmpty {
                        HStack(spacing: 8) {
                            ForEach(imgs.prefix(3), id: \.self) { imgURL in
                                AsyncImage(url: URL(string: imgURL)) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 44, height: 44)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    case .failure:
                                        Image(systemName: "photo.fill")
                                            .font(.title3)
                                            .foregroundStyle(AppTheme.brand.opacity(0.3))
                                            .frame(width: 44, height: 44)
                                            .background(AppTheme.surfaceSecondary)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    default:
                                        ProgressView()
                                            .frame(width: 44, height: 44)
                                            .background(AppTheme.surfaceSecondary)
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                }
                            }
                            if imgs.count > 3 {
                                Text("+\(imgs.count - 3)")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.surfaceSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                        }
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func severityColor(_ severity: WorkOrderPriority) -> Color {
        switch severity {
        case .low:      return AppTheme.success
        case .medium:   return AppTheme.brand
        case .high:     return AppTheme.warning
        case .critical: return AppTheme.error
        }
    }

    private func statusColor(_ status: DefectStatus) -> Color {
        switch status {
        case .pending:   return AppTheme.textSecondary
        case .approved:  return Color.blue
        case .inRepair:  return AppTheme.warning
        case .completed: return AppTheme.success
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Defect Review Sheet

struct DefectReviewSheet: View {
    let defect: DefectReport
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel

    @State private var priority: WorkOrderPriority = .medium
    @State private var selectedTechID: UUID?
    @State private var details: String = ""
    @State private var isShowingApprovalForm = false
    @State private var isShowingImageDetail = false
    @State private var selectedImageName: String?

    // Computed helpers — available throughout body without scope issues
    private var vehicle: Vehicle? {
        appViewModel.service.vehicle(for: defect.vehicleID)
    }
    private var driver: User? {
        appViewModel.service.users().first { $0.id == defect.driverID }
    }
    private var linkedWorkOrder: WorkOrder? {
        appViewModel.service.workOrders.first { $0.defectReportID == defect.id }
    }

    init(defect: DefectReport) {
        self.defect = defect
        _priority = State(initialValue: defect.severity)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: Vehicle Info
                    sectionHeader("Vehicle Details")
                    GlassCard {
                        HStack(spacing: 12) {
                            Image(systemName: "truck.box.fill")
                                .font(.title)
                                .foregroundStyle(AppTheme.brand)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vehicle?.displayName ?? "Unknown Vehicle")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text("Plate: \(vehicle?.plateNumber ?? "No Plate") • Odometer: \(vehicle?.odometer.formatted() ?? "0") km")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }

                    // MARK: Driver Info
                    sectionHeader("Driver Info")
                    GlassCard {
                        HStack(spacing: 12) {
                            Image(systemName: "person.crop.circle.fill")
                                .font(.title)
                                .foregroundStyle(AppTheme.brand)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(driver?.name ?? "Unknown Driver")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Text(driver?.title ?? "Professional Driver")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }

                    // MARK: Defect Details
                    sectionHeader("Defect Description")
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(defect.title ?? "Issue")
                                    .font(.system(size: 16, weight: .bold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 4) {
                                    StatusBadgeView(
                                        text: defect.severity.rawValue,
                                        color: severityColor(defect.severity)
                                    )
                                    StatusBadgeView(
                                        text: defect.status.rawValue,
                                        color: statusColor(defect.status)
                                    )
                                }
                            }
                            Text(defect.description)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                            Text("Reported on: \(formattedDate(defect.reportedDate))")
                                .font(.caption.italic())
                                .foregroundStyle(AppTheme.textSecondary)
                                .padding(.top, 4)
                        }
                    }

                    // MARK: Photos
                    if let imgs = defect.images, !imgs.isEmpty {
                        sectionHeader("Damage Photos")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(imgs, id: \.self) { img in
                                    Button {
                                        selectedImageName = img
                                        isShowingImageDetail = true
                                    } label: {
                                        ZStack(alignment: .bottom) {
                                            AsyncImage(url: URL(string: img)) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 120, height: 120)
                                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                                case .failure:
                                                    Image(systemName: "photo.fill")
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(width: 120, height: 120)
                                                        .foregroundStyle(AppTheme.brand.opacity(0.3))
                                                        .padding(12)
                                                        .background(AppTheme.surfaceSecondary)
                                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                                default:
                                                    ProgressView()
                                                        .frame(width: 120, height: 120)
                                                        .background(AppTheme.surfaceSecondary)
                                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                                }
                                            }

                                            Text("Expand")
                                                .font(.system(size: 10, weight: .bold))
                                                .foregroundStyle(.white)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 2)
                                                .background(Color.black.opacity(0.6))
                                                .clipShape(Capsule())
                                                .padding(.bottom, 6)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // MARK: Actions
                    if defect.status == .pending {
                        pendingActionsSection
                    } else {
                        linkedWorkOrderSection
                    }
                }
                .padding(20)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Review Defect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .sheet(isPresented: $isShowingImageDetail) {
                imageDetailSheet
            }
        }
    }

    // MARK: - Pending Actions Section

    @ViewBuilder
    private var pendingActionsSection: some View {
        if !isShowingApprovalForm {
            HStack(spacing: 16) {
                Button("Reject Report") {
                    appViewModel.service.rejectDefectReport(defect: defect)
                    dismiss()
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(AppTheme.error)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppTheme.error.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Button("Approve & Repair") {
                    withAnimation {
                        isShowingApprovalForm = true
                        if let firstTech = appViewModel.service.users(for: .maintenance).first {
                            selectedTechID = firstTech.id
                        }
                        let cleanDesc = defect.description.replacingOccurrences(
                            of: #"^\[.*?\]\s*"#, with: "", options: .regularExpression
                        )
                        details = "Please inspect and resolve: \(defect.title ?? "defect").\nDetails: \(cleanDesc)"
                    }
                }
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppTheme.brand)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.top, 10)
        } else {
            approvalConfigForm
        }
    }

    // MARK: - Approval Config Form

    private var approvalConfigForm: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()

            Text("Configure Work Order")
                .font(.title3.weight(.bold))
                .foregroundStyle(AppTheme.brand)

            // Priority Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Work Order Priority")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                Picker("Priority", selection: $priority) {
                    ForEach(WorkOrderPriority.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Tech Selection
            VStack(alignment: .leading, spacing: 8) {
                Text("Assign Technician")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                let techs = appViewModel.service.users(for: .maintenance)

                if techs.isEmpty {
                    Text("No maintenance technicians found. Please add technicians first.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.error)
                        .padding(10)
                        .background(AppTheme.error.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    Picker("Technician", selection: $selectedTechID) {
                        Text("Select Technician").tag(nil as UUID?)
                        ForEach(techs) { tech in
                            Text("\(tech.name) (\(tech.title))").tag(tech.id as UUID?)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            // Details Editor
            VStack(alignment: .leading, spacing: 8) {
                Text("Work Order Instructions")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)

                TextEditor(text: $details)
                    .frame(minHeight: 80)
                    .padding(10)
                    .background(AppTheme.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .scrollContentBackground(.hidden)
            }

            // Submit approval
            Button {
                guard let techID = selectedTechID else { return }
                let orderTitle = defect.title ?? "Repair: \(vehicle?.displayName ?? "Vehicle")"
                appViewModel.service.approveDefectReport(
                    defect: defect,
                    assignedTechID: techID,
                    title: orderTitle,
                    priority: priority,
                    details: details
                )
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "wrench.and.screwdriver.fill")
                    Text("Approve & Coordinate Repair")
                        .font(.headline)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(selectedTechID == nil ? AppTheme.textSecondary : AppTheme.brand)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(selectedTechID == nil)

            Button("Cancel Approval") {
                withAnimation {
                    isShowingApprovalForm = false
                }
            }
            .font(.subheadline)
            .foregroundStyle(AppTheme.textSecondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .padding()
        .background(AppTheme.surfaceSecondary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    // MARK: - Linked Work Order Section (non-pending)

    @ViewBuilder
    private var linkedWorkOrderSection: some View {
        if let wo = linkedWorkOrder {
            sectionHeader("Linked Work Order")
            GlassCard {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(wo.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                        StatusBadgeView(
                            text: wo.status.rawValue,
                            color: wo.status == .completed ? AppTheme.success : AppTheme.warning
                        )
                    }

                    if let tech = appViewModel.service.users(for: .maintenance)
                        .first(where: { $0.id == wo.assignedMaintenanceID }) {
                        Label("Technician: \(tech.name) (\(tech.title))", systemImage: "wrench.and.screwdriver")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    NavigationLink(
                        destination: WorkOrderChatView(workOrderID: wo.id)
                            .environment(appViewModel)
                            .hideTabBarOnPush()
                    ) {
                        HStack {
                            Image(systemName: "bubble.left.and.bubble.right.fill")
                            Text("Open Coordination Chat")
                        }
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(AppTheme.brand)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding(.top, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            GlassCard {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(defect.status == .completed ? AppTheme.success : AppTheme.brand)
                    Text(defect.status == .completed
                         ? "This defect report has been closed."
                         : "Work order will appear here once created.")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    // MARK: - Image Detail Sheet

    private var imageDetailSheet: some View {
        VStack {
            HStack {
                Spacer()
                Button("Dismiss") { isShowingImageDetail = false }
                    .font(.headline)
                    .foregroundStyle(AppTheme.brand)
                    .padding()
            }
            Spacer()
            if let urlString = selectedImageName, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .padding()
                    case .failure:
                        VStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(AppTheme.warning)
                            Text("Failed to load image")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    default:
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.5)
                            Text("Loading photo…")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .foregroundStyle(AppTheme.brand.opacity(0.4))
                        .padding()
                    Text("No image URL available")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            Spacer()
        }
        .background(AppTheme.background.ignoresSafeArea())
    }

    // MARK: - Helpers

    @ViewBuilder
    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(.headline)
            .foregroundStyle(AppTheme.textPrimary)
    }

    private func severityColor(_ severity: WorkOrderPriority) -> Color {
        switch severity {
        case .low:      return AppTheme.success
        case .medium:   return AppTheme.brand
        case .high:     return AppTheme.warning
        case .critical: return AppTheme.error
        }
    }

    private func statusColor(_ status: DefectStatus) -> Color {
        switch status {
        case .pending:   return AppTheme.textSecondary
        case .approved:  return Color.blue
        case .inRepair:  return AppTheme.warning
        case .completed: return AppTheme.success
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}


#Preview {
    NavigationStack {
        DefectReportsListView()
            .environment(AppViewModel())
    }

}
