import SwiftUI
import UniformTypeIdentifiers
import UIKit
import PhotosUI

struct VehicleManagementView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var viewModel: VehicleManagementViewModel
    @State private var displayMode: VehicleDisplayMode = .cards
    @State private var showAttentionOnly = false

    init(service: MockDataService, currentOrgID: UUID?) {
        _viewModel = State(wrappedValue: VehicleManagementViewModel(service: service, currentOrgID: currentOrgID))
    }

    private var displayedVehicles: [Vehicle] {
        viewModel.filteredVehicles.filter { !showAttentionOnly || viewModel.needsAttention($0) }
    }

    private var analyticsColumns: [GridItem] {
        [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 160 : 210), spacing: 16)]
    }

    private var vehicleColumns: [GridItem] {
        [GridItem(.adaptive(minimum: horizontalSizeClass == .compact ? 320 : 360), spacing: 16)]
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VehicleSectionBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    heroSection
                    controlsSection
                    vehiclesSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 120)
            }

            addVehicleButton
        }
        .navigationTitle("Vehicles")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $viewModel.isPresentingForm) {
            VehicleFormSheet(viewModel: viewModel)
        }
        .confirmationDialog(
            "Delete Vehicle",
            isPresented: $viewModel.isPresentingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                viewModel.deleteConfirmed()
            }
            Button("Cancel", role: .cancel) {
                viewModel.vehicleToDelete = nil
            }
        } message: {
            if let vehicle = viewModel.vehicleToDelete {
                Text("Are you sure you want to delete \(vehicle.displayName)? This action cannot be undone.")
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Fleet Status")
                        .font(.headline)
                        .foregroundStyle(VehicleStudioTheme.secondary)
                    
                    HStack(spacing: 8) {
                        Circle()
                            .fill(viewModel.readinessScore > 80 ? VehicleStudioTheme.success : VehicleStudioTheme.warning)
                            .frame(width: 10, height: 10)
                        Text("\(viewModel.readinessScore)% Readiness")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(VehicleStudioTheme.primary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(viewModel.activeCount + viewModel.inTransitCount) Active")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(VehicleStudioTheme.accent)
                    
                    Text("\(viewModel.liveTrackingCount) Live")
                        .font(.caption)
                        .foregroundStyle(VehicleStudioTheme.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(VehicleStudioTheme.accent.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            
            HStack(spacing: 12) {
                summaryMetric(title: "Idle", value: "\(viewModel.idleCount)", icon: "pause.fill", color: VehicleStatus.idle.dashboardColor)
                summaryMetric(title: "Service", value: "\(viewModel.maintenanceCount)", icon: "wrench.and.screwdriver.fill", color: VehicleStatus.outOfService.dashboardColor)
                summaryMetric(title: "Fuel Avg", value: "\(viewModel.averageFuelLevel)%", icon: "fuelpump.fill", color: fuelTint(for: viewModel.averageFuelLevel))
            }
        }
        .padding(.vertical, 10)
    }

    private func summaryMetric(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(VehicleStudioTheme.primary)
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(VehicleStudioTheme.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(color.opacity(0.15), lineWidth: 1)
        )
    }

// Removed unused heroMetricPill.

    private var controlsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(VehicleStudioTheme.secondary)
                
                TextField("Search fleet...", text: $viewModel.searchText)
                    .font(.body)
                
                if !viewModel.searchText.isEmpty {
                    Button { viewModel.searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(VehicleStudioTheme.tertiary)
                    }
                }
            }
            .padding(12)
            .background(VehicleStudioTheme.softFill)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            Picker("Filter Vehicles", selection: $viewModel.selectedStatusFilter) {
                Text("All (\(viewModel.allCount))").tag(VehicleStatus?.none)
                Text("Active (\(viewModel.activeCount))").tag(VehicleStatus?.some(.active))
                Text("Transit (\(viewModel.inTransitCount))").tag(VehicleStatus?.some(.inService))
                Text("Idle (\(viewModel.idleCount))").tag(VehicleStatus?.some(.idle))
                Text("Service (\(viewModel.maintenanceCount))").tag(VehicleStatus?.some(.outOfService))
            }
            .pickerStyle(.segmented)
        }
    }

    private func filterChip(title: String, count: Int, status: VehicleStatus?, icon: String) -> some View {
        let isSelected = viewModel.selectedStatusFilter == status
        return VehicleFilterChip(
            title: title,
            icon: icon,
            count: count,
            isSelected: isSelected
        ) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                viewModel.selectedStatusFilter = status
            }
        }
    }

// Removed unused analyticsSection definition.

    private var vehiclesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Vehicles (\(displayedVehicles.count))")
                .font(.headline)
                .foregroundStyle(VehicleStudioTheme.primary)
            
            if displayedVehicles.isEmpty {
                VehicleEmptyStateCard(
                    icon: "car.2",
                    title: "No matches",
                    message: "Current filters returned no results."
                )
            } else {
                VStack(spacing: 12) {
                    ForEach(displayedVehicles) { vehicle in
                        NavigationLink(destination: VehicleDetailView(viewModel: viewModel, vehicleID: vehicle.id)) {
                            VehicleRowView(viewModel: viewModel, vehicle: vehicle)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button { viewModel.prepareForEdit(vehicle) } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            Button(role: .destructive) { viewModel.confirmDelete(vehicle) } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var addVehicleButton: some View {
        Button {
            viewModel.prepareForAdd()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.headline.weight(.bold))
                Text("Add Vehicle")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(VehicleStudioTheme.accentGradient)
                    .shadow(color: VehicleStudioTheme.accent.opacity(0.28), radius: 20, x: 0, y: 12)
            )
        }
        .buttonStyle(VehiclePressableStyle())
        .padding(.trailing, 20)
        .padding(.bottom, 24)
    }

// Removed unused resultLabel.
}

private struct VehicleFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: VehicleManagementViewModel
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    private var isEditing: Bool { viewModel.selectedVehicle != nil }
    private var canSave: Bool {
        !viewModel.displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !viewModel.plateNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        !viewModel.model.trimmingCharacters(in: .whitespaces).isEmpty &&
        Int(viewModel.odometer) != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                VehicleSectionBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 20) {
                        VehicleGlassPanel {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        Circle()
                                            .fill(VehicleStudioTheme.accent.opacity(0.16))
                                            .frame(width: 62, height: 62)
                                        Image(systemName: isEditing ? "square.and.pencil.circle.fill" : "plus.circle.fill")
                                            .font(.system(size: 30, weight: .semibold))
                                            .foregroundStyle(VehicleStudioTheme.accent)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(isEditing ? "Refine Vehicle Profile" : "Create Vehicle Profile")
                                            .font(.system(size: 24, weight: .bold, design: .rounded))
                                            .foregroundStyle(VehicleStudioTheme.primary)
                                        Text("Keep the fleet record polished with assignment, service, and document details.")
                                            .font(.subheadline)
                                            .foregroundStyle(VehicleStudioTheme.secondary)
                                    }
                                }
                            }
                        }

                        formSection(title: "Identity", icon: "car.side.fill") {
                            formField(label: "Display Name", placeholder: "e.g. Truck Alpha", text: $viewModel.displayName)
                            formField(label: "Plate Number", placeholder: "e.g. MH12AB1234", text: $viewModel.plateNumber)
                            formField(label: "Model", placeholder: "e.g. Tata Ace", text: $viewModel.model)
                            formField(label: "Odometer (km)", placeholder: "e.g. 52000", text: $viewModel.odometer, keyboard: .numberPad)

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Status")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(VehicleStudioTheme.secondary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        ForEach(VehicleStatus.allCases, id: \.self) { status in
                                            let selected = viewModel.status == status
                                            Button {
                                                viewModel.status = status
                                            } label: {
                                                HStack(spacing: 8) {
                                                    Image(systemName: status.iconName)
                                                        .font(.caption.weight(.bold))
                                                    Text(status.rawValue)
                                                        .font(.caption.weight(.semibold))
                                                }
                                                .foregroundStyle(selected ? .white : status.dashboardColor)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 10)
                                                .background(
                                                    Capsule()
                                                        .fill(selected ? status.dashboardColor : status.dashboardColor.opacity(0.12))
                                                )
                                            }
                                            .buttonStyle(VehiclePressableStyle())
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }
                        }

                        formSection(title: "Operations", icon: "person.crop.circle.badge.checkmark") {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Assigned Driver")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(VehicleStudioTheme.secondary)

                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 10) {
                                        driverChip(name: "Unassigned", id: nil)
                                        ForEach(viewModel.drivers) { driver in
                                            driverChip(name: driver.name, id: driver.id)
                                        }
                                    }
                                    .padding(.vertical, 2)
                                }
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                Text("Next Service")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(VehicleStudioTheme.secondary)

                                DatePicker("", selection: $viewModel.nextServiceDate, displayedComponents: .date)
                                    .datePickerStyle(.compact)
                                    .labelsHidden()
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .fill(VehicleStudioTheme.softFill)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                    .stroke(VehicleStudioTheme.stroke.opacity(0.65), lineWidth: 1)
                                            )
                                    )
                            }

                            sliderRow(
                                label: "Fuel Level",
                                icon: "fuelpump.fill",
                                value: $viewModel.fuelLevel,
                                color: fuelTint(for: Int(viewModel.fuelLevel))
                            )

                            sliderRow(
                                label: "Utilization",
                                icon: "speedometer",
                                value: $viewModel.utilization,
                                color: VehicleStudioTheme.accent
                            )
                        }

                        formSection(title: "Compliance Info", icon: "doc.richtext.fill") {
                            Text("All documents are mandatory for vehicle approval.")
                                .font(.caption)
                                .foregroundStyle(VehicleStudioTheme.secondary)
                                .padding(.bottom, 8)

                            ForEach(DocumentType.allCases) { type in
                                VStack(alignment: .leading, spacing: 14) {
                                    Text(type.rawValue)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(VehicleStudioTheme.accent)

                                    formField(label: "Number", placeholder: "e.g. \(exampleNumberFor(type))", text: Binding(
                                        get: { viewModel.documentNumbers[type] ?? "" },
                                        set: { viewModel.documentNumbers[type] = $0 }
                                    ))

                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Expiry")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(VehicleStudioTheme.secondary)

                                        DatePicker("", selection: Binding(
                                            get: { viewModel.documentExpiries[type] ?? Date.now.addingTimeInterval(86400 * 120) },
                                            set: { viewModel.documentExpiries[type] = $0 }
                                        ), displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(
                                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                .fill(VehicleStudioTheme.softFill)
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                                                        .stroke(VehicleStudioTheme.stroke.opacity(0.65), lineWidth: 1)
                                                )
                                        )
                                    }
                                }
                                .padding(.bottom, 16)
                            }
                        }
                    
                    

                        Button {
                            viewModel.saveVehicle()
                            dismiss()
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: isEditing ? "checkmark.circle.fill" : "plus.circle.fill")
                                Text(isEditing ? "Save Changes" : "Add Vehicle")
                                    .font(.system(size: 16, weight: .bold, design: .rounded))
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(canSave ? VehicleStudioTheme.accentGradient : LinearGradient(colors: [VehicleStudioTheme.neutral, VehicleStudioTheme.neutral], startPoint: .leading, endPoint: .trailing))
                                    .shadow(color: canSave ? VehicleStudioTheme.accent.opacity(0.28) : .clear, radius: 18, x: 0, y: 10)
                            )
                        }
                        .buttonStyle(VehiclePressableStyle())
                        .disabled(!canSave || DocumentType.allCases.contains { type in
                            (viewModel.documentNumbers[type] ?? "").trimmingCharacters(in: .whitespaces).isEmpty
                        })
                        .padding(.bottom, 28)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
            }
            .navigationTitle(isEditing ? "Edit Vehicle" : "Add Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(VehicleStudioTheme.accent)
                }
            }
            .photosPicker(isPresented: $viewModel.isPresentingImagePicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let type = viewModel.activeDocumentTypeForPhoto {
                        viewModel.documentImages[type] = image
                    }
                    selectedPhotoItem = nil
                }
            }
        }
    }

    private func formSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VehicleGlassPanel {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .foregroundStyle(VehicleStudioTheme.accent)
                    Text(title)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(VehicleStudioTheme.secondary)
                        .textCase(.uppercase)
                        .tracking(0.7)
                }

                content()
            }
        }
    }

    private func formField(label: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(VehicleStudioTheme.secondary)

            TextField(placeholder, text: text)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .foregroundStyle(VehicleStudioTheme.primary)
                .keyboardType(keyboard)
                .textInputAutocapitalization(.words)
                .autocorrectionDisabled()
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(VehicleStudioTheme.softFill)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(VehicleStudioTheme.stroke.opacity(0.65), lineWidth: 1)
                        )
                )
        }
    }

    private func driverChip(name: String, id: UUID?) -> some View {
        let selected = viewModel.assignedDriverID == id
        return Button {
            viewModel.assignedDriverID = id
        } label: {
            HStack(spacing: 8) {
                if id == nil {
                    Image(systemName: "person.crop.circle.badge.xmark")
                        .font(.caption.weight(.bold))
                } else {
                    AvatarView(name: name, size: 22, customColor: VehicleStudioTheme.accent)
                }

                Text(name)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(selected ? .white : VehicleStudioTheme.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(selected ? VehicleStudioTheme.accent : VehicleStudioTheme.softFill)
                    .overlay(
                        Capsule()
                            .stroke(selected ? VehicleStudioTheme.accent : VehicleStudioTheme.stroke.opacity(0.65), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(VehiclePressableStyle())
    }

    private func sliderRow(label: String, icon: String, value: Binding<Double>, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(label, systemImage: icon)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(VehicleStudioTheme.secondary)
                Spacer()
                Text("\(Int(value.wrappedValue))%")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(VehicleStudioTheme.primary)
                    .monospacedDigit()
            }

            Slider(value: value, in: 0...100, step: 1)
                .tint(color)

            VehicleProgressBar(progress: value.wrappedValue / 100, tint: color)
        }
    }

    private func exampleNumberFor(_ type: DocumentType) -> String {
        switch type {
        case .rc: return "RC-1234567"
        case .insurance: return "INS-998877"
        case .puc: return "PUC-554433"
        case .permit: return "PRM-112233"
        }
    }
}

private struct NativeDetailCard<Content: View>: View {
    let padding: CGFloat
    let content: Content

    init(padding: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

private struct VehicleDetailView: View {
    @Bindable var viewModel: VehicleManagementViewModel
    let vehicleID: UUID

    enum VehicleActionSheet: String, Identifiable {
        case liveView
        case tripDetails
        case ping
        case insights

        var id: String { rawValue }
    }

    @State private var activeSheet: VehicleActionSheet?
    @State private var showEditSheet = false

    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                if let vehicle = viewModel.vehicle(for: vehicleID) {
                    VStack(spacing: 20) {
                        heroCard(for: vehicle)
                        // metricStrip(for: vehicle)
                        actionStrip
                        // insightsSection(for: vehicle)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .padding(.bottom, 36)
                } else {
                    VehicleEmptyStateCard(
                        icon: "car.2",
                        title: "Vehicle not found",
                        message: "This record is no longer available in the fleet inventory."
                    )
                    .padding(16)
                }
            }
        }
        .navigationTitle("Vehicle Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if let vehicle = viewModel.vehicle(for: vehicleID) {
                        viewModel.prepareForEdit(vehicle)
                        showEditSheet = true
                    }
                } label: {
                    Text("Edit")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Color.blue)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            VehicleFormSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.isPresentingDocumentSheet) {
            DocumentUploadSheet(viewModel: viewModel, vehicleID: vehicleID)
        }
        .sheet(item: $activeSheet) { sheet in
            NavigationStack {
                ZStack {
                    Color(UIColor.systemGroupedBackground)
                        .ignoresSafeArea()

                    if sheet == .insights, let vehicle = viewModel.vehicle(for: vehicleID) {
                        ScrollView {
                            VStack(spacing: 16) {
                                insightsSection(for: vehicle)
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                        }
                    } else {
                        VStack(spacing: 24) {
                            Image(systemName: sheetIcon(for: sheet))
                                .font(.system(size: 56, weight: .semibold))
                                .foregroundStyle(Color.blue)
                            Text(sheetTitle(for: sheet))
                                .font(.title2.weight(.bold))
                                .foregroundStyle(Color(.label))
                            Text("A dedicated surface for this control is ready to plug into the live data flow.")
                                .font(.subheadline)
                                .foregroundStyle(Color(.secondaryLabel))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                    }
                }
                .navigationTitle(sheetTitle(for: sheet))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            activeSheet = nil
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
    }

    private func heroCard(for vehicle: Vehicle) -> some View {
        NativeDetailCard {
            VStack(alignment: .leading, spacing: 18) {
                HStack(alignment: .center, spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(Color(UIColor.systemGray6))
                        Image(systemName: vehicle.status == .outOfService ? "wrench.and.screwdriver.fill" : "car.side.fill")
                            .font(.system(size: 28, weight: .semibold))
                            .foregroundStyle(vehicle.status.dashboardColor)
                    }
                    .frame(width: 64, height: 64)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(vehicle.displayName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(Color(.label))
                        Text(vehicle.plateNumber)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color(.secondaryLabel))
                        Text(vehicle.model)
                            .font(.footnote)
                            .foregroundStyle(Color(.secondaryLabel))
                    }

                    Spacer(minLength: 8)
                }

                HStack(spacing: 8) {
                    VehicleStatusBadge(title: vehicle.status.rawValue, tint: vehicle.status.dashboardColor, icon: vehicle.status.iconName)
                    VehicleStatusBadge(
                        title: viewModel.isLiveTracked(vehicle) ? "Live Tracking" : "Standby",
                        tint: viewModel.isLiveTracked(vehicle) ? Color.blue : Color(.secondaryLabel),
                        icon: viewModel.isLiveTracked(vehicle) ? "dot.radiowaves.left.and.right" : "pause.circle.fill"
                    )
                }

                Divider().background(Color(UIColor.separator))

                HStack(spacing: 12) {
                    detailInfoPill(
                        icon: "person.fill",
                        title: "Assigned Driver",
                        value: viewModel.driverName(for: vehicle)
                    )
                    detailInfoPill(
                        icon: "point.topleft.down.curvedto.point.bottomright.up.fill",
                        title: "Route Context",
                        value: vehicleRouteText(for: vehicle)
                    )
                }

                if !vehicleTags(for: vehicle, in: viewModel).isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(vehicleTags(for: vehicle, in: viewModel)) { tag in
                                VehicleStatusBadge(title: tag.title, tint: tag.tint, icon: tag.icon)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    private func detailInfoPill(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color(.secondaryLabel))
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color(.label))
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(UIColor.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func metricStrip(for vehicle: Vehicle) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
            VehicleMetricTile(
                title: "Fuel",
                value: "\(vehicle.fuelLevel)%",
                caption: "Reserve",
                tint: fuelTint(for: vehicle.fuelLevel),
                icon: "fuelpump.fill"
            )

            VehicleMetricTile(
                title: "Utilization",
                value: "\(vehicle.utilization)%",
                caption: "Workload",
                tint: Color.blue,
                icon: "speedometer"
            )

            VehicleMetricTile(
                title: "Alerts",
                value: "\(viewModel.activeAlertCount(for: vehicle) + viewModel.unresolvedDefectCount(for: vehicle))",
                caption: "Open signals",
                tint: viewModel.needsAttention(vehicle) ? Color.orange : Color.green,
                icon: "bell.badge.fill"
            )

            let days = viewModel.maintenanceDaysRemaining(for: vehicle)
            VehicleMetricTile(
                title: "Service",
                value: serviceLabel(for: days),
                caption: "Next window",
                tint: serviceTint(for: days),
                icon: "calendar"
            )
        }
    }

    private var actionStrip: some View {
        NativeDetailCard(padding: 12) {
            HStack(spacing: 0) {
                Spacer()
                actionButton(icon: "viewfinder", title: "Live View") { activeSheet = .liveView }
                Spacer()
                actionButton(icon: "doc.text.magnifyingglass", title: "Trip Details") { activeSheet = .tripDetails }
                Spacer()
                actionButton(icon: "antenna.radiowaves.left.and.right", title: "Ping") { activeSheet = .ping }
                Spacer()
                actionButton(icon: "sparkles", title: "Insights") { activeSheet = .insights }
                Spacer()
            }
        }
    }

    private func actionButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Color.blue)
                }
                Text(title)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(Color.blue)
            }
            .frame(width: 76)
        }
    }

    private func insightsSection(for vehicle: Vehicle) -> some View {
        NativeDetailCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Attention & Insights")
                    .font(.headline)
                    .foregroundStyle(Color(.label))

                let alerts = Array(viewModel.alerts(for: vehicle.id).prefix(2))
                let defects = Array(viewModel.defects(for: vehicle.id).filter { !$0.isResolved }.prefix(2))

                if alerts.isEmpty && defects.isEmpty {
                    ForEach(vehiclePositiveInsights(for: vehicle)) { insight in
                        insightRow(icon: insight.icon, tint: insight.tint, title: insight.title)
                    }
                } else {
                    ForEach(alerts) { alert in
                        insightRow(
                            icon: alert.severity == .critical ? "exclamationmark.triangle.fill" : "bell.badge.fill",
                            tint: alert.severity == .critical ? Color.red : Color.orange,
                            title: alert.alertDescription
                        )
                    }

                    ForEach(defects) { defect in
                        insightRow(
                            icon: "wrench.and.screwdriver.fill",
                            tint: defect.severity.priorityColor,
                            title: defect.title ?? defect.description
                        )
                    }
                }
            }
        }
    }

    private func insightRow(icon: String, tint: Color, title: String) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.12))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color(.label))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 2)
    }

    /*
    private func documentsSection(for vehicle: Vehicle) -> some View {
        NativeDetailCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Documents")
                        .font(.headline)
                        .foregroundStyle(Color(.label))
                    Spacer()
                    Button("Upload") {
                        viewModel.prepareForDocumentUpload()
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.blue)
                }

                let documents = viewModel.documents(for: vehicle.id)
                if documents.isEmpty {
                    Text("No compliance documents uploaded yet.")
                        .font(.subheadline)
                        .foregroundStyle(Color(.secondaryLabel))
                } else {
                    ForEach(documents.prefix(4)) { document in
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(Color(UIColor.systemGray6))
                                Image(systemName: "doc.text.fill")
                                    .foregroundStyle(Color.blue)
                            }
                            .frame(width: 42, height: 42)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(document.type.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color(.label))
                                Text(document.documentNumber)
                                    .font(.caption)
                                    .foregroundStyle(Color(.secondaryLabel))
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                Text(document.expiryDate.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(Color(.label))
                                VehicleStatusBadge(
                                    title: document.isVerified ? "Verified" : "Pending",
                                    tint: document.isVerified ? Color.green : Color.orange,
                                    icon: document.isVerified ? "checkmark.seal.fill" : "clock.fill"
                                )
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
        }
    }
    */

    private func sheetIcon(for sheet: VehicleActionSheet) -> String {
        switch sheet {
        case .liveView: return "viewfinder"
        case .tripDetails: return "doc.text.magnifyingglass"
        case .ping: return "antenna.radiowaves.left.and.right"
        case .insights: return "sparkles"
        }
    }

    private func sheetTitle(for sheet: VehicleActionSheet) -> String {
        switch sheet {
        case .liveView: return "Live View"
        case .tripDetails: return "Trip Details"
        case .ping: return "Ping Vehicle"
        case .insights: return "Fleet Insights"
        }
    }
}

private struct DocumentUploadSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: VehicleManagementViewModel
    let vehicleID: UUID
    @State private var selectedPhotoItem: PhotosPickerItem? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                VehicleSectionBackground()

                VStack(spacing: 20) {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 22) {
                            VehicleGlassPanel {
                                VStack(alignment: .leading, spacing: 16) {
                                    HStack(spacing: 12) {
                                        Image(systemName: "doc.text.fill")
                                            .foregroundStyle(VehicleStudioTheme.accent)
                                        Text("Compliance Documents")
                                            .font(.system(size: 24, weight: .bold, design: .rounded))
                                            .foregroundStyle(VehicleStudioTheme.primary)
                                    }
                                    Text("Please provide the following mandatory identification and permit details for the fleet. All fields must be completed.")
                                        .font(.subheadline)
                                        .foregroundStyle(VehicleStudioTheme.secondary)
                                }
                            }

                            ForEach(DocumentType.allCases) { type in
                                documentInputSection(type: type)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 20)
            }
            .navigationTitle("Upload Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save All") {
                        viewModel.saveDocument(for: vehicleID)
                        dismiss()
                    }
                    .disabled(DocumentType.allCases.contains { type in
                        (viewModel.documentNumbers[type] ?? "").trimmingCharacters(in: .whitespaces).isEmpty
                    })
                }
            }
            .photosPicker(isPresented: $viewModel.isPresentingImagePicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let type = viewModel.activeDocumentTypeForPhoto {
                        viewModel.documentImages[type] = image
                    }
                    selectedPhotoItem = nil
                }
            }
        }
    }

    private func documentInputSection(type: DocumentType) -> some View {
        VehicleGlassPanel {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(type.rawValue)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(VehicleStudioTheme.accent)
                    Spacer()
                    Image(systemName: (viewModel.documentNumbers[type] ?? "").isEmpty ? "circle" : "checkmark.circle.fill")
                        .foregroundStyle((viewModel.documentNumbers[type] ?? "").isEmpty ? VehicleStudioTheme.tertiary : VehicleStudioTheme.success)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Document Number")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VehicleStudioTheme.secondary)

                    TextField("e.g. \(exampleNumber(for: type))", text: Binding(
                        get: { viewModel.documentNumbers[type] ?? "" },
                        set: { viewModel.documentNumbers[type] = $0 }
                    ))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundStyle(VehicleStudioTheme.primary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(VehicleStudioTheme.softFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(VehicleStudioTheme.stroke.opacity(0.65), lineWidth: 1)
                            )
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Expiry Date")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VehicleStudioTheme.secondary)

                    DatePicker("", selection: Binding(
                        get: { viewModel.documentExpiries[type] ?? Date.now.addingTimeInterval(86400 * 120) },
                        set: { viewModel.documentExpiries[type] = $0 }
                    ), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(VehicleStudioTheme.softFill)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(VehicleStudioTheme.stroke.opacity(0.65), lineWidth: 1)
                            )
                    )
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("Document Photo")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(VehicleStudioTheme.secondary)

                    HStack(spacing: 12) {
                        if let image = viewModel.documentImages[type] as? UIImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(VehicleStudioTheme.stroke.opacity(0.5), lineWidth: 1)
                                )
                            
                            Button(role: .destructive) {
                                withAnimation {
                                    viewModel.documentImages[type] = nil
                                }
                            } label: {
                                Label("Remove", systemImage: "trash")
                                    .font(.caption.weight(.semibold))
                            }
                        } else {
                            Button {
                                viewModel.activeDocumentTypeForPhoto = type
                                viewModel.isPresentingImagePicker = true
                            } label: {
                                VStack(spacing: 8) {
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 20))
                                    Text("Add Photo")
                                        .font(.caption.weight(.bold))
                                }
                                .foregroundStyle(VehicleStudioTheme.accent)
                                .frame(width: 80, height: 80)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(VehicleStudioTheme.accent.opacity(0.1))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(VehicleStudioTheme.accent.opacity(0.3), lineWidth: 1)
                                )
                            }
                        }
                        
                        Spacer()
                    }
                }
            }
        }
    }

    private func exampleNumber(for type: DocumentType) -> String {
        switch type {
        case .rc: return "RC-1234567"
        case .insurance: return "INS-998877"
        case .puc: return "PUC-554433"
        case .permit: return "PRM-112233"
        }
    }
}

private enum VehicleDisplayMode: String, CaseIterable, Identifiable {
    case cards = "Cards"
    case table = "Table"

    var id: String { rawValue }
}

private enum VehicleStudioTheme {
    static let accent = AppTheme.brand
    static let accentSoft = AppTheme.brandDark
    static let mint = AppTheme.success
    static let success = AppTheme.success
    static let warning = AppTheme.warning
    static let danger = AppTheme.error
    static let primary = AppTheme.textPrimary
    static let secondary = AppTheme.textSecondary
    static let tertiary = AppTheme.textSecondary.opacity(0.72)
    static let neutral = AppTheme.surfaceSecondary
    static let stroke = AppTheme.border
    static let softFill = AppTheme.surfaceSecondary
    static let glassFill = AppTheme.cardBackground
    static let backgroundTop = AppTheme.background
    static let backgroundBottom = AppTheme.background
    static let accentGradient = AppTheme.gradient
}

private struct VehicleSectionBackground: View {
    var body: some View {
        /*
        ZStack {
            AppTheme.background
                .ignoresSafeArea()

            AppTheme.ambientGradient
                .opacity(0.72)
                .ignoresSafeArea()

            Circle()
                .fill(VehicleStudioTheme.accent.opacity(0.18))
                .frame(width: 260, height: 260)
                .blur(radius: 80)
                .offset(x: -120, y: -280)

            Circle()
                .fill(VehicleStudioTheme.accentSoft.opacity(0.14))
                .frame(width: 220, height: 220)
                .blur(radius: 90)
                .offset(x: 150, y: -180)

            Circle()
                .fill(AppTheme.surfaceSecondary.opacity(0.9))
                .frame(width: 260, height: 260)
                .blur(radius: 100)
                .offset(x: 120, y: 220)
        }
        */
        AppTheme.background
            .ignoresSafeArea()
    }
}

private struct VehicleGlassPanel<Content: View>: View {
    let padding: CGFloat
    let content: Content

    init(padding: CGFloat = 18, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .fill(VehicleStudioTheme.glassFill.opacity(0.9))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(VehicleStudioTheme.stroke.opacity(0.8), lineWidth: 1)
                    )
                    .shadow(color: AppTheme.cardShadowColor.opacity(0.08), radius: 18, x: 0, y: 8)
            )
    }
}

// Removed legacy VehicleAnalyticsCard.

// Removed legacy VehicleStatusDistributionView.

private struct VehicleFilterChip: View {
    let title: String
    let icon: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text("\(count)")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(isSelected ? Color.white.opacity(0.18) : VehicleStudioTheme.accent.opacity(0.12))
                    )
            }
            .foregroundStyle(isSelected ? .white : VehicleStudioTheme.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(isSelected ? VehicleStudioTheme.accentGradient : LinearGradient(colors: [VehicleStudioTheme.softFill, VehicleStudioTheme.softFill], startPoint: .leading, endPoint: .trailing))
                    .overlay(
                        Capsule()
                            .stroke(isSelected ? Color.clear : VehicleStudioTheme.stroke.opacity(0.75), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(VehiclePressableStyle())
    }
}

private struct VehicleStatusBadge: View {
    let title: String
    let tint: Color
    let icon: String?

    init(title: String, tint: Color, icon: String? = nil) {
        self.title = title
        self.tint = tint
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
            }
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(tint.opacity(0.12))
                .overlay(
                    Capsule()
                        .stroke(tint.opacity(0.18), lineWidth: 1)
                )
        )
    }
}

// Removed VehicleAnalyticsCard as it is consolidated in the hero section.
// Removed VehicleMetricTile.

private struct VehicleMetricTile: View {
    let title: String
    let value: String
    let caption: String
    let tint: Color
    let icon: String

    var body: some View {
        NativeDetailCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        Circle()
                            .fill(tint.opacity(0.12))
                            .frame(width: 32, height: 32)
                        Image(systemName: icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(tint)
                    }
                    Spacer()
                }

                Text(value)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color(.label))
                    .lineLimit(1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(.label))

                    Text(caption)
                        .font(.caption)
                        .foregroundStyle(Color(.secondaryLabel))
                }
            }
        }
    }
}

private struct VehicleProgressBar: View {
    let progress: Double
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(VehicleStudioTheme.neutral.opacity(0.45))
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.65), tint],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * max(0, min(progress, 1)))
            }
        }
        .frame(height: 8)
    }
}

private struct VehicleRowView: View {
    let viewModel: VehicleManagementViewModel
    let vehicle: Vehicle
    
    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(vehicle.status.dashboardColor.opacity(0.1))
                Image(systemName: vehicle.status == .outOfService ? "wrench.and.screwdriver.fill" : "car.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(vehicle.status.dashboardColor)
            }
            .frame(width: 52, height: 52)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.displayName)
                    .font(.headline)
                    .foregroundStyle(VehicleStudioTheme.primary)
                Text(vehicle.plateNumber)
                    .font(.subheadline)
                    .foregroundStyle(VehicleStudioTheme.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 6) {
                Text(vehicle.status.rawValue)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(vehicle.status.dashboardColor.opacity(0.1))
                    .foregroundStyle(vehicle.status.dashboardColor)
                    .clipShape(Capsule())
            }
            
            Image(systemName: "chevron.right")
                .font(.caption2.weight(.bold))
                .foregroundStyle(VehicleStudioTheme.tertiary)
        }
        .padding(12)
        .background(VehicleStudioTheme.glassFill)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(VehicleStudioTheme.stroke.opacity(0.5), lineWidth: 1)
        )
    }
}

// Removed legacy VehicleDeckCard and VehicleTablePanel.

private struct VehicleEmptyStateCard: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VehicleGlassPanel {
            VStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .fill(VehicleStudioTheme.accent.opacity(0.12))
                        .frame(width: 64, height: 64)
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(VehicleStudioTheme.accent)
                }

                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(VehicleStudioTheme.primary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(VehicleStudioTheme.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }
}

private struct VehicleActionMenu: View {
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Menu {
            Button(action: onEdit) {
                Label("Edit Vehicle", systemImage: "square.and.pencil")
            }

            Button(role: .destructive, action: onDelete) {
                Label("Delete Vehicle", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(VehicleStudioTheme.secondary)
                .background(
                    Circle()
                        .fill(VehicleStudioTheme.glassFill.opacity(0.95))
                        .frame(width: 30, height: 30)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct VehiclePressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.985 : 1)
            .opacity(configuration.isPressed ? 0.94 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

private struct VehicleTag: Identifiable {
    let title: String
    let icon: String
    let tint: Color

    var id: String { "\(icon)-\(title)" }
}

private struct VehiclePositiveInsight: Identifiable {
    let icon: String
    let tint: Color
    let title: String

    var id: String { "\(icon)-\(title)" }
}

private extension VehicleStatus {
    var dashboardColor: Color {
        switch self {
        case .active:
            return VehicleStudioTheme.accent
        case .inService:
            return VehicleStudioTheme.mint
        case .idle:
            return VehicleStudioTheme.secondary
        case .outOfService:
            return VehicleStudioTheme.danger
        }
    }

    var iconName: String {
        switch self {
        case .active:
            return "bolt.fill"
        case .inService:
            return "location.fill"
        case .idle:
            return "pause.circle.fill"
        case .outOfService:
            return "wrench.and.screwdriver.fill"
        }
    }
}

private extension WorkOrderPriority {
    var priorityColor: Color {
        switch self {
        case .critical:
            return VehicleStudioTheme.danger
        case .high:
            return VehicleStudioTheme.warning
        case .medium:
            return VehicleStudioTheme.accent
        case .low:
            return VehicleStudioTheme.secondary
        }
    }
}

private func fuelTint(for level: Int) -> Color {
    if level > 60 {
        return VehicleStudioTheme.success
    }
    if level > 30 {
        return VehicleStudioTheme.warning
    }
    return VehicleStudioTheme.danger
}

private func serviceLabel(for days: Int) -> String {
    if days < 0 {
        return "\(-days)d overdue"
    }
    if days == 0 {
        return "Due today"
    }
    if days <= 7 {
        return "\(days)d left"
    }
    return "\(days)d out"
}

private func serviceTint(for days: Int) -> Color {
    if days <= 0 {
        return VehicleStudioTheme.danger
    }
    if days <= 7 {
        return VehicleStudioTheme.warning
    }
    return VehicleStudioTheme.success
}

private func vehicleRouteText(for vehicle: Vehicle) -> String {
    switch vehicle.status {
    case .active:
        return "Mumbai to Pune"
    case .inService:
        return "Pune to Nashik"
    case .idle:
        return "Nagpur Yard"
    case .outOfService:
        return "Workshop Bay"
    }
}

private func vehicleTags(for vehicle: Vehicle, in viewModel: VehicleManagementViewModel) -> [VehicleTag] {
    var tags: [VehicleTag] = []

    let alertCount = viewModel.activeAlertCount(for: vehicle)
    if alertCount > 0 {
        tags.append(VehicleTag(title: "\(alertCount) live alerts", icon: "bell.badge.fill", tint: VehicleStudioTheme.warning))
    }

    let defectCount = viewModel.unresolvedDefectCount(for: vehicle)
    if defectCount > 0 {
        tags.append(VehicleTag(title: "\(defectCount) open defects", icon: "wrench.and.screwdriver.fill", tint: VehicleStudioTheme.danger))
    }

    let days = viewModel.maintenanceDaysRemaining(for: vehicle)
    if days <= 0 {
        tags.append(VehicleTag(title: "Service overdue", icon: "calendar.badge.exclamationmark", tint: VehicleStudioTheme.danger))
    } else if days <= 7 {
        tags.append(VehicleTag(title: "Service in \(days)d", icon: "calendar", tint: VehicleStudioTheme.warning))
    }

    if vehicle.fuelLevel <= 25 {
        tags.append(VehicleTag(title: "Fuel reserve low", icon: "fuelpump.fill", tint: VehicleStudioTheme.warning))
    }

    if tags.isEmpty {
        tags.append(
            VehicleTag(
                title: viewModel.isLiveTracked(vehicle) ? "Tracking healthy" : "Standing by",
                icon: viewModel.isLiveTracked(vehicle) ? "checkmark.circle.fill" : "pause.circle.fill",
                tint: viewModel.isLiveTracked(vehicle) ? VehicleStudioTheme.success : VehicleStudioTheme.secondary
            )
        )
    }

    return Array(tags.prefix(3))
}

private func vehiclePositiveInsights(for vehicle: Vehicle) -> [VehiclePositiveInsight] {
    switch vehicle.status {
    case .active, .inService:
        return [
            VehiclePositiveInsight(icon: "checkmark.circle.fill", tint: VehicleStudioTheme.success, title: "Route performance is stable and the vehicle is dispatching cleanly."),
            VehiclePositiveInsight(icon: "leaf.fill", tint: VehicleStudioTheme.mint, title: "Efficiency trend remains healthy for the current assignment window.")
        ]
    case .idle:
        return [
            VehiclePositiveInsight(icon: "pause.circle.fill", tint: VehicleStudioTheme.secondary, title: "Vehicle is staged and available for the next dispatch slot."),
            VehiclePositiveInsight(icon: "battery.100percent", tint: VehicleStudioTheme.success, title: "Standby health is strong with no active fault signals.")
        ]
    case .outOfService:
        return [
            VehiclePositiveInsight(icon: "wrench.and.screwdriver.fill", tint: VehicleStudioTheme.warning, title: "Service workflow is active and the unit is safely isolated from dispatch."),
            VehiclePositiveInsight(icon: "doc.text.fill", tint: VehicleStudioTheme.accent, title: "Maintenance documentation can be updated directly from this detail surface.")
        ]
    }
}

#Preview {
    NavigationStack {
        VehicleManagementView(service: MockDataService(), currentOrgID: UUID())
    }
}
