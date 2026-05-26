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

    var body: some View {
        Form {
            Section {
                ProfileHeaderContainer(
                    user: currentUser,
                    driverVM: driverVM,
                    isEditing: isEditing,
                    editName: $editName,
                    editLicense: $editLicense
                )
            }
            
            Section(header: Text("Vehicle Status")) {
                VehicleCardContainer(vehicle: appViewModel.assignedVehicle)
            }
            
            Section(header: Text("Contact Info")) {
                ContactInfoContainer(
                    user: currentUser,
                    organizationName: appViewModel.organizationName,
                    isEditing: isEditing,
                    editEmail: $editEmail,
                    editPhone: $editPhone
                )
            }
            
            Section(header: Text("Activity")) {
                TripHistoryContainer(appViewModel: appViewModel, driverVM: driverVM)
            }
            
            Section(header: Text("Settings")) {
                SettingsSectionContainer(
                    showDefectSheet: $showDefectSheet,
                    showChatSheet: $showChatSheet
                )
            }
            
            Section {
                Button(role: .destructive) {
                    showLogoutAlert = true
                } label: {
                    HStack {
                        Spacer()
                        Text("Log Out")
                        Spacer()
                    }
                }
            }
        }
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
}

// MARK: - Sub-Containers

struct ProfileHeaderContainer: View {
    let user: User?
    let driverVM: DriverViewModel
    let isEditing: Bool
    @Binding var editName: String
    @Binding var editLicense: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                if let u = user, u.name.contains("Rajesh") {
                    Image("driver_profile")
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(DriverTheme.accent.gradient)
                        .frame(width: 60, height: 60)
                    Text(driverVM.driverInitials(user))
                        .font(.title2.bold())
                        .foregroundStyle(.white)
                }
            }
            
            if let u = user {
                if isEditing {
                    VStack {
                        TextField("Name", text: $editName)
                        TextField("License", text: $editLicense)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(u.name).font(.headline)
                        let license = UserDefaults.standard.string(forKey: "driver_license_\(u.id)") ?? "DL-0420231234567"
                        Text("Licence: \(license)").font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

struct VehicleCardContainer: View {
    let vehicle: Vehicle?
    
    var body: some View {
        if let v = vehicle {
            HStack {
                Image(systemName: "truck.box.fill").foregroundStyle(DriverTheme.accent).font(.title2)
                VStack(alignment: .leading) {
                    Text(v.plateNumber).font(.headline)
                    Text(v.displayName).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(v.status == .active ? DriverTheme.successGreen : .gray).frame(width: 8, height: 8)
                    Text(v.status.rawValue.capitalized).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        } else {
            HStack {
                Image(systemName: "truck.box.fill").foregroundStyle(.secondary).font(.title2)
                Text("No Assigned Vehicle").foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}

struct ContactInfoContainer: View {
    let user: User?
    let organizationName: String
    let isEditing: Bool
    @Binding var editEmail: String
    @Binding var editPhone: String

    var body: some View {
        if let u = user {
            if isEditing {
                TextField("Email", text: $editEmail)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                TextField("Phone", text: $editPhone)
                    .keyboardType(.phonePad)
            } else {
                LabeledContent("Email", value: u.email)
                LabeledContent("Phone", value: u.phone)
                LabeledContent("Organization", value: organizationName)
            }
        }
    }
}

struct TripHistoryContainer: View {
    let appViewModel: AppViewModel
    let driverVM: DriverViewModel

    var body: some View {
        NavigationLink {
            DriverSafetyView().environment(appViewModel).environment(driverVM)
        } label: {
            Label {
                Text("Safety Score & History")
            } icon: {
                Image(systemName: "shield.checkerboard").foregroundStyle(DriverTheme.accent)
            }
        }
    }
}

struct SettingsSectionContainer: View {
    @Binding var showDefectSheet: Bool
    @Binding var showChatSheet: Bool

    var body: some View {
        Button(action: { }) {
            Label("Change Password", systemImage: "lock.fill").foregroundStyle(DriverTheme.textPrimary)
        }
        Button(action: { showDefectSheet = true }) {
            Label("Report Defect", systemImage: "exclamationmark.triangle.fill").foregroundStyle(DriverTheme.textPrimary)
        }
        Button(action: { showChatSheet = true }) {
            Label("Maintenance Chat", systemImage: "wrench.and.screwdriver.fill").foregroundStyle(DriverTheme.textPrimary)
        }
        Button(action: { }) {
            Label("About", systemImage: "info.circle.fill").foregroundStyle(DriverTheme.textPrimary)
        }
    }
}

#Preview {
    NavigationStack {
        DriverProfileView()
            .environment(AppViewModel())
            .environment(DriverViewModel())
    }
}
