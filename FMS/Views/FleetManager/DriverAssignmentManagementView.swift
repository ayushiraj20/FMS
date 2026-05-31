import SwiftUI

struct DriverAssignmentManagementView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var viewModel: DriverAssignmentViewModel
    @State private var isPresentingAssignDriverTripModal = false
    
    init(service: MockDataService) {
        _viewModel = State(wrappedValue: DriverAssignmentViewModel(service: service))
    }
    
    var body: some View {
        AppScaffold {
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {

                        
                        // Summary Metrics Cards List
                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                            summaryStatCard(title: "Total Drivers", value: "\(viewModel.totalDriversCount)", icon: "person.2.fill", tint: AppTheme.brand)
                            summaryStatCard(title: "Available Drivers", value: "\(viewModel.availableDriversCount)", icon: "checkmark.circle.fill", tint: AppTheme.success)
                            summaryStatCard(title: "Assigned Drivers", value: "\(viewModel.assignedDriversCount)", icon: "key.fill", tint: Color(hex: "#00a2ff"))
                            summaryStatCard(title: "Active Vehicles", value: "\(viewModel.activeVehiclesCount)", icon: "truck.box.fill", tint: AppTheme.warning)
                            summaryStatCard(title: "Unassigned Vehicles", value: "\(viewModel.unassignedVehiclesCount)", icon: "exclamationmark.triangle.fill", tint: AppTheme.error)
                        }
                        .padding(.horizontal)
                        
                        availableDriversSection

                        // Section Title
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(title: "Driver Assignments", subtitle: "Active pairings and duty status")
                                .padding(.horizontal)
                            
                            LazyVStack(spacing: 16) {
                                ForEach(viewModel.drivers) { driver in
                                    driverAssignmentCard(driver: driver)
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        Spacer().frame(height: 80) // bottom padding
                    }
                }
                .refreshable {
                    await viewModel.service.syncWithDatabase()
                }
                

                
                // Toast Success Overlay
                if viewModel.isShowingToast, let message = viewModel.successMessage {
                    successToast(message: message)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(2)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            viewModel.organizationID = appViewModel.currentOrganization?.id
        }
        .onChange(of: appViewModel.currentOrganization?.id) { _, newValue in
            viewModel.organizationID = newValue
        }
        .sheet(isPresented: $viewModel.isPresentingAssignSheet) {
            if let driver = viewModel.selectedDriver {
                AssignVehicleSheet(viewModel: viewModel, driver: driver)
            }
        }
        .sheet(isPresented: $isPresentingAssignDriverTripModal) {
            AssignDriverTripView(service: viewModel.service)
        }
    }
    
    // MARK: - Available Drivers (on duty, no trip)

    private var availableDriversSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(
                title: "Available Drivers",
                subtitle: "On duty with no scheduled or active trips"
            )
            .padding(.horizontal)

            if viewModel.availableDrivers.isEmpty {
                EmptyStateView(
                    icon: "person.crop.circle.badge.clock",
                    title: "No available drivers",
                    message: "Drivers appear here when they switch to on duty and have no trip assigned."
                )
                .padding(.horizontal)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.availableDrivers) { driver in
                        availableDriverRow(driver)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    private func availableDriverRow(_ driver: User) -> some View {
        HStack(spacing: 12) {
            AvatarView(name: driver.name, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(driver.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.textPrimary)
                Text(driver.phone)
                    .font(.caption)
                    .foregroundStyle(AppTheme.textSecondary)
            }

            Spacer()

            Text("Ready")
                .font(.caption2.weight(.bold))
                .foregroundStyle(AppTheme.success)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppTheme.success.opacity(0.12), in: Capsule())
        }
        .padding(12)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 0.5)
        )
    }

    // MARK: - Component UI Elements
    
    private func summaryStatCard(title: String, value: String, icon: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppTheme.textSecondary)
                    .minimumScaleFactor(0.85)
                    .lineLimit(1)
                Spacer()
                Image(systemName: icon)
                    .font(.subheadline)
                    .foregroundStyle(tint)
            }
            
            Text(value)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.border, lineWidth: 0.5)
        )
    }
    
    private func driverAssignmentCard(driver: User) -> some View {
        let assignedVehicle = viewModel.service.vehicles.first { $0.assignedDriverID == driver.id }
        let isOnDuty = viewModel.service.dutyStatus(for: driver.id) == .onDuty
        let empCode = "DR-\(abs(driver.id.hashValue % 900) + 100)"
        
        return GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                // Top row: Avatar + Driver Info + Availability
                HStack(alignment: .top, spacing: 14) {
                    AvatarView(name: driver.name, size: 48)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(driver.name)
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)
                        Text("Employee Code: \(empCode)")
                            .font(.caption.monospaced())
                            .foregroundStyle(AppTheme.textSecondary)
                    }
                    
                    Spacer()
                    
                    // Availability status badge
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isOnDuty ? AppTheme.success : AppTheme.textSecondary)
                            .frame(width: 6, height: 6)
                        Text(isOnDuty ? "On Duty" : "Off Duty")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(isOnDuty ? AppTheme.success : AppTheme.textSecondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(isOnDuty ? AppTheme.success.opacity(0.12) : AppTheme.surfaceSecondary)
                    .clipShape(Capsule())
                }
                
                Divider()
                    .background(AppTheme.border)
                
                // Middle row: Vehicle assignment status
                HStack(alignment: .center, spacing: 12) {
                    if let vehicle = assignedVehicle {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(vehicleStatusColor(vehicle.status).opacity(0.12))
                                .frame(width: 40, height: 40)
                            Image(systemName: "box.truck.fill")
                                .foregroundStyle(vehicleStatusColor(vehicle.status))
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(vehicle.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text("Plate: \(vehicle.plateNumber)")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        
                        Spacer()
                        
                        // Vehicle status indicator badge
                        Text(vehicle.status.rawValue.uppercased())
                            .font(.system(size: 9, weight: .black))
                            .tracking(0.5)
                            .foregroundStyle(vehicleStatusColor(vehicle.status))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(vehicleStatusColor(vehicle.status).opacity(0.12))
                            .clipShape(Capsule())
                        
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(AppTheme.textSecondary.opacity(0.1))
                                .frame(width: 40, height: 40)
                            Image(systemName: "slash.circle")
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No Assigned Vehicle")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.textSecondary)
                            Text("Requires assignment")
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary.opacity(0.8))
                        }
                        
                        Spacer()
                        
                        Text("UNASSIGNED")
                            .font(.system(size: 9, weight: .black))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.surfaceSecondary)
                            .clipShape(Capsule())
                    }
                }
                
                // Bottom row: Assignment Actions
                HStack {
                    Spacer()
                    
                    if assignedVehicle != nil {
                        Button {
                            withAnimation {
                                viewModel.unassign(driver: driver)
                            }
                        } label: {
                            Text("Unassign")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppTheme.error)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(AppTheme.error.opacity(0.08))
                                .clipShape(Capsule())
                        }
                    }
                    
                    Button {
                        viewModel.selectedDriver = driver
                        viewModel.selectedVehicle = assignedVehicle
                        viewModel.isPresentingAssignSheet = true
                    } label: {
                        Text(assignedVehicle == nil ? "Assign Vehicle" : "Reassign")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppTheme.brand)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
    
    private func vehicleStatusColor(_ status: VehicleStatus) -> Color {
        switch status {
        case .active: return Color(hex: "#00a2ff") // blue
        case .inService: return Color(hex: "#cddb32") // yellow-green
        case .idle: return AppTheme.success // green
        case .outOfService: return AppTheme.error // red
        }
    }
    
    private func successToast(message: String) -> some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white)
                    .font(.headline)
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(Capsule().fill(AppTheme.success))
            .shadow(color: AppTheme.success.opacity(0.4), radius: 10, y: 4)
            .padding(.top, 40)
            Spacer()
        }
    }
}

// MARK: - Assign Vehicle Sheet

private struct AssignVehicleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: DriverAssignmentViewModel
    let driver: User
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Driver Details") {
                    LabeledContent("Name", value: driver.name)
                    LabeledContent("Email", value: driver.email)
                    LabeledContent("Role", value: driver.role.rawValue)
                }
                
                Section("Assign Vehicle") {
                    if viewModel.availableVehicles.isEmpty {
                        Text("No available vehicles left in inventory. All vehicles have active driver pairings.")
                            .font(.footnote)
                            .foregroundStyle(AppTheme.textSecondary)
                    } else {
                        Picker("Select Vehicle", selection: $viewModel.selectedVehicle) {
                            Text("Unassigned").tag(Optional<Vehicle>.none)
                            ForEach(viewModel.availableVehicles) { vehicle in
                                Text("\(vehicle.displayName) (\(vehicle.plateNumber))").tag(Optional(vehicle))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Vehicle Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Confirm") {
                        if let selected = viewModel.selectedVehicle {
                            viewModel.assign(vehicle: selected, to: driver)
                        } else {
                            viewModel.unassign(driver: driver)
                        }
                        dismiss()
                    }
                }
            }
        }
    }
}
