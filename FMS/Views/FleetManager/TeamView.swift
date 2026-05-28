import SwiftUI
import Observation

// MARK: - Team View (Crew Management)
struct TeamView: View {
    @State private var viewModel: TeamViewModel
    @Environment(AppViewModel.self) private var appViewModel

    init(service: MockDataService, currentOrgID: UUID?) {
        _viewModel = State(wrappedValue: TeamViewModel(service: service, currentOrgID: currentOrgID))
    }

    enum CrewSegment: String, CaseIterable {
        case drivers = "Driver"
        case maintenance = "Maintenance Personnel"
    }

    @State private var selectedSegment: CrewSegment = .drivers

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // MARK: - Header
                VStack(spacing: 14) {
                    HStack {
                        Text("Crew Management")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(AppTheme.textPrimary)
                        Spacer()
                    }

                    // Search Bar
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(AppTheme.textSecondary)
                            .font(.system(size: 15))
                        TextField("Search crew members...", text: $viewModel.searchText)
                            .foregroundStyle(AppTheme.textPrimary)
                            .font(.system(size: 15))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(AppTheme.surfaceSecondary)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    // Segment Picker
                    Picker("Crew Segment", selection: $selectedSegment) {
                        ForEach(CrewSegment.allCases, id: \.self) { seg in
                            Text(seg.rawValue).tag(seg)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 16)
                .background(AppTheme.background)

                // MARK: - Content
                TabView(selection: $selectedSegment) {
                    DriversTabView(viewModel: viewModel)
                        .tag(CrewSegment.drivers)

                    MaintenanceTabContentView()
                        .tag(CrewSegment.maintenance)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
            }
            .background(AppTheme.background)
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .bottomTrailing) {
                Button {
                    viewModel.newRole = selectedSegment == .drivers ? .driver : .maintenance
                    viewModel.showAddMember = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(width: 56, height: 56)
                        .background(AppTheme.brand)
                        .clipShape(Circle())
                        .shadow(color: AppTheme.brand.opacity(0.35), radius: 10, y: 4)
                }
                .padding(.trailing, 24)
                .padding(.bottom, 24)
            }
            .sheet(isPresented: $viewModel.showAddMember) {
                AddTeamMemberSheet(viewModel: viewModel)
            }
            .confirmationDialog(
                "Delete Team Member",
                isPresented: $viewModel.isPresentingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) { viewModel.deleteConfirmed() }
                Button("Cancel", role: .cancel) { viewModel.memberToDelete = nil }
            } message: {
                if let m = viewModel.memberToDelete {
                    Text("Are you sure you want to delete \(m.name)? This cannot be undone.")
                }
            }
        }
    }
}

// MARK: - Drivers Tab
private struct DriversTabView: View {
    let viewModel: TeamViewModel

    private var drivers: [User] {
        let all = viewModel.service.users.filter { $0.role == .driver }
        guard !viewModel.searchText.isEmpty else { return all }
        return all.filter {
            $0.name.localizedCaseInsensitiveContains(viewModel.searchText) ||
            $0.title.localizedCaseInsensitiveContains(viewModel.searchText) ||
            $0.phone.localizedCaseInsensitiveContains(viewModel.searchText)
        }
    }

    private var totalCount: Int { viewModel.service.users.filter { $0.role == .driver }.count }

    private var availableCount: Int {
        viewModel.service.users.filter { $0.role == .driver }.filter { driver in
            !viewModel.service.vehicles.contains { $0.assignedDriverID == driver.id }
        }.count
    }

    private var assignedCount: Int {
        viewModel.service.users.filter { $0.role == .driver }.filter { driver in
            viewModel.service.vehicles.contains { $0.assignedDriverID == driver.id }
        }.count
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {

                // MARK: - Stat Cards
                HStack(spacing: 12) {
                    driverStatCard(title: "Total Drivers", value: "\(totalCount)", icon: "person.2.fill", tint: AppTheme.brand)
                    driverStatCard(title: "Available", value: "\(availableCount)", icon: "checkmark.circle.fill", tint: AppTheme.success)
                    driverStatCard(title: "Assigned", value: "\(assignedCount)", icon: "key.fill", tint: Color(hex: "#00a2ff"))
                }
                .padding(.horizontal, 20)

                // MARK: - Driver List
                VStack(alignment: .leading, spacing: 10) {
                    Text("All Drivers")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppTheme.textPrimary)
                        .padding(.horizontal, 20)

                    if drivers.isEmpty {
                        EmptyStateView(
                            icon: "person.slash",
                            title: "No drivers found",
                            message: viewModel.searchText.isEmpty
                                ? "Add drivers using the + button"
                                : "No results for \"\(viewModel.searchText)\""
                        )
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(drivers) { driver in
                                NavigationLink(destination: DriverDetailView(driver: driver, service: viewModel.service)) {
                                    DriverRowCard(driver: driver, service: viewModel.service)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }

                Spacer().frame(height: 100)
            }
            .padding(.top, 4)
        }
        .background(AppTheme.background)
        .refreshable {
            await viewModel.service.syncWithDatabase()
        }
    }

    private func driverStatCard(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(tint)
                Spacer()
            }
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppTheme.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 0.5)
        )
    }
}

// MARK: - Driver Row Card
private struct DriverRowCard: View {
    let driver: User
    let service: MockDataService

    private var assignedVehicle: Vehicle? {
        service.vehicles.first { $0.assignedDriverID == driver.id }
    }

    private var hasActiveTrip: Bool {
        service.trips.contains { $0.driverID == driver.id && $0.status == .inProgress }
    }

    private var dutyStatus: (String, Color) {
        if assignedVehicle != nil {
            return ("On Duty", AppTheme.success)
        }
        return ("Off Duty", Color(white: 0.55))
    }

    /// Driver activity status: only shown when On Duty
    /// - Idle: assigned to a vehicle but no active trip
    /// - Active: currently on an in-progress trip
    private var driverActivityStatus: (String, Color)? {
        guard assignedVehicle != nil else { return nil }
        if hasActiveTrip {
            return ("Active", AppTheme.success)
        } else {
            return ("Idle", AppTheme.warning)
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            ZStack {
                Circle()
                    .fill(AppTheme.brand.opacity(0.12))
                    .frame(width: 48, height: 48)
                Text(driver.name.prefix(1).uppercased())
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(AppTheme.brand)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(driver.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
            }

            Spacer()

            // Status pills
            VStack(alignment: .trailing, spacing: 5) {
                // On Duty / Off Duty
                HStack(spacing: 4) {
                    Circle()
                        .fill(dutyStatus.1)
                        .frame(width: 6, height: 6)
                    Text(dutyStatus.0)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(dutyStatus.1)
                }

                // Idle / Active (driver activity, not vehicle status)
                if let activity = driverActivityStatus {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(activity.1)
                            .frame(width: 6, height: 6)
                        Text(activity.0)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(activity.1)
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 0.5)
        )
    }
}

// MARK: - Driver Detail View (read-only, no assign/unassign)
private struct DriverDetailView: View {
    let driver: User
    let service: MockDataService

    private var assignedVehicle: Vehicle? {
        service.vehicles.first { $0.assignedDriverID == driver.id }
    }

    private var activeTrip: Trip? {
        service.trips.first { $0.driverID == driver.id && $0.status == .inProgress }
    }

    private var tripHistory: [Trip] {
        service.trips
            .filter { $0.driverID == driver.id && $0.status != .inProgress }
            .sorted { ($0.startDate) > ($1.startDate) }
    }

    private var isIdle: Bool {
        assignedVehicle != nil && activeTrip == nil
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {

                // Profile Card
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.brand.opacity(0.12))
                            .frame(width: 80, height: 80)
                        Text(driver.name.prefix(1).uppercased())
                            .font(.system(size: 32, weight: .bold))
                            .foregroundStyle(AppTheme.brand)
                    }
                    Text(driver.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)
                    Text(driver.title)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)
                    RoleBadgeView(role: driver.role)
                }
                .padding(.top, 8)

                // Contact Info
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        infoRow(icon: "envelope.fill", label: "Email", value: driver.email)
                        Divider()
                        infoRow(icon: "phone.fill", label: "Phone", value: driver.phone)
                    }
                }

                // Vehicle Assignment (read-only)
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Assigned Vehicle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .textCase(.uppercase)

                        if let vehicle = assignedVehicle {
                            HStack(spacing: 12) {
                                Image(systemName: "truck.box.fill")
                                    .font(.title3)
                                    .foregroundStyle(AppTheme.brand)
                                    .frame(width: 42, height: 42)
                                    .background(AppTheme.brand.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(vehicle.displayName)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text(vehicle.plateNumber)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer()
                                // Show driver activity status (not vehicle status)
                                StatusBadgeView(
                                    text: activeTrip != nil ? "Active" : "Idle",
                                    color: activeTrip != nil ? AppTheme.success : AppTheme.warning
                                )
                            }
                        } else {
                            HStack(spacing: 8) {
                                Image(systemName: "truck.box")
                                    .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
                                Text("No vehicle assigned")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                        }
                    }
                }

                // Active Trip
                if let trip = activeTrip {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Active Trip")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                                .textCase(.uppercase)
                            HStack(spacing: 8) {
                                Image(systemName: "location.fill")
                                    .foregroundStyle(AppTheme.brand)
                                Text(trip.origin)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Image(systemName: "arrow.right")
                                    .foregroundStyle(AppTheme.textSecondary)
                                    .font(.caption)
                                Text(trip.destination)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.textPrimary)
                            }
                            Text("\(Int(trip.distanceKM)) km")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }

                // Trip History
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Trip History")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .textCase(.uppercase)

                        if tripHistory.isEmpty {
                            HStack(spacing: 8) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(AppTheme.textSecondary.opacity(0.5))
                                Text("No past trips")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            .padding(.vertical, 4)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(tripHistory.enumerated()), id: \.element.id) { index, trip in
                                    VStack(spacing: 0) {
                                        if index > 0 {
                                            Divider()
                                                .padding(.vertical, 10)
                                        }
                                        tripHistoryRow(trip: trip)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 40)
        }
        .background(AppTheme.background)
        .navigationTitle("Driver Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.brand)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
                Text(value)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.textPrimary)
            }
            Spacer()
        }
    }

    private func tripHistoryRow(trip: Trip) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Status dot
            Circle()
                .fill(tripStatusColor(trip.status))
                .frame(width: 8, height: 8)
                .padding(.top, 5)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(trip.origin) → \(trip.destination)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                    Text(trip.status.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tripStatusColor(trip.status))
                }
                HStack(spacing: 8) {
                    Text(trip.startDate, style: .date)
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    Text("\(Int(trip.distanceKM)) km")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    if let score = trip.safetyScore {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        HStack(spacing: 3) {
                            Image(systemName: "shield.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(score >= 80 ? AppTheme.success : AppTheme.warning)
                            Text("\(score)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(score >= 80 ? AppTheme.success : AppTheme.warning)
                        }
                    }
                }
            }
        }
    }

    private func tripStatusColor(_ status: TripStatus) -> Color {
        switch status {
        case .completed:  return AppTheme.success
        case .cancelled:  return AppTheme.error
        case .scheduled:  return Color(hex: "#00a2ff")
        case .inProgress: return AppTheme.brand
        }
    }
}

// MARK: - Add Team Member Sheet
private struct AddTeamMemberSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: TeamViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Full Name", text: $viewModel.newName)
                        .disabled(viewModel.isCreating)
                    Picker("Role", selection: $viewModel.newRole) {
                        Text(UserRole.driver.rawValue).tag(UserRole.driver)
                        Text(UserRole.maintenance.rawValue).tag(UserRole.maintenance)
                    }
                    .disabled(viewModel.isCreating)
                    TextField("Email", text: $viewModel.newEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .disabled(viewModel.isCreating)
                    TextField("Phone", text: $viewModel.newPhone)
                        .keyboardType(.phonePad)
                        .disabled(viewModel.isCreating)
                    TextField("Job Title", text: $viewModel.newTitle)
                        .disabled(viewModel.isCreating)
                }

                if let error = viewModel.errorMessage {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(AppTheme.error)
                            Text(error)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.error)
                        }
                    }
                }

                Section {
                    Text("New accounts use the default password `demo123` for this demo.")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
            .navigationTitle("Add Team Member")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isCreating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            let success = await viewModel.createMember()
                            if success { dismiss() }
                        }
                    } label: {
                        if viewModel.isCreating {
                            ProgressView().tint(AppTheme.brand)
                        } else {
                            Text("Add")
                        }
                    }
                    .disabled(
                        viewModel.newName.isEmpty || viewModel.newEmail.isEmpty ||
                        viewModel.newPhone.isEmpty || viewModel.newTitle.isEmpty ||
                        viewModel.isCreating
                    )
                }
            }
        }
    }
}

// MARK: - Filter Enum (kept for compatibility)
enum TeamFilter: String, CaseIterable {
    case all = "All"
    case managers = "Managers"
    case drivers = "Drivers"
    case maintenance = "Maintenance"
    var displayName: String { rawValue }
}

// MARK: - Team View Model
@Observable
@MainActor
final class TeamViewModel {
    let service: MockDataService
    let currentOrgID: UUID?

    var searchText = ""
    var selectedFilter: TeamFilter = .all
    var showAddMember = false

    // Form fields
    var newName = ""
    var newEmail = ""
    var newPhone = ""
    var newTitle = ""
    var newRole: UserRole = .driver
    var isCreating = false
    var errorMessage: String?

    // Delete state
    var memberToDelete: User? = nil
    var isPresentingDeleteConfirmation = false

    init(service: MockDataService, currentOrgID: UUID?) {
        self.service = service
        self.currentOrgID = currentOrgID
    }

    func confirmDelete(_ member: User) {
        memberToDelete = member
        isPresentingDeleteConfirmation = true
    }

    func deleteConfirmed() {
        if let member = memberToDelete {
            service.deleteUser(member)
        }
        memberToDelete = nil
        isPresentingDeleteConfirmation = false
    }

    func createMember() async -> Bool {
        errorMessage = nil
        isCreating = true

        if service.users.contains(where: { $0.email.lowercased() == newEmail.lowercased() }) {
            errorMessage = "An account with this email already exists."
            isCreating = false
            return false
        }

        guard let orgID = currentOrgID else {
            errorMessage = "Organization not found."
            isCreating = false
            return false
        }

        do {
            try await service.addUser(
                name: newName,
                role: newRole,
                email: newEmail,
                phone: newPhone,
                title: newTitle,
                organizationID: orgID
            )
            resetForm()
            isCreating = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isCreating = false
            return false
        }
    }

    func resetForm() {
        newName = ""
        newEmail = ""
        newPhone = ""
        newTitle = ""
        newRole = .driver
        errorMessage = nil
    }
}

#Preview {
    NavigationStack {
        TeamView(service: MockDataService(), currentOrgID: UUID())
    }
}
