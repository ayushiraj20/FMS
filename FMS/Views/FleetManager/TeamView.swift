import SwiftUI
import Combine
import Observation

struct TeamView: View {
    @State private var viewModel: TeamViewModel

    init(service: MockDataService, currentOrgID: UUID?) {
        _viewModel = State(wrappedValue: TeamViewModel(service: service, currentOrgID: currentOrgID))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(spacing: 16) {
                    // MARK: - Custom Header
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("Team")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundStyle(.white)
                        
                        Text("\(viewModel.service.users.count) members")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color(white: 0.6))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(white: 0.2))
                            .clipShape(Capsule())
                        
                        Spacer()
                    }
                    .padding(.top, 10)
                    
                    // MARK: - Search Bar
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color(white: 0.6))
                        TextField("Search", text: $viewModel.searchText)
                            .foregroundStyle(.white)
                    }
                    .padding(12)
                    .background(Color(white: 0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // MARK: - Filter Chips
                    filterChips

                    // MARK: - Team Members List
                    if viewModel.filteredMembers.isEmpty {
                        EmptyStateView(
                            icon: "person.2.slash",
                            title: "No team members found",
                            message: "Try adjusting your search or filters."
                        )
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.filteredMembers) { member in
                                NavigationLink(destination: TeamMemberDetailView(member: member, service: viewModel.service)) {
                                    teamMemberCard(member)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100)
            }
            .background(AppTheme.background)
            .navigationBarHidden(true)
            
            // MARK: - Floating Add Button
            Button {
                viewModel.showAddMember = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(AppTheme.brand)
                    .clipShape(Circle())
                    .shadow(color: AppTheme.brand.opacity(0.4), radius: 10, y: 4)
            }
            .padding(.trailing, 24)
            .padding(.bottom, 24)
        }
        .sheet(isPresented: $viewModel.showAddMember) {
            AddTeamMemberSheet(viewModel: viewModel)
        }
    }

    // MARK: - Filter Chips
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TeamFilter.allCases, id: \.self) { filter in
                    FilterChipView(
                        title: filter.displayName,
                        isSelected: viewModel.selectedFilter == filter
                    ) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Team Member Card
    private func teamMemberCard(_ member: User) -> some View {
        VStack(spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                // Profile Avatar
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundStyle(Color(white: 0.6), Color(white: 0.9))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(member.name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.black)
                    
                    Text(member.role.rawValue.capitalized)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppTheme.brand)
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                // Status
                let statusInfo = memberStatus(member)
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusInfo.1)
                        .frame(width: 6, height: 6)
                    Text(statusInfo.0)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(statusInfo.1)
                }
            }
            
            HStack(alignment: .bottom) {
                Text(getVehiclePlate(for: member))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.black)
                
                Spacer()
                
                // Actions
                HStack(spacing: 12) {
                    Button(action: {}) {
                        Image(systemName: "phone")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.black)
                            .frame(width: 36, height: 36)
                            .background(Color(white: 0.95))
                            .clipShape(Circle())
                    }
                    Button(action: {}) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.black)
                            .frame(width: 36, height: 36)
                            .background(Color(white: 0.95))
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(16)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private func getVehiclePlate(for member: User) -> String {
        if let vid = member.assignedVehicleID, let vehicle = viewModel.service.vehicle(for: vid) {
            return vehicle.plateNumber
        }
        return "Unassigned"
    }

    // MARK: - Status Badge
    private func statusBadge(for member: User) -> some View {
        let (text, color) = memberStatus(member)
        return StatusBadgeView(text: text, color: color)
    }

    // MARK: - Role Tags
    @ViewBuilder
    private func roleTags(for member: User) -> some View {
        switch member.role {
        case .driver:
            TagView(text: "Driver", color: AppTheme.brand)
            if member.assignedVehicleID != nil {
                TagView(text: "Assigned", color: AppTheme.success)
            }
        case .maintenance:
            TagView(text: "Technician", color: .purple)
        case .fleetManager:
            TagView(text: "Manager", color: AppTheme.brand)
        }
    }

    // MARK: - Member Status Logic
    private func memberStatus(_ member: User) -> (String, Color) {
        if member.role == .driver {
            if member.assignedVehicleID != nil {
                return ("On Duty", AppTheme.success)
            } else {
                return ("Off Duty", Color(white: 0.5))
            }
        } else if member.role == .maintenance {
            let hasActiveWork = viewModel.service.workOrders.contains {
                $0.assignedMaintenanceID == member.id && $0.status != .completed
            }
            return hasActiveWork ? ("On Duty", AppTheme.success) : ("Off Duty", Color(white: 0.5))
        }
        return ("Active", AppTheme.success)
    }
}

// MARK: - Team Member Detail View
private struct TeamMemberDetailView: View {
    let member: User
    let service: MockDataService

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Card
                VStack(spacing: 12) {
                    AvatarView(name: member.name, size: 80)

                    Text(member.name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.textPrimary)

                    Text(member.title)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)

                    RoleBadgeView(role: member.role)
                }
                .padding(.top, 8)

                // Contact Info
                GlassCard {
                    VStack(alignment: .leading, spacing: 12) {
                        contactRow(icon: "envelope.fill", label: "Email", value: member.email)
                        Divider()
                        contactRow(icon: "phone.fill", label: "Phone", value: member.phone)
                    }
                }

                // Assignment Info
                if member.role == .driver {
                    driverAssignmentSection
                }

                if member.role == .maintenance {
                    maintenanceAssignmentSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(AppTheme.background)
        .navigationTitle("Member Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func contactRow(icon: String, label: String, value: String) -> some View {
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

    private var driverAssignmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Current Assignment", subtitle: "Vehicle and trip details")

            if let vehicleID = member.assignedVehicleID,
               let vehicle = service.vehicle(for: vehicleID) {
                GlassCard {
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
                        StatusBadgeView(text: vehicle.status.rawValue, color: vehicle.status == .active ? AppTheme.success : AppTheme.warning)
                    }
                }
            } else {
                GlassCard {
                    HStack {
                        Text("Unassigned")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                        Spacer()
                        Button("Assign Driver") {}
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(AppTheme.brand))
                    }
                }
            }
        }
    }

    private var maintenanceAssignmentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Active Work Orders", subtitle: "Currently assigned maintenance tasks")

            let activeOrders = service.workOrders.filter {
                $0.assignedMaintenanceID == member.id && $0.status != .completed
            }

            if activeOrders.isEmpty {
                EmptyStateView(icon: "checkmark.circle", title: "No active orders", message: "All assigned work is complete.")
            } else {
                ForEach(activeOrders) { order in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(order.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                priorityBadge(order.priority)
                            }
                            Text(order.details)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(2)
                            StatusBadgeView(text: order.status.rawValue, color: order.status == .inProgress ? AppTheme.brand : AppTheme.warning)
                        }
                    }
                }
            }
        }
    }

    private func priorityBadge(_ priority: WorkOrderPriority) -> some View {
        Text(priority.rawValue)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(priorityColor(priority))
            )
    }

    private func priorityColor(_ priority: WorkOrderPriority) -> Color {
        switch priority {
        case .low: return AppTheme.success
        case .medium: return AppTheme.brand
        case .high: return AppTheme.warning
        case .critical: return AppTheme.error
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
                    Text("New accounts use the default password `demo123` for this academic demo.")
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
                    .disabled(viewModel.newName.isEmpty || viewModel.newEmail.isEmpty || viewModel.newPhone.isEmpty || viewModel.newTitle.isEmpty || viewModel.isCreating)
                }
            }
        }
    }
}

// MARK: - Filter Enum
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

    init(service: MockDataService, currentOrgID: UUID?) {
        self.service = service
        self.currentOrgID = currentOrgID
    }

    var filteredMembers: [User] {
        var members = service.users

        if !searchText.isEmpty {
            members = members.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.email.localizedCaseInsensitiveContains(searchText) ||
                $0.title.localizedCaseInsensitiveContains(searchText)
            }
        }

        switch selectedFilter {
        case .all:
            break
        case .managers:
            members = service.users.filter { $0.role == .fleetManager }
        case .drivers:
            members = members.filter { $0.role == .driver }
        case .maintenance:
            members = members.filter { $0.role == .maintenance }
        }

        return members
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

    private func memberIsAvailable(_ user: User) -> Bool {
        if user.role == .driver {
            return user.assignedVehicleID == nil
        } else if user.role == .maintenance {
            return !service.workOrders.contains { $0.assignedMaintenanceID == user.id && $0.status != .completed }
        }
        return true
    }

    private func memberIsOnShift(_ user: User) -> Bool {
        if user.role == .driver {
            return user.assignedVehicleID != nil
        } else if user.role == .maintenance {
            return service.workOrders.contains { $0.assignedMaintenanceID == user.id && $0.status != .completed }
        }
        return false
    }
}

#Preview {
    NavigationStack {
        TeamView(service: MockDataService(), currentOrgID: UUID())
    }
}
