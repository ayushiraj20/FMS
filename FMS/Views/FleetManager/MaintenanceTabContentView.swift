import SwiftUI

// MARK: - Maintenance Personnel Tab (inside Crew → Maintenance Personnel)
struct MaintenanceTabContentView: View {
    @Environment(AppViewModel.self) private var appViewModel

    enum DutyFilter: String, CaseIterable {
        case all       = "All"
        case available = "Available"
        case busy      = "Busy"
        case offDuty   = "Off Duty"
    }

    @State private var dutyFilter: DutyFilter = .all
    @State private var showAddSheet = false

    private var maintenancePersonnel: [User] {
        appViewModel.service.users.filter { $0.role == .maintenance }
    }

    private var filtered: [User] {
        switch dutyFilter {
        case .all:       return maintenancePersonnel
        case .available: return maintenancePersonnel.filter { status(for: $0).0 == "Available" }
        case .busy:      return maintenancePersonnel.filter { status(for: $0).0 == "Busy" }
        case .offDuty:   return maintenancePersonnel.filter { status(for: $0).0 == "Off Duty" }
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // MARK: – Status filter chips
                    filterChipBar
                        .padding(.top, 4)

                    // MARK: – Personnel cards
                    if filtered.isEmpty {
                        EmptyStateView(
                            icon: "person.2.slash",
                            title: "No maintenance personnel found",
                            message: "Add new crew members or try different filters"
                        )
                        .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 14) {
                            ForEach(filtered) { member in
                                NavigationLink(
                                    destination: MaintenanceMemberDetailView(
                                        member: member,
                                        service: appViewModel.service
                                    ).hideTabBarOnPush()
                                ) {
                                    maintenanceMemberCard(member)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 100) // room for FAB
            }
            .background(AppTheme.background)
            .refreshable {
                await appViewModel.service.syncWithDatabase()
            }
            .task {
                await appViewModel.service.syncDefectsAndWorkOrders()
            }


        }
        .sheet(isPresented: $showAddSheet) {
            AddMaintenanceMemberSheet(service: appViewModel.service,
                                     orgID: appViewModel.currentOrganization?.id)
                .registersSheetPresentation()
        }
    }

    // MARK: – Filter Chips
    private var filterChipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(DutyFilter.allCases, id: \.self) { filter in
                    let isSelected = dutyFilter == filter
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                            dutyFilter = filter
                        }
                    } label: {
                        Text(filter.rawValue)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 9)
                            .background {
                                Capsule()
                                    .fill(isSelected ? AppTheme.brand : AppTheme.surfaceSecondary)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: – Member Card
    private func maintenanceMemberCard(_ member: User) -> some View {
        let (statusText, statusColor) = status(for: member)
        let activeOrders = appViewModel.service.workOrders.filter {
            $0.assignedMaintenanceID == member.id && $0.status != .completed
        }
        let empCode = "MT-\(abs(member.id.hashValue % 900) + 100)"

        return GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                // Top row
                HStack(alignment: .top, spacing: 14) {
                    // Avatar
                    AvatarView(name: member.name, size: 48)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(member.name)
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text(member.title)
                            .font(.caption)
                            .foregroundStyle(AppTheme.textSecondary)
                        Text(empCode)
                            .font(.caption.monospaced())
                            .foregroundStyle(AppTheme.textSecondary.opacity(0.7))
                    }

                    Spacer()

                    // Status pill
                    HStack(spacing: 5) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 7, height: 7)
                        Text(statusText)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(statusColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(statusColor.opacity(0.12))
                    .clipShape(Capsule())
                }

                Divider().background(AppTheme.border)

                // Work order info row
                HStack(spacing: 16) {
                    infoChip(
                        icon: "wrench.and.screwdriver.fill",
                        value: "\(activeOrders.count)",
                        label: "Active Orders",
                        color: activeOrders.isEmpty ? AppTheme.success : AppTheme.warning
                    )

                    infoChip(
                        icon: "phone.fill",
                        value: member.phone,
                        label: "Contact",
                        color: AppTheme.brand
                    )

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.textSecondary)
                }
            }
        }
    }

    private func infoChip(icon: String, value: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.textPrimary)
                    .lineLimit(1)
                Text(label)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(AppTheme.textSecondary)
            }
        }
    }

    // MARK: – Status logic
    private func status(for member: User) -> (String, Color) {
        let hasActive = appViewModel.service.workOrders.contains {
            $0.assignedMaintenanceID == member.id && $0.status != .completed
        }
        if hasActive {
            return ("Busy", AppTheme.warning)
        }
        // Simplified: all maintenance staff who aren't on active orders are "Available"
        return ("Available", AppTheme.success)
    }
}

// MARK: - Maintenance Member Detail View
struct MaintenanceMemberDetailView: View {
    let member: User
    let service: MockDataService
    @Environment(\.dismiss) private var dismiss

    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var isDeleted = false

    private var currentMember: User {
        service.users.first { $0.id == member.id } ?? member
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Profile Hero Card
                GlassCard {
                    VStack(spacing: 14) {
                        AvatarView(name: currentMember.name, size: 80)

                        VStack(spacing: 4) {
                            Text(currentMember.name)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(currentMember.title)
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }

                        HStack(spacing: 12) {
                            // Call button
                            Button {
                                if let url = URL(string: "tel://\(currentMember.phone.replacingOccurrences(of: " ", with: ""))") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Label("Call", systemImage: "phone.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(AppTheme.success, in: Capsule())
                            }

                            // Email button
                            Button {
                                if let url = URL(string: "mailto:\(currentMember.email)") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Label("Email", systemImage: "envelope.fill")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.brand)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 10)
                                    .background(AppTheme.brand.opacity(0.12), in: Capsule())
                                    .overlay(Capsule().strokeBorder(AppTheme.brand.opacity(0.3), lineWidth: 1))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }

                // Contact Info
                GlassCard {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("CONTACT INFO")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)

                        contactRow(icon: "phone.fill", label: "Phone", value: currentMember.phone)
                        Divider().background(AppTheme.border)
                        contactRow(icon: "envelope.fill", label: "Email", value: currentMember.email)
                    }
                }

                // Active Work Orders
                if !isDeleted {
                    activeWorkOrdersSection
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .background(AppTheme.background.ignoresSafeArea())
        .navigationTitle("Technician Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AppTheme.brand)
                        .font(.title3)
                }

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash.circle.fill")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(AppTheme.error)
                        .font(.title3)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditMaintenanceMemberSheet(member: currentMember, service: service)
                .registersSheetPresentation()
        }
        .confirmationDialog(
            "Delete Technician",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                let userToDelete = currentMember
                isDeleted = true
                service.deleteUser(userToDelete)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to delete \(currentMember.name)? This action cannot be undone.")
        }
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

    private var activeWorkOrdersSection: some View {
        let activeOrders = service.workOrders.filter {
            $0.assignedMaintenanceID == member.id && $0.status != .completed
        }

        return VStack(alignment: .leading, spacing: 12) {
            Text("ACTIVE WORK ORDERS")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.textSecondary)
                .padding(.horizontal, 4)

            if activeOrders.isEmpty {
                EmptyStateView(
                    icon: "checkmark.seal.fill",
                    title: "All clear",
                    message: "No active work orders assigned."
                )
            } else {
                ForEach(activeOrders) { order in
                    let vehicle = service.vehicles.first { $0.id == order.vehicleID }
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(order.title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                                priorityBadge(order.priority)
                            }
                            if let v = vehicle {
                                Label(v.displayName + " · " + v.plateNumber, systemImage: "truck.box.fill")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.textSecondary)
                            }
                            Text(order.details)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                                .lineLimit(2)
                            StatusBadgeView(
                                text: order.status.rawValue,
                                color: order.status == .inProgress ? AppTheme.brand : AppTheme.warning
                            )
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
            .background(Capsule().fill(priorityColor(priority)))
    }

    private func priorityColor(_ priority: WorkOrderPriority) -> Color {
        switch priority {
        case .low:      AppTheme.success
        case .medium:   AppTheme.brand
        case .high:     AppTheme.warning
        case .critical: AppTheme.error
        }
    }
}

// MARK: - Add Maintenance Member Sheet

private struct AddMaintenanceMemberSheet: View {
    @Environment(\.dismiss) private var dismiss

    let service: MockDataService
    let orgID: UUID?

    @State private var name = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var jobTitle = ""
    @State private var isCreating = false
    @State private var errorMessage: String?

    private var canSubmit: Bool {
        !name.isEmpty && !email.isEmpty && !phone.isEmpty && !jobTitle.isEmpty && !isCreating
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Full Name", text: $name)
                        .disabled(isCreating)

                    // Role is fixed — shown as a read-only label, not a picker
                    LabeledContent("Role") {
                        Text(UserRole.maintenance.rawValue)
                            .foregroundStyle(AppTheme.brand)
                    }

                    TextField("Email", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .disabled(isCreating)

                    TextField("Phone", text: $phone)
                        .keyboardType(.phonePad)
                        .disabled(isCreating)

                    TextField("Job Title", text: $jobTitle)
                        .disabled(isCreating)
                }

                if let error = errorMessage {
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
                        .disabled(isCreating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await submit() }
                    } label: {
                        if isCreating {
                            ProgressView().tint(AppTheme.brand)
                        } else {
                            Text("Add")
                        }
                    }
                    .disabled(!canSubmit)
                }
            }
        }
    }

    private func submit() async {
        errorMessage = nil
        isCreating = true

        // Duplicate email check
        if service.users.contains(where: { $0.email.lowercased() == email.lowercased() }) {
            errorMessage = "An account with this email already exists."
            isCreating = false
            return
        }

        guard let orgID else {
            errorMessage = "Organization not found."
            isCreating = false
            return
        }

        do {
            try await service.addUser(
                name: name,
                role: .maintenance,      // always fixed to maintenance
                email: email,
                phone: phone,
                title: jobTitle,
                organizationID: orgID
            )
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
            isCreating = false
        }
    }
}

// MARK: - Edit Maintenance Member Sheet

private struct EditMaintenanceMemberSheet: View {
    @Environment(\.dismiss) private var dismiss
    let member: User
    let service: MockDataService

    @State private var editName: String
    @State private var editEmail: String
    @State private var editPhone: String
    @State private var editTitle: String
    @State private var isSaving = false
    @State private var errorMessage: String?

    init(member: User, service: MockDataService) {
        self.member = member
        self.service = service
        _editName = State(wrappedValue: member.name)
        _editEmail = State(wrappedValue: member.email)
        _editPhone = State(wrappedValue: member.phone)
        _editTitle = State(wrappedValue: member.title)
    }

    private var canSave: Bool {
        !editName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !editEmail.trimmingCharacters(in: .whitespaces).isEmpty &&
        !editPhone.trimmingCharacters(in: .whitespaces).isEmpty &&
        !editTitle.trimmingCharacters(in: .whitespaces).isEmpty &&
        !isSaving
    }

    private var hasChanges: Bool {
        editName != member.name ||
        editEmail != member.email ||
        editPhone != member.phone ||
        editTitle != member.title
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Profile") {
                    HStack {
                        Spacer()
                        AvatarView(name: editName, size: 64)
                        Spacer()
                    }
                    .listRowBackground(Color.clear)

                    TextField("Full Name", text: $editName)
                        .disabled(isSaving)

                    LabeledContent("Role") {
                        Text(member.role.rawValue)
                            .foregroundStyle(AppTheme.brand)
                    }

                    TextField("Job Title", text: $editTitle)
                        .disabled(isSaving)
                }

                Section("Contact") {
                    TextField("Email", text: $editEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .disabled(isSaving)

                    TextField("Phone", text: $editPhone)
                        .keyboardType(.phonePad)
                        .disabled(isSaving)
                }

                if let error = errorMessage {
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
            }
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        saveChanges()
                    } label: {
                        if isSaving {
                            ProgressView().tint(AppTheme.brand)
                        } else {
                            Text("Save")
                        }
                    }
                    .disabled(!canSave || !hasChanges)
                }
            }
        }
    }

    private func saveChanges() {
        errorMessage = nil
        isSaving = true

        if editEmail.lowercased() != member.email.lowercased(),
           service.users.contains(where: { $0.email.lowercased() == editEmail.lowercased() }) {
            errorMessage = "An account with this email already exists."
            isSaving = false
            return
        }

        var updatedUser = member
        updatedUser.name = editName.trimmingCharacters(in: .whitespaces)
        updatedUser.email = editEmail.trimmingCharacters(in: .whitespaces)
        updatedUser.phone = editPhone.trimmingCharacters(in: .whitespaces)
        updatedUser.title = editTitle.trimmingCharacters(in: .whitespaces)

        service.updateUser(updatedUser)
        isSaving = false
        dismiss()
    }
}

#Preview {
    NavigationStack {
        MaintenanceTabContentView()
            .environment(AppViewModel())
    }
}
