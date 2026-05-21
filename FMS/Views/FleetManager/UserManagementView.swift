import SwiftUI

struct UserManagementView: View {
    @StateObject private var viewModel: UserManagementViewModel

    init(service: MockDataService, currentOrgID: UUID?) {
        _viewModel = StateObject(wrappedValue: UserManagementViewModel(service: service, currentOrgID: currentOrgID))
    }

    var body: some View {
        List {
            Section {
                ForEach(viewModel.filteredUsers) { user in
                    GlassCard {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.name)
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text(user.title)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.textSecondary)
                                }
                                Spacer()
                                RoleBadgeView(role: user.role)
                            }
                            Text(user.email)
                                .font(.footnote)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } header: {
                Text("Team Members")
            }
        }
        .appListStyle()
        .searchable(text: $viewModel.searchText, placement: .navigationBarDrawer(displayMode: .always))
        .navigationTitle("User Management")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.resetForm()
                    viewModel.isPresentingCreateUser = true
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(AppTheme.brand)
                }
            }
        }
        .sheet(isPresented: $viewModel.isPresentingCreateUser) {
            CreateUserSheet(viewModel: viewModel)
        }
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
