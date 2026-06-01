import SwiftUI

struct DriverProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(DriverViewModel.self) private var driverVM
    
    @State private var showDefectSheet = false
    @State private var showChatSheet = false
    @State private var showManagerChatSheet = false
    @State private var showLogoutAlert = false

    // Edit fields
    @State private var isEditing = false
    @State private var editName = ""
    @State private var editEmail = ""
    @State private var editPhone = ""
    @State private var editLicense = ""

    private var currentUser: User? { appViewModel.currentUser }

    var body: some View {
        ZStack {
            DriverTheme.background.ignoresSafeArea()
            
            List {
                // Header Block (Non-List row style or transparent list row)
                headerSection
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .padding(.vertical, 16)
                
                // Vehicle Status Section
                Section(header: Text("Vehicle Status").font(.footnote.bold()).foregroundStyle(DriverTheme.textSecondary)) {
                    VehicleCardContainer(vehicle: appViewModel.assignedVehicle)
                        .listRowBackground(DriverTheme.elevatedCard)
                }
                
                // Contact Details Section
                Section(header: Text("Contact Info").font(.footnote.bold()).foregroundStyle(DriverTheme.textSecondary)) {
                    if isEditing {
                        editContactFields
                            .listRowBackground(DriverTheme.elevatedCard)
                    } else {
                        contactRows
                            .listRowBackground(DriverTheme.elevatedCard)
                    }
                }
                
                // Activity & Metrics Section
                Section(header: Text("Activity").font(.footnote.bold()).foregroundStyle(DriverTheme.textSecondary)) {
                    NavigationLink {
                        DriverSafetyView().environment(appViewModel).environment(driverVM)
                    } label: {
                        settingsRow(
                            icon: "shield.checkerboard",
                            iconBg: Color.orange,
                            title: "Safety Score & History"
                        )
                    }
                    .listRowBackground(DriverTheme.elevatedCard)
                }
                
                // Actions & Settings Section
                Section(header: Text("Settings").font(.footnote.bold()).foregroundStyle(DriverTheme.textSecondary)) {
                    Button(action: { }) {
                        settingsRow(icon: "lock.fill", iconBg: Color.blue, title: "Change Password")
                    }
                    
                    Button(action: { showDefectSheet = true }) {
                        settingsRow(icon: "exclamationmark.triangle.fill", iconBg: Color.orange, title: "Report Defect")
                    }
                    
                    Button(action: { showChatSheet = true }) {
                        settingsRow(icon: "wrench.and.screwdriver.fill", iconBg: Color.purple, title: "Maintenance Chat")
                    }

                    Button(action: { showManagerChatSheet = true }) {
                        settingsRow(icon: "message.fill", iconBg: DriverTheme.accent, title: "Fleet Manager Chat")
                    }
                    
                    Button(action: { }) {
                        settingsRow(icon: "info.circle.fill", iconBg: Color.gray, title: "About")
                    }
                }
                .listRowBackground(DriverTheme.elevatedCard)
                
                // Log Out Row
                Section {
                    Button(role: .destructive) {
                        showLogoutAlert = true
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Log Out")
                                .font(.system(.subheadline, design: .rounded).bold())
                            Spacer()
                        }
                        .foregroundStyle(DriverTheme.criticalRed)
                    }
                    .listRowBackground(DriverTheme.criticalRed.opacity(0.1))
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden) // Hides default iOS list background to let DriverTheme.background show through
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
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
        .sheet(isPresented: $showManagerChatSheet) {
            NavigationStack {
                DriverManagerChatView()
                    .environment(appViewModel)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showManagerChatSheet = false }
                        }
                    }
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

    private var headerSection: some View {
        let name = currentUser?.name ?? "Driver Name"
        let license = UserDefaults.standard.string(forKey: "driver_license_\(currentUser?.id.uuidString ?? "")") ?? "DL-0420231234567"
        
        return VStack(spacing: 16) {
            AvatarView(name: name, size: 96, customColor: DriverTheme.accent)
                .overlay(alignment: .bottomTrailing) {
                    ZStack {
                        Circle()
                            .fill(.white) // Cutout effect for badge
                            .frame(width: 28, height: 28)
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(DriverTheme.accent)
                    }
                    .offset(x: 2, y: 2)
                    .shadow(color: Color.black.opacity(0.1), radius: 3, x: 0, y: 2)
                }
            
            VStack(spacing: 6) {
                if isEditing {
                    TextField("Full Name", text: $editName)
                        .font(.title3.weight(.bold))
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.plain)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(DriverTheme.accent.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, 32)
                    
                    TextField("Licence Number", text: $editLicense)
                        .font(.system(size: 12, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(DriverTheme.accent.opacity(0.3), lineWidth: 1)
                        )
                        .padding(.horizontal, 48)
                } else {
                    Text(name)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(DriverTheme.textPrimary)
                    
                    Text("Licence: \(license)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DriverTheme.accent)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(DriverTheme.accent.opacity(0.12)))
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var contactRows: some View {
        Group {
            infoRow(icon: "envelope.fill", iconBg: Color.blue, title: "Email", value: currentUser?.email ?? "")
            infoRow(icon: "phone.fill", iconBg: Color.green, title: "Phone", value: currentUser?.phone ?? "")
            infoRow(icon: "building.2.fill", iconBg: Color.teal, title: "Organization", value: appViewModel.organizationName)
        }
    }

    private var editContactFields: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Email").font(.subheadline).foregroundStyle(DriverTheme.textSecondary).frame(width: 80, alignment: .leading)
                TextField("Email", text: $editEmail)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .font(.subheadline)
            }
            Divider().background(DriverTheme.textSecondary.opacity(0.1))
            HStack {
                Text("Phone").font(.subheadline).foregroundStyle(DriverTheme.textSecondary).frame(width: 80, alignment: .leading)
                TextField("Phone", text: $editPhone)
                    .keyboardType(.phonePad)
                    .font(.subheadline)
            }
        }
        .padding(.vertical, 4)
    }

    private func infoRow(icon: String, iconBg: Color, title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(iconBg, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            
            Text(title)
                .font(.subheadline)
                .foregroundStyle(DriverTheme.textPrimary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .foregroundStyle(DriverTheme.textSecondary)
        }
    }

    private func settingsRow(icon: String, iconBg: Color, title: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(iconBg, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(DriverTheme.textPrimary)
            
            Spacer()
        }
    }

    private func loadFields() {
        if let user = currentUser {
            editName = user.name
            editEmail = user.email
            editPhone = user.phone
            editLicense = UserDefaults.standard.string(forKey: "driver_license_\(user.id.uuidString)") ?? "DL-0420231234567"
        }
    }

    private func saveFields() {
        if let user = currentUser {
            Task {
                await appViewModel.updateProfile(name: editName, phone: editPhone, title: user.title, email: editEmail)
            }
            UserDefaults.standard.set(editLicense, forKey: "driver_license_\(user.id.uuidString)")
        }
    }
}

struct VehicleCardContainer: View {
    let vehicle: Vehicle?
    
    var body: some View {
        if let v = vehicle {
            HStack(spacing: 12) {
                Image(systemName: "box.truck.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(DriverTheme.accent, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(v.displayName)
                        .font(.subheadline.bold())
                        .foregroundStyle(DriverTheme.textPrimary)
                    Text("Plate: \(v.plateNumber)")
                        .font(.caption)
                        .foregroundStyle(DriverTheme.textSecondary)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(v.status == .active ? DriverTheme.successGreen : Color.gray)
                        .frame(width: 8, height: 8)
                    Text(v.status.rawValue.capitalized)
                        .font(.caption.bold())
                        .foregroundStyle(v.status == .active ? DriverTheme.successGreen : DriverTheme.textSecondary)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    Capsule()
                        .fill(v.status == .active ? DriverTheme.successGreen.opacity(0.1) : Color.gray.opacity(0.1))
                )
            }
            .padding(.vertical, 2)
        } else {
            HStack(spacing: 12) {
                Image(systemName: "box.truck.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(Color.gray, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                
                Text("No Assigned Vehicle")
                    .font(.subheadline)
                    .foregroundStyle(DriverTheme.textSecondary)
            }
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
