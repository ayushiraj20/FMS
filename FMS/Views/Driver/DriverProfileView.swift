import SwiftUI

struct DriverProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel
    @EnvironmentObject private var driverVM: DriverViewModel
    @State private var showDefectSheet = false
    @State private var showChatSheet = false
    @State private var showLogoutAlert = false

    // Edit fields
    @State private var isEditing = false
    @State private var editName = ""
    @State private var editEmail = ""
    @State private var editPhone = ""
    @State private var editLicense = ""

    private var currentUser: User? { appViewModel.currentUser }
    private var assignedVehicle: Vehicle? { appViewModel.service.vehicle(for: currentUser?.assignedVehicleID) }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                profileHeader
                vehicleCard
                contactInfo
                tripHistory
                settingsSection
                logoutButton
            }
            .padding(20)
        }
        .background(DriverTheme.background.ignoresSafeArea())
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Save" : "Edit") {
                    if isEditing {
                        saveFields()
                    } else {
                        loadFields()
                    }
                    isEditing.toggle()
                }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(DriverTheme.accent)
            }
        }
        .onAppear(perform: loadFields)
        .sheet(isPresented: $showDefectSheet) {
            DefectReportView()
                .environmentObject(appViewModel)
        }
        .sheet(isPresented: $showChatSheet) {
            MaintenanceChatView()
                .environmentObject(appViewModel)
        }
        .alert("Log Out", isPresented: $showLogoutAlert) {
            Button("Log Out", role: .destructive) {
                dismiss()
                appViewModel.logout()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to log out?")
        }
    }

    private func loadFields() {
        if let user = currentUser {
            editName = user.name
            editEmail = user.email
            editPhone = user.phone
            editLicense = UserDefaults.standard.string(forKey: "driver_license_\(user.id)") ?? "DL-0420231234567"
        }
    }

    private func saveFields() {
        if let user = currentUser {
            appViewModel.updateProfile(name: editName, email: editEmail, phone: editPhone)
            UserDefaults.standard.set(editLicense, forKey: "driver_license_\(user.id)")
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                if let user = currentUser, user.name.contains("Rajesh") {
                    Image("driver_profile")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 80, height: 80)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(DriverTheme.accent)
                        .frame(width: 80, height: 80)
                    Text(driverVM.driverInitials(currentUser))
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                }
            }

            if let user = currentUser {
                if isEditing {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Name")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DriverTheme.textSecondary)
                        TextField("Name", text: $editName)
                            .padding(10)
                            .background(DriverTheme.cardFill)
                            .cornerRadius(8)
                            .foregroundStyle(DriverTheme.textPrimary)
                    }
                    .padding(.horizontal, 20)
                } else {
                    Text(user.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(DriverTheme.textPrimary)
                }

                if isEditing {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("License Number")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(DriverTheme.textSecondary)
                        TextField("License", text: $editLicense)
                            .padding(10)
                            .background(DriverTheme.cardFill)
                            .cornerRadius(8)
                            .foregroundStyle(DriverTheme.textPrimary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                } else {
                    let license = UserDefaults.standard.string(forKey: "driver_license_\(user.id)") ?? "DL-0420231234567"
                    Text("Licence: \(license)")
                        .font(.system(size: 13))
                        .foregroundStyle(DriverTheme.textSecondary)
                }
            }
        }
    }

    private var vehicleCard: some View {
        DriverGlassCard {
            if let vehicle = assignedVehicle {
                HStack(spacing: 14) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(DriverTheme.cardFill)
                        .frame(width: 60, height: 60)
                        .overlay(
                            Image(systemName: "truck.box.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(DriverTheme.accent.opacity(0.6))
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(vehicle.plateNumber)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(DriverTheme.textPrimary)
                        Text(vehicle.displayName)
                            .font(.system(size: 13))
                            .foregroundStyle(DriverTheme.textSecondary)
                        HStack(spacing: 4) {
                            Circle()
                                .fill(vehicle.status == .active ? DriverTheme.successGreen : Color.gray)
                                .frame(width: 6, height: 6)
                            Text(vehicle.status.rawValue)
                                .font(.system(size: 12))
                                .foregroundStyle(DriverTheme.textSecondary)
                        }
                    }
                    Spacer()
                }
            } else {
                HStack {
                    Image(systemName: "truck.box.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(DriverTheme.textSecondary)
                    Text("No Assigned Vehicle")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(DriverTheme.textSecondary)
                    Spacer()
                }
            }
        }
    }

    private var contactInfo: some View {
        DriverGlassCard {
            VStack(spacing: 12) {
                if let user = currentUser {
                    if isEditing {
                        VStack(alignment: .leading, spacing: 8) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Email")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(DriverTheme.textSecondary)
                                TextField("Email", text: $editEmail)
                                    .padding(10)
                                    .background(DriverTheme.cardFill)
                                    .cornerRadius(8)
                                    .foregroundStyle(DriverTheme.textPrimary)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Phone")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(DriverTheme.textSecondary)
                                TextField("Phone", text: $editPhone)
                                    .padding(10)
                                    .background(DriverTheme.cardFill)
                                    .cornerRadius(8)
                                    .foregroundStyle(DriverTheme.textPrimary)
                                    .keyboardType(.phonePad)
                            }
                        }
                    } else {
                        profileRow(icon: "envelope.fill", label: "Email", value: user.email)
                        Divider().foregroundStyle(DriverTheme.separator)
                        profileRow(icon: "phone.fill", label: "Phone", value: user.phone)
                        Divider().foregroundStyle(DriverTheme.separator)
                        profileRow(icon: "building.2.fill", label: "Organization", value: appViewModel.organizationName)
                    }
                }
            }
        }
    }

    private var tripHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trip History & Safety Score")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DriverTheme.textPrimary)

            NavigationLink {
                // Navigate to safety score & trip history view
                DriverSafetyView()
                    .environmentObject(appViewModel)
                    .environmentObject(driverVM)
            } label: {
                DriverGlassCard {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(DriverTheme.accent.opacity(0.1))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Image(systemName: "shield.checkerboard")
                                    .font(.system(size: 20))
                                    .foregroundStyle(DriverTheme.accent)
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text("Safety Score & History")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(DriverTheme.textPrimary)
                            Text("Driving stats, safety logs & full trip records")
                                .font(.system(size: 12))
                                .foregroundStyle(DriverTheme.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DriverTheme.textPrimary)

            DriverGlassCard {
                VStack(spacing: 0) {
                    settingsRow(icon: "lock.fill", title: "Change Password") { }
                    Divider().foregroundStyle(DriverTheme.separator)
                    settingsRow(icon: "wrench.fill", title: "Report Defect") {
                        showDefectSheet = true
                    }
                    Divider().foregroundStyle(DriverTheme.separator)
                    settingsRow(icon: "message.fill", title: "Maintenance Chat") {
                        showChatSheet = true
                    }
                    Divider().foregroundStyle(DriverTheme.separator)
                    settingsRow(icon: "info.circle.fill", title: "About") { }
                }
            }
        }
    }

    private var logoutButton: some View {
        Button("Log Out") {
            showLogoutAlert = true
        }
        .font(.system(size: 17, weight: .semibold))
        .foregroundStyle(DriverTheme.criticalRed)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
    }

    private func profileRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(DriverTheme.accent)
                .frame(width: 24)
            Text(label)
                .font(.system(size: 15))
                .foregroundStyle(DriverTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 15))
                .foregroundStyle(DriverTheme.textPrimary)
                .lineLimit(1)
        }
    }

    private func settingsRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(DriverTheme.accent)
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(DriverTheme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DriverTheme.textSecondary)
            }
            .padding(.vertical, 12)
        }
    }
}

#Preview {
    DriverProfileView()
        .environmentObject(AppViewModel())
        .environmentObject(DriverViewModel())
}
