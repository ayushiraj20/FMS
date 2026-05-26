import SwiftUI

struct DriverProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(DriverViewModel.self) private var driverVM
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
    private var assignedVehicle: Vehicle? { appViewModel.assignedVehicle }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 24) {
                profileHeader
                vehicleCard
                contactInfo
                tripHistory
                settingsSection
                logoutButton
                
                Spacer().frame(height: 40)
            }
            .padding(20)
        }
        .background(
            ZStack {
                DriverTheme.background.ignoresSafeArea()
                GeometryReader { geo in
                    Circle()
                        .fill(DriverTheme.accent.opacity(0.1))
                        .frame(width: geo.size.width)
                        .blur(radius: 60)
                        .offset(x: geo.size.width * 0.4, y: -geo.size.height * 0.1)
                }.ignoresSafeArea()
            }
        )
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(isEditing ? "Save" : "Edit") {
                    withAnimation {
                        if isEditing { saveFields() } else { loadFields() }
                        isEditing.toggle()
                    }
                }
                .font(.system(.headline, design: .rounded).bold())
                .foregroundStyle(DriverTheme.accent)
            }
        }
        .onAppear(perform: loadFields)
        .sheet(isPresented: $showDefectSheet) {
            DefectReportView().environment(appViewModel)
        }
        .sheet(isPresented: $showChatSheet) {
            if let activeWO = appViewModel.service.workOrders.first(where: { $0.vehicleID == appViewModel.assignedVehicle?.id && $0.status != .completed }) {
                NavigationStack {
                    WorkOrderChatView(workOrderID: activeWO.id)
                        .environment(appViewModel)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Close") { showChatSheet = false }
                            }
                        }
                }
            } else {
                MaintenanceChatView().environment(appViewModel)
            }
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
            Task {
                await appViewModel.updateProfile(name: editName, phone: editPhone, title: user.title, email: editEmail)
            }
            UserDefaults.standard.set(editLicense, forKey: "driver_license_\(user.id)")
        }
    }

    private var profileHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                if let user = currentUser, user.name.contains("Rajesh") {
                    Image("driver_profile")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(DriverTheme.accent, lineWidth: 3))
                        .shadow(color: DriverTheme.accent.opacity(0.3), radius: 10, y: 5)
                } else {
                    Circle()
                        .fill(DriverTheme.accent.gradient)
                        .frame(width: 100, height: 100)
                        .overlay(Circle().stroke(.white.opacity(0.2), lineWidth: 2))
                        .shadow(color: DriverTheme.accent.opacity(0.3), radius: 10, y: 5)
                    Text(driverVM.driverInitials(currentUser))
                        .font(.system(.largeTitle, design: .rounded).bold())
                        .foregroundStyle(.white)
                }
            }
            .padding(.top, 20)

            if let user = currentUser {
                if isEditing {
                    VStack(alignment: .leading, spacing: 12) {
                        editField(title: "Name", text: $editName)
                        editField(title: "License Number", text: $editLicense)
                    }
                    .padding(.horizontal, 20)
                } else {
                    VStack(spacing: 4) {
                        Text(user.name)
                            .font(.system(.title, design: .rounded).bold())
                            .foregroundStyle(DriverTheme.textPrimary)
                        
                        let license = UserDefaults.standard.string(forKey: "driver_license_\(user.id)") ?? "DL-0420231234567"
                        Text("Licence: \(license)")
                            .font(.subheadline)
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                }
            }
        }
    }

    private var vehicleCard: some View {
        VStack {
            if let vehicle = assignedVehicle {
                HStack(spacing: 16) {
                    Image(systemName: "truck.box.fill")
                        .font(.title)
                        .foregroundStyle(DriverTheme.accent)
                        .frame(width: 64, height: 64)
                        .background(DriverTheme.accent.opacity(0.15), in: RoundedRectangle(cornerRadius: 16))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(vehicle.plateNumber)
                            .font(.system(.headline, design: .rounded).bold())
                            .foregroundStyle(DriverTheme.textPrimary)
                        Text(vehicle.displayName)
                            .font(.subheadline)
                            .foregroundStyle(DriverTheme.textSecondary)
                        HStack(spacing: 6) {
                            Circle()
                                .fill(vehicle.status == .active ? DriverTheme.successGreen : .gray)
                                .frame(width: 8, height: 8)
                            Text(vehicle.status.rawValue)
                                .font(.caption.bold())
                                .foregroundStyle(DriverTheme.textSecondary)
                        }
                    }
                    Spacer()
                }
            } else {
                HStack(spacing: 16) {
                    Image(systemName: "truck.box.fill")
                        .font(.title)
                        .foregroundStyle(DriverTheme.textSecondary)
                        .frame(width: 64, height: 64)
                        .background(DriverTheme.cardFill, in: RoundedRectangle(cornerRadius: 16))
                    Text("No Assigned Vehicle")
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(DriverTheme.textSecondary)
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var contactInfo: some View {
        VStack(spacing: 16) {
            if let user = currentUser {
                if isEditing {
                    VStack(alignment: .leading, spacing: 12) {
                        editField(title: "Email", text: $editEmail, keyboard: .emailAddress)
                        editField(title: "Phone", text: $editPhone, keyboard: .phonePad)
                    }
                } else {
                    profileRow(icon: "envelope.fill", label: "Email", value: user.email)
                    Divider().background(DriverTheme.textSecondary.opacity(0.2))
                    profileRow(icon: "phone.fill", label: "Phone", value: user.phone)
                    Divider().background(DriverTheme.textSecondary.opacity(0.2))
                    profileRow(icon: "building.2.fill", label: "Organization", value: appViewModel.organizationName)
                }
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var tripHistory: some View {
        NavigationLink {
            DriverSafetyView().environment(appViewModel).environment(driverVM)
        } label: {
            HStack(spacing: 16) {
                Image(systemName: "shield.checkerboard")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 64, height: 64)
                    .background(DriverTheme.accent, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: DriverTheme.accent.opacity(0.3), radius: 8, y: 4)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Safety Score & History")
                        .font(.system(.headline, design: .rounded).bold())
                        .foregroundStyle(DriverTheme.textPrimary)
                    Text("Driving stats, safety logs & full trip records")
                        .font(.subheadline)
                        .foregroundStyle(DriverTheme.textSecondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.body.bold())
                    .foregroundStyle(DriverTheme.textSecondary)
            }
            .padding(20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings")
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(DriverTheme.textPrimary)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                settingsRow(icon: "lock.fill", title: "Change Password") { }
                Divider().background(DriverTheme.textSecondary.opacity(0.2)).padding(.leading, 56)
                settingsRow(icon: "exclamationmark.triangle.fill", title: "Report Defect") { showDefectSheet = true }
                Divider().background(DriverTheme.textSecondary.opacity(0.2)).padding(.leading, 56)
                settingsRow(icon: "wrench.and.screwdriver.fill", title: "Maintenance Chat") { showChatSheet = true }
                Divider().background(DriverTheme.textSecondary.opacity(0.2)).padding(.leading, 56)
                settingsRow(icon: "info.circle.fill", title: "About") { }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
    }

    private var logoutButton: some View {
        Button {
            showLogoutAlert = true
        } label: {
            Text("Log Out")
                .font(.system(.title3, design: .rounded).bold())
                .foregroundStyle(DriverTheme.criticalRed)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(DriverTheme.criticalRed.opacity(0.15), in: Capsule())
                .overlay(Capsule().stroke(DriverTheme.criticalRed.opacity(0.3), lineWidth: 1))
        }
    }

    private func profileRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(DriverTheme.accent)
                .frame(width: 24)
            Text(label)
                .font(.system(.body, design: .rounded))
                .foregroundStyle(DriverTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(.body, design: .rounded).bold())
                .foregroundStyle(DriverTheme.textPrimary)
                .lineLimit(1)
        }
    }

    private func settingsRow(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(DriverTheme.accent)
                    .frame(width: 24)
                Text(title)
                    .font(.system(.body, design: .rounded))
                    .foregroundStyle(DriverTheme.textPrimary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundStyle(DriverTheme.textSecondary)
            }
            .padding(20)
        }
    }

    private func editField(title: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.bold())
                .foregroundStyle(DriverTheme.textSecondary)
            TextField(title, text: text)
                .font(.system(.body, design: .rounded))
                .padding(14)
                .background(DriverTheme.cardFill, in: RoundedRectangle(cornerRadius: 12))
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
        }
    }
}

#Preview {
    DriverProfileView()
        .environment(AppViewModel())
        .environment(DriverViewModel())
}
