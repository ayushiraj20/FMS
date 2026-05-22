import SwiftUI

struct UserManagementView: View {
    @StateObject private var viewModel: UserManagementViewModel

    init(service: MockDataService, currentOrgID: UUID?) {
        _viewModel = StateObject(wrappedValue: UserManagementViewModel(service: service, currentOrgID: currentOrgID))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Color(hex: "#121212").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Text("Team")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(.white)
                    
                    Text("\(viewModel.filteredUsers.count) members")
                        .font(.caption)
                        .foregroundStyle(Color(hex: "#8E8E93"))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(hex: "#1C1C1E"))
                        .clipShape(Capsule())
                }
                .padding(.horizontal)
                .padding(.top, 10)

                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color(hex: "#8E8E93"))
                    TextField("Search", text: $viewModel.searchText)
                        .foregroundStyle(.white)
                        .tint(AppTheme.brand)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(hex: "#1C1C1E"))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal)

                // Filter Chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        filterChip(title: "All", role: nil)
                        filterChip(title: "Managers", role: .fleetManager)
                        filterChip(title: "Drivers", role: .driver)
                        filterChip(title: "Maintenance", role: .maintenance)
                    }
                    .padding(.horizontal)
                }

                // User Cards List
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(viewModel.filteredUsers) { user in
                            TeamMemberCard(user: user)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100) // Space for FAB
                }
            }

            // Floating Action Button
            Button {
                viewModel.resetForm()
                viewModel.isPresentingCreateUser = true
            } label: {
                Image(systemName: "plus")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(AppTheme.brand)
                    .clipShape(Circle())
                    .shadow(color: AppTheme.brand.opacity(0.6), radius: 10, y: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 30)
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $viewModel.isPresentingCreateUser) {
            CreateUserSheet(viewModel: viewModel)
        }
    }

    private func filterChip(title: String, role: UserRole?) -> some View {
        let isSelected = viewModel.selectedRoleFilter == role
        return Button {
            withAnimation {
                viewModel.selectedRoleFilter = role
            }
        } label: {
            Text(title)
                .font(.subheadline.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .white : Color(hex: "#8E8E93"))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? AppTheme.brand : .clear)
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(isSelected ? .clear : Color(hex: "#3A3A3C"), lineWidth: 1)
                )
        }
    }
}

private struct TeamMemberCard: View {
    let user: User
    
    // Mock status based on ID hash for UI
    private var isOnDuty: Bool {
        user.id.hashValue % 2 == 0
    }
    
    private var statusColor: Color {
        isOnDuty ? AppTheme.success : Color(hex: "#8E8E93")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                // Avatar
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .frame(width: 50, height: 50)
                    .foregroundStyle(Color(hex: "#D1D1D6"))
                    .background(Circle().fill(Color(hex: "#F2F2F7")))
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(user.name)
                        .font(.headline)
                        .foregroundStyle(.black)
                    
                    Text(user.role.rawValue)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(AppTheme.brand)
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                // Status
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 6, height: 6)
                    Text(isOnDuty ? "On Duty" : "Off Duty")
                        .font(.caption)
                        .foregroundStyle(statusColor)
                }
            }
            
            HStack {
                // Vehicle ID / Subtitle
                Text(user.role == .driver ? "TRK-\(abs(user.id.hashValue % 9000) + 1000)" : user.title)
                    .font(.headline)
                    .foregroundStyle(.black)
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 8) {
                    Button(action: {}) {
                        Image(systemName: "phone")
                            .foregroundStyle(.black)
                            .frame(width: 36, height: 36)
                            .background(Color(hex: "#F2F2F7"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    Button(action: {}) {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.black)
                            .frame(width: 36, height: 36)
                            .background(Color(hex: "#F2F2F7"))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

private struct CreateUserSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: UserManagementViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    TextField("Full Name", text: $viewModel.newUserName)
                        .disabled(viewModel.isCreating)
                    Picker("Role", selection: $viewModel.newUserRole) {
                        Text(UserRole.driver.rawValue).tag(UserRole.driver)
                        Text(UserRole.maintenance.rawValue).tag(UserRole.maintenance)
                    }
                    .disabled(viewModel.isCreating)
                    TextField("Email", text: $viewModel.newUserEmail)
                        .textInputAutocapitalization(.never)
                        .disabled(viewModel.isCreating)
                    TextField("Phone", text: $viewModel.newUserPhone)
                        .disabled(viewModel.isCreating)
                    TextField("Job Title", text: $viewModel.newUserTitle)
                        .disabled(viewModel.isCreating)
                }

                if let errorMessage = viewModel.errorMessage {
                    Section {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(AppTheme.error)
                            Text(errorMessage)
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
            .navigationTitle("Create User")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(viewModel.isCreating)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task {
                            let success = await viewModel.createUser()
                            if success {
                                dismiss()
                            }
                        }
                    } label: {
                        if viewModel.isCreating {
                            ProgressView()
                                .tint(AppTheme.brand)
                        } else {
                            Text("Create")
                        }
                    }
                    .disabled(viewModel.newUserName.isEmpty || viewModel.newUserEmail.isEmpty || viewModel.newUserPhone.isEmpty || viewModel.newUserTitle.isEmpty || viewModel.isCreating)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        UserManagementView(service: MockDataService(), currentOrgID: UUID())
    }
}
