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
        @Bindable var bindableViewModel = viewModel
        ZStack(alignment: .bottomTrailing) {
            List {
                // Section 1: Fleet Status Dashboard
                Section {
                    HStack(alignment: .center, spacing: 16) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Fleet Readiness")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.secondary)
                            
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(viewModel.readinessScore > 80 ? Color.green : Color.orange)
                                    .frame(width: 8, height: 8)
                                Text("\(viewModel.readinessScore)%")
                                    .font(.title2.bold())
                                    .foregroundStyle(.primary)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(viewModel.activeCount + viewModel.inTransitCount) Active")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Color.blue)
                            Text("\(viewModel.liveTrackingCount) Live Tracked")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Idle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(viewModel.idleCount)")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Service")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(viewModel.maintenanceCount)")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 16)
                        
                        Divider()
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Avg Fuel")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("\(viewModel.averageFuelLevel)%")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 16)
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Fleet Summary")
                }
                
                // Section 2: Segmented Status Filter
                Section {
                    Picker("Status Filter", selection: $bindableViewModel.selectedStatusFilter) {
                        Text("All").tag(nil as VehicleStatus?)
                        Text("Active").tag(VehicleStatus.active as VehicleStatus?)
                        Text("Transit").tag(VehicleStatus.inService as VehicleStatus?)
                        Text("Idle").tag(VehicleStatus.idle as VehicleStatus?)
                        Text("Service").tag(VehicleStatus.outOfService as VehicleStatus?)
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
                
                // Section 3: Vehicles List
                Section {
                    if displayedVehicles.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "car.2")
                                .font(.largeTitle)
                                .foregroundStyle(.secondary)
                            Text("No Matches Found")
                                .font(.headline)
                            Text("Try adjusting your filters or search text.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                        .listRowBackground(Color.clear)
                    } else {
                        ForEach(displayedVehicles) { vehicle in
                            NavigationLink(destination: VehicleDetailView(viewModel: viewModel, vehicleID: vehicle.id).hideTabBarOnPush()) {
                                HStack(spacing: 16) {
                                    ZStack {
                                        Circle()
                                            .fill(vehicle.status.dashboardColor.opacity(0.12))
                                            .frame(width: 38, height: 38)
                                        Image(systemName: vehicle.status == .outOfService ? "wrench.and.screwdriver.fill" : "car.side.fill")
                                            .font(.subheadline)
                                            .foregroundStyle(vehicle.status.dashboardColor)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(vehicle.displayName)
                                            .font(.body.weight(.semibold))
                                            .foregroundStyle(.primary)
                                        Text(vehicle.plateNumber)
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    Text(vehicle.status.rawValue.capitalized)
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(vehicle.status.dashboardColor)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(vehicle.status.dashboardColor.opacity(0.12))
                                        .clipShape(Capsule())
                                }
                            }
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
                } header: {
                    Text("Vehicles (\(displayedVehicles.count))")
                }
            }
            .listStyle(.insetGrouped)
            .refreshable {
                await viewModel.refresh()
            }
            .searchable(text: $bindableViewModel.searchText, prompt: "Search fleet...")

            addVehicleButton
        }
        .navigationTitle("Vehicles")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $viewModel.isPresentingForm) {
            VehicleFormSheet(viewModel: viewModel)
                .registersSheetPresentation()
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
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    filterChip(title: "All", count: viewModel.allCount, status: nil, icon: "car.2.fill")
                    filterChip(title: "Active", count: viewModel.activeCount, status: .active, icon: "checkmark.circle.fill")
                    filterChip(title: "Transit", count: viewModel.inTransitCount, status: .inService, icon: "arrow.triangle.turn.up.right.circle.fill")
                    filterChip(title: "Idle", count: viewModel.idleCount, status: .idle, icon: "pause.circle.fill")
                    filterChip(title: "Service", count: viewModel.maintenanceCount, status: .outOfService, icon: "wrench.and.screwdriver.fill")
                }
                .padding(.vertical, 2)
            }
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
                        NavigationLink(destination: VehicleDetailView(viewModel: viewModel, vehicleID: vehicle.id).hideTabBarOnPush()) {
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
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(
                    Circle()
                        .fill(AppTheme.brand)
                        .shadow(color: AppTheme.brand.opacity(0.4), radius: 10, x: 0, y: 4)
                )
        }
        .buttonStyle(.plain)
        .padding(.trailing, 24)
        .padding(.bottom, 24)
    }

// Removed unused resultLabel.
}


// MARK: - Multi-Step Add Vehicle Form

private struct VehicleFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: VehicleManagementViewModel
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var currentStep: Int = 0
    @State private var driverSearchText: String = ""
    @State private var showDriverPicker: Bool = false
    
    @State private var isPresentingPhotoSource = false
    @State private var isPresentingCamera = false
    @State private var capturedImage: UIImage? = nil

    private var isEditing: Bool { viewModel.selectedVehicle != nil }

    private var step1Valid: Bool {
        !viewModel.displayName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !viewModel.plateNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        !viewModel.model.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var step2Valid: Bool {
        let cleanOdo = viewModel.odometer.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        return !cleanOdo.isEmpty && Int(cleanOdo) != nil
    }

    private var canSave: Bool { step1Valid && step2Valid }

    private let stepTitles = ["Identity", "Operations", "Compliance"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                stepIndicator
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 4)

                TabView(selection: $currentStep) {
                    step1View.tag(0)
                    step2View.tag(1)
                    step3View.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.25), value: currentStep)

                bottomNav
            }
            .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(isEditing ? "Edit Vehicle" : "Add Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(VehicleStudioTheme.accent)
                }
            }
            .sheet(isPresented: $showDriverPicker) {
                driverPickerSheet
                    .registersSheetPresentation()
            }
            .photosPicker(isPresented: $viewModel.isPresentingImagePicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data),
                       let type = viewModel.activeDocumentTypeForPhoto {
                        viewModel.uploadImage(image, for: type)
                    }
                    selectedPhotoItem = nil
                }
            }
            .confirmationDialog(
                "Select Photo Source",
                isPresented: $isPresentingPhotoSource,
                titleVisibility: .visible
            ) {
                Button("Take Photo (Camera)") {
                    isPresentingCamera = true
                }
                Button("Choose from Library") {
                    viewModel.isPresentingImagePicker = true
                }
                Button("Cancel", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $isPresentingCamera) {
                CameraView(image: $capturedImage) { image in
                    if let type = viewModel.activeDocumentTypeForPhoto {
                        viewModel.uploadImage(image, for: type)
                    }
                }
                .ignoresSafeArea()
            }
        }
    }

    // MARK: - Step Indicator
    private var stepIndicator: some View {
        HStack(spacing: 0) {
            ForEach(0..<3) { index in
                HStack(spacing: 0) {
                    ZStack {
                        Circle()
                            .fill(index <= currentStep ? VehicleStudioTheme.accent : Color(UIColor.systemGray5))
                            .frame(width: 26, height: 26)
                        if index < currentStep {
                            Image(systemName: "checkmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        } else {
                            Text("\(index + 1)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(index == currentStep ? .white : Color(UIColor.secondaryLabel))
                        }
                    }

                    Text(stepTitles[index])
                        .font(.system(size: 11, weight: index == currentStep ? .semibold : .regular))
                        .foregroundStyle(index == currentStep ? VehicleStudioTheme.accent : Color(UIColor.secondaryLabel))
                        .padding(.leading, 5)

                    if index < 2 {
                        Rectangle()
                            .fill(index < currentStep ? VehicleStudioTheme.accent : Color(UIColor.systemGray4))
                            .frame(height: 1.5)
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 8)
                    }
                }
            }
        }
    }

    // MARK: - Bottom Navigation
    private var bottomNav: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                if currentStep > 0 {
                    Button {
                        withAnimation { currentStep -= 1 }
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "chevron.left").font(.system(size: 12, weight: .semibold))
                            Text("Back").font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(VehicleStudioTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 12).fill(VehicleStudioTheme.accent.opacity(0.08)))
                    }
                    .buttonStyle(VehiclePressableStyle())
                }

                if currentStep < 2 {
                    let stepInvalid = (currentStep == 0 && !step1Valid) || (currentStep == 1 && !step2Valid)
                    Button {
                        withAnimation { currentStep += 1 }
                    } label: {
                        HStack(spacing: 5) {
                            Text("Continue").font(.system(size: 15, weight: .semibold))
                            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(stepInvalid ? Color(UIColor.systemGray4) : VehicleStudioTheme.accent)
                        )
                    }
                    .buttonStyle(VehiclePressableStyle())
                    .disabled(stepInvalid)
                } else {
                    Button {
                        viewModel.saveVehicle()
                        dismiss()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: isEditing ? "checkmark.circle.fill" : "plus.circle.fill")
                                .font(.system(size: 14, weight: .semibold))
                            Text(isEditing ? "Save Changes" : "Add Vehicle")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(canSave ? VehicleStudioTheme.accent : Color(UIColor.systemGray4))
                        )
                    }
                    .buttonStyle(VehiclePressableStyle())
                    .disabled(!canSave)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemGroupedBackground))
        }
    }

    // MARK: - Step 1: Vehicle Identity
    private var step1View: some View {
        Form {
            Section {
                inlineField("Display Name", placeholder: "e.g. Truck Alpha", text: $viewModel.displayName)
                inlineField("Plate Number", placeholder: "e.g. MH12AB1234", text: $viewModel.plateNumber, autocap: .characters)
                inlineField("Model", placeholder: "e.g. Tata Ace", text: $viewModel.model)
            } header: {
                Text("Basic Info")
            }

            Section {
                inlineField("Manufacturer", placeholder: "e.g. Tata Motors", text: $viewModel.manufacturer)
                inlineField("Year", placeholder: "e.g. 2022", text: $viewModel.vehicleYear, keyboard: .numberPad)
                Picker("Vehicle Type", selection: $viewModel.vehicleType) {
                    ForEach(["Truck", "Van", "SUV", "Sedan", "Bus", "Pickup"], id: \.self) { Text($0).tag($0) }
                }
                inlineField("VIN / Chassis No.", placeholder: "e.g. MALA851HXNM123456", text: $viewModel.vinNumber, autocap: .characters)
                Picker("Fuel Type", selection: $viewModel.fuelType) {
                    ForEach(["Diesel", "Petrol", "CNG", "Electric", "Hybrid"], id: \.self) { Text($0).tag($0) }
                }
            } header: {
                Text("Vehicle Details")
            } footer: {
                Text("VIN uniquely identifies this vehicle in your fleet records.")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Step 2: Assignment & Operations
    private var step2View: some View {
        Form {
            Section {
                inlineField("Odometer (km)", placeholder: "e.g. 52000", text: $viewModel.odometer, keyboard: .numberPad)
                inlineField("Fuel Consumption (L/100km)", placeholder: "e.g. 8.5", text: $viewModel.fuelConsumption, keyboard: .decimalPad)
                inlineField("Utilization (%)", placeholder: "e.g. 75", text: $viewModel.utilization, keyboard: .numberPad)
            } header: {
                Text("Operations")
            } footer: {
                Text("Fuel level is tracked automatically via telemetry.")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Step 3: Compliance Documents
    private var step3View: some View {
        Form {
            Section {
                Text("All documents are recommended for vehicle compliance. You can also add them later from the vehicle profile.")
                    .font(.footnote)
                    .foregroundStyle(Color(UIColor.secondaryLabel))
            }

            ForEach(DocumentType.allCases) { docType in
                let number = viewModel.documentNumbers[docType] ?? ""
                let expiry = viewModel.documentExpiries[docType] ?? Date.now.addingTimeInterval(86400 * 120)
                let hasDoc = !number.trimmingCharacters(in: .whitespaces).isEmpty

                Section {
                    inlineField(
                        "Document Number",
                        placeholder: exampleNumberFor(docType),
                        text: Binding(
                            get: { viewModel.documentNumbers[docType] ?? "" },
                            set: { viewModel.documentNumbers[docType] = $0 }
                        ),
                        autocap: .characters
                    )

                    DatePicker(
                        "Expiry Date",
                        selection: Binding(
                            get: { viewModel.documentExpiries[docType] ?? Date.now.addingTimeInterval(86400 * 120) },
                            set: { viewModel.documentExpiries[docType] = $0 }
                        ),
                        displayedComponents: .date
                    )

                    // Upload row
                    Button {
                        viewModel.activeDocumentTypeForPhoto = docType
                        isPresentingPhotoSource = true
                    } label: {
                        HStack(spacing: 10) {
                            if let img = viewModel.documentImages[docType] as? UIImage {
                                Image(uiImage: img)
                                    .resizable().scaledToFill()
                                    .frame(width: 32, height: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: 7))
                                Text("Replace Photo").foregroundStyle(VehicleStudioTheme.accent)
                            } else if let urlString = viewModel.documentImageURLs[docType], let url = URL(string: urlString) {
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let image):
                                        image.resizable().scaledToFill()
                                            .frame(width: 32, height: 32)
                                            .clipShape(RoundedRectangle(cornerRadius: 7))
                                    default:
                                        Image(systemName: "doc.text").foregroundStyle(VehicleStudioTheme.accent)
                                    }
                                }
                                Text("Replace Photo").foregroundStyle(VehicleStudioTheme.accent)
                            } else {
                                Image(systemName: "doc.badge.plus").foregroundStyle(VehicleStudioTheme.accent)
                                Text("Attach Document").foregroundStyle(VehicleStudioTheme.accent)
                            }
                            
                            if viewModel.uploadingDocuments.contains(docType) {
                                Spacer()
                                ProgressView()
                            }
                            Spacer()
                        }
                    }
                    .buttonStyle(.plain)

                    // Expiry status
                    let daysLeft = Calendar.current.dateComponents([.day], from: .now, to: expiry).day ?? 0
                    HStack(spacing: 5) {
                        if daysLeft < 0 {
                            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.red).font(.caption2)
                            Text("Expired \(-daysLeft)d ago").font(.caption).foregroundStyle(.red)
                        } else if daysLeft <= 30 {
                            Image(systemName: "clock.badge.exclamationmark").foregroundStyle(.orange).font(.caption2)
                            Text("Expires in \(daysLeft) days").font(.caption).foregroundStyle(.orange)
                        } else {
                            Image(systemName: "checkmark.shield.fill").foregroundStyle(.green).font(.caption2)
                            Text("Valid · \(daysLeft) days remaining").font(.caption).foregroundStyle(.green)
                        }
                        Spacer()
                        if hasDoc {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundStyle(VehicleStudioTheme.success)
                        }
                    }
                    .listRowSeparator(.hidden)
                } header: {
                    Label(docType.rawValue, systemImage: docTypeIcon(docType))
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Driver Picker Sheet
    private var driverPickerSheet: some View {
        NavigationStack {
            List {
                Button {
                    viewModel.assignedDriverID = nil
                    showDriverPicker = false
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color(UIColor.systemGray5)).frame(width: 36, height: 36)
                            Image(systemName: "person.slash").font(.system(size: 14)).foregroundStyle(Color(UIColor.secondaryLabel))
                        }
                        Text("Unassigned").foregroundStyle(Color(UIColor.label))
                        Spacer()
                        if viewModel.assignedDriverID == nil {
                            Image(systemName: "checkmark").foregroundStyle(VehicleStudioTheme.accent).font(.system(size: 14, weight: .semibold))
                        }
                    }
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                ForEach(filteredDrivers) { driver in
                    Button {
                        viewModel.assignedDriverID = driver.id
                        showDriverPicker = false
                    } label: {
                        HStack(spacing: 12) {
                            AvatarView(name: driver.name, size: 36, customColor: VehicleStudioTheme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(driver.name).font(.subheadline.weight(.medium)).foregroundStyle(Color(UIColor.label))
                                Text(driver.title).font(.caption).foregroundStyle(Color(UIColor.secondaryLabel))
                            }
                            Spacer()
                            if viewModel.assignedDriverID == driver.id {
                                Image(systemName: "checkmark").foregroundStyle(VehicleStudioTheme.accent).font(.system(size: 14, weight: .semibold))
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }
            }
            .searchable(text: $driverSearchText, prompt: "Search drivers")
            .navigationTitle("Assign Driver")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showDriverPicker = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var filteredDrivers: [User] {
        if driverSearchText.isEmpty { return viewModel.drivers }
        return viewModel.drivers.filter {
            $0.name.localizedCaseInsensitiveContains(driverSearchText) ||
            $0.title.localizedCaseInsensitiveContains(driverSearchText)
        }
    }

    // MARK: - Helpers
    private func inlineField(_ label: String, placeholder: String, text: Binding<String>, keyboard: UIKeyboardType = .default, autocap: TextInputAutocapitalization = .words) -> some View {
        HStack {
            Text(label).foregroundStyle(Color(UIColor.label))
            Spacer()
            TextField(placeholder, text: text)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(Color(UIColor.secondaryLabel))
                .keyboardType(keyboard)
                .textInputAutocapitalization(autocap)
                .autocorrectionDisabled()
        }
    }

    private func docTypeIcon(_ type: DocumentType) -> String {
        switch type {
        case .rc: return "car.fill"
        case .insurance: return "shield.fill"
        case .puc: return "leaf.fill"
        case .permit: return "checkmark.seal.fill"
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
    @State private var selectedDocumentForPreview: VehicleDocument? = nil

    var body: some View {
        if let vehicle = viewModel.vehicle(for: vehicleID) {
            List {
                // Section 1: Hero Header
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(vehicle.status.dashboardColor.opacity(0.12))
                                .frame(width: 60, height: 60)
                            Image(systemName: vehicle.status == .outOfService ? "wrench.and.screwdriver.fill" : "car.side.fill")
                                .font(.title2)
                                .foregroundStyle(vehicle.status.dashboardColor)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(vehicle.displayName)
                                .font(.headline)
                            Text(vehicle.plateNumber)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(vehicle.model)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    
                    LabeledContent("Status") {
                        Text(vehicle.status.rawValue.capitalized)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(vehicle.status.dashboardColor)
                    }
                    
                    LabeledContent("Telemetry") {
                        Text(viewModel.isLiveTracked(vehicle) ? "Live Tracking" : "Standby")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(viewModel.isLiveTracked(vehicle) ? Color.blue : Color.secondary)
                    }
                }
                
                // Section 2: Metrics
                Section("Metrics") {
                    LabeledContent {
                        Text("\(vehicle.fuelLevel)%")
                            .foregroundStyle(fuelTint(for: vehicle.fuelLevel))
                    } label: {
                        Label("Fuel Level", systemImage: "fuelpump.fill")
                    }
                    
                    LabeledContent {
                        Text("\(vehicle.utilization)%")
                    } label: {
                        Label("Utilization", systemImage: "speedometer")
                    }
                    
                    let days = viewModel.maintenanceDaysRemaining(for: vehicle)
                    LabeledContent {
                        Text(serviceLabel(for: days))
                            .foregroundStyle(serviceTint(for: days))
                    } label: {
                        Label("Service Due", systemImage: "calendar")
                    }
                }
                
                // Section 3: Assignment
                Section("Assignment") {
                    LabeledContent {
                        Text(viewModel.driverName(for: vehicle))
                    } label: {
                        Label("Assigned Driver", systemImage: "person.fill")
                    }
                    
                    LabeledContent {
                        Text(viewModel.routeText(for: vehicle))
                    } label: {
                        Label("Route Context", systemImage: "point.topleft.down.curvedto.point.bottomright.up.fill")
                    }
                }
                
                // Section 4: Quick Actions
                Section("Quick Actions") {
                    Button {
                        activeSheet = .liveView
                    } label: {
                        Label("Live View", systemImage: "viewfinder")
                    }
                    
                    Button {
                        activeSheet = .tripDetails
                    } label: {
                        Label("Trip Details", systemImage: "doc.text.magnifyingglass")
                    }
                    
                    Button {
                        activeSheet = .ping
                    } label: {
                        Label("Ping Telemetry", systemImage: "antenna.radiowaves.left.and.right")
                    }
                    
                    Button {
                        activeSheet = .insights
                    } label: {
                        Label("Attention & Insights", systemImage: "sparkles")
                    }
                }
                
                // Section 5: Documents
                Section {
                    let documents = viewModel.documents(for: vehicle.id)
                    if documents.isEmpty {
                        Text("No compliance documents uploaded yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(documents) { document in
                            Button {
                                selectedDocumentForPreview = document
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(document.type.rawValue)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Color(.label))
                                        Text(document.documentNumber)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    
                                    Spacer()
                                    
                                    VStack(alignment: .trailing, spacing: 4) {
                                        Text(document.expiryDate.formatted(.dateTime.month(.abbreviated).day()))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Text(document.isVerified ? "Verified" : "Pending")
                                            .font(.caption2.weight(.bold))
                                            .foregroundStyle(document.isVerified ? Color.green : Color.orange)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } header: {
                    HStack {
                        Text("Documents")
                        Spacer()
                        Button("Upload") {
                            viewModel.prepareForDocumentUpload(for: vehicle.id)
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.blue)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Vehicle Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.prepareForEdit(vehicle)
                        showEditSheet = true
                    } label: {
                        Text("Edit")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(Color.blue)
                    }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                VehicleFormSheet(viewModel: viewModel)
                    .registersSheetPresentation()
            }
            .sheet(isPresented: $viewModel.isPresentingDocumentSheet) {
                DocumentUploadSheet(viewModel: viewModel, vehicleID: vehicleID)
                    .registersSheetPresentation()
            }
            .sheet(item: $selectedDocumentForPreview) { document in
                DocumentPreviewSheet(document: document, viewModel: viewModel)
                    .registersSheetPresentation()
            }
            .sheet(item: $activeSheet) { sheet in
                NavigationStack {
                    ZStack {
                        Color(UIColor.systemGroupedBackground)
                            .ignoresSafeArea()
                        
                        if sheet == .insights {
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
                .registersSheetPresentation()
            }
        } else {
            VehicleEmptyStateCard(
                icon: "car.2",
                title: "Vehicle not found",
                message: "This record is no longer available in the fleet inventory."
            )
            .padding(16)
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
                        value: viewModel.routeText(for: vehicle)
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

    private func documentsSection(for vehicle: Vehicle) -> some View {
        NativeDetailCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Documents")
                        .font(.headline)
                        .foregroundStyle(Color(.label))
                    Spacer()
                    Button("Upload") {
                        viewModel.prepareForDocumentUpload(for: vehicle.id)
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
                        Button {
                            selectedDocumentForPreview = document
                        } label: {
                            HStack(spacing: 12) {
                                DocumentMiniatureThumbnailView(document: document, viewModel: viewModel)

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
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

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
    
    @State private var isPresentingPhotoSource = false
    @State private var isPresentingCamera = false
    @State private var capturedImage: UIImage? = nil

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
                        viewModel.uploadImage(image, for: type)
                    }
                    selectedPhotoItem = nil
                }
            }
            .confirmationDialog(
                "Select Photo Source",
                isPresented: $isPresentingPhotoSource,
                titleVisibility: .visible
            ) {
                Button("Take Photo (Camera)") {
                    isPresentingCamera = true
                }
                Button("Choose from Library") {
                    viewModel.isPresentingImagePicker = true
                }
                Button("Cancel", role: .cancel) {}
            }
            .fullScreenCover(isPresented: $isPresentingCamera) {
                CameraView(image: $capturedImage) { image in
                    if let type = viewModel.activeDocumentTypeForPhoto {
                        viewModel.uploadImage(image, for: type)
                    }
                }
                .ignoresSafeArea()
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
                        if viewModel.uploadingDocuments.contains(type) {
                            ProgressView()
                                .frame(width: 80, height: 80)
                                .background(RoundedRectangle(cornerRadius: 12).fill(VehicleStudioTheme.softFill))
                        } else if viewModel.documentImages[type] != nil || viewModel.documentImageURLs[type] != nil {
                            DocumentThumbnailView(type: type, viewModel: viewModel)
                            
                            Button(role: .destructive) {
                                withAnimation {
                                    viewModel.documentImages[type] = nil
                                    viewModel.documentImageURLs[type] = nil
                                }
                            } label: {
                                Label("Remove", systemImage: "trash")
                                    .font(.caption.weight(.semibold))
                            }
                        } else {
                            Button {
                                viewModel.activeDocumentTypeForPhoto = type
                                isPresentingPhotoSource = true
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
                    .foregroundStyle(isSelected ? .white : Color.accentColor)
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
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
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

private struct DocumentPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    let document: VehicleDocument
    let viewModel: VehicleManagementViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let uiImage = loadLocalImage() {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding()
                } else if let imageUrlString = document.imageUrl,
                          !imageUrlString.hasPrefix("mock-local") && !imageUrlString.hasPrefix("file"),
                          let url = URL(string: imageUrlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .padding()
                        case .failure:
                            VStack(spacing: 12) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.red)
                                Text("Failed to load document image")
                                    .font(.headline)
                            }
                        case .empty:
                            ProgressView()
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    PremiumDocumentCardView(document: document)
                }
            }
            .navigationTitle(document.type.rawValue)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
        }
    }

    private func loadLocalImage() -> UIImage? {
        if let localImage = viewModel.documentImages[document.type] as? UIImage {
            return localImage
        }
        
        guard let imageUrlString = document.imageUrl else { return nil }
        
        if imageUrlString.hasPrefix("file://") {
            if let url = URL(string: imageUrlString),
               let data = try? Data(contentsOf: url) {
                return UIImage(data: data)
            }
        } else if imageUrlString.hasPrefix("mock-local://") {
            let parts = imageUrlString.replacingOccurrences(of: "mock-local://", with: "").split(separator: "/")
            if parts.count >= 3 {
                let vehicleIDString = String(parts[1])
                let typeString = String(parts[2])
                let fileManager = FileManager.default
                if let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
                    let fileURL = cachesDir.appendingPathComponent("vehicle-documents/\(vehicleIDString)/\(typeString)")
                    if let data = try? Data(contentsOf: fileURL) {
                        return UIImage(data: data)
                    }
                }
            }
        } else {
            // Check if direct path
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: imageUrlString) {
                if let data = try? Data(contentsOf: URL(fileURLWithPath: imageUrlString)) {
                    return UIImage(data: data)
                }
            }
        }
        return nil
    }
}

private struct PremiumDocumentCardView: View {
    let document: VehicleDocument
    
    var body: some View {
        VStack(spacing: 24) {
            // A beautiful badge card
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .font(.title)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    
                    Text("OFFICIAL DOCUMENT")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.2))
                        .clipShape(Capsule())
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 6) {
                    Text(document.type.rawValue)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    
                    Text("NUMBER: \(document.documentNumber)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.9))
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("EXPIRY DATE")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.7))
                        Text(document.expiryDate.formatted(.dateTime.year().month().day()))
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    
                    Spacer()
                    
                    if document.isVerified {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.green)
                            Text("Verified")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.2))
                        .clipShape(Capsule())
                    }
                }
            }
            .padding(24)
            .frame(width: 320, height: 200)
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 5)
            
            Text("No photo has been uploaded for this document yet.")
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding()
    }
}

private struct DocumentThumbnailView: View {
    let type: DocumentType
    let viewModel: VehicleManagementViewModel
    
    var body: some View {
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
        } else if let urlString = viewModel.documentImageURLs[type] {
            if let localImage = loadLocalImage(urlString: urlString) {
                Image(uiImage: localImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(VehicleStudioTheme.stroke.opacity(0.5), lineWidth: 1)
                    )
            } else if !urlString.hasPrefix("mock-local") && !urlString.hasPrefix("file"), let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    default:
                        defaultPlaceholder
                    }
                }
            } else {
                defaultPlaceholder
            }
        } else {
            defaultPlaceholder
        }
    }
    
    private var defaultPlaceholder: some View {
        Image(systemName: "doc.text")
            .frame(width: 80, height: 80)
            .background(Color.red.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private func loadLocalImage(urlString: String) -> UIImage? {
        if urlString.hasPrefix("file://") {
            if let url = URL(string: urlString),
               let data = try? Data(contentsOf: url) {
                return UIImage(data: data)
            }
        } else if urlString.hasPrefix("mock-local://") {
            let parts = urlString.replacingOccurrences(of: "mock-local://", with: "").split(separator: "/")
            if parts.count >= 3 {
                let vehicleIDString = String(parts[1])
                let typeString = String(parts[2])
                let fileManager = FileManager.default
                if let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
                    let fileURL = cachesDir.appendingPathComponent("vehicle-documents/\(vehicleIDString)/\(typeString)")
                    if let data = try? Data(contentsOf: fileURL) {
                        return UIImage(data: data)
                    }
                }
            }
        }
        return nil
    }
}

private struct DocumentMiniatureThumbnailView: View {
    let document: VehicleDocument
    let viewModel: VehicleManagementViewModel
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(UIColor.systemGray6))
            
            if let image = loadLocalImage() {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 42, height: 42)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else if let imageUrlString = document.imageUrl,
                      !imageUrlString.hasPrefix("mock-local") && !imageUrlString.hasPrefix("file"),
                      let url = URL(string: imageUrlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 42, height: 42)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    default:
                        defaultIcon
                    }
                }
            } else {
                defaultIcon
            }
        }
        .frame(width: 42, height: 42)
    }
    
    private var defaultIcon: some View {
        Image(systemName: "doc.text.fill")
            .foregroundStyle(Color.blue)
    }
    
    private func loadLocalImage() -> UIImage? {
        if let localImage = viewModel.documentImages[document.type] as? UIImage {
            return localImage
        }
        guard let imageUrlString = document.imageUrl else { return nil }
        if imageUrlString.hasPrefix("file://") {
            if let url = URL(string: imageUrlString),
               let data = try? Data(contentsOf: url) {
                return UIImage(data: data)
            }
        } else if imageUrlString.hasPrefix("mock-local://") {
            let parts = imageUrlString.replacingOccurrences(of: "mock-local://", with: "").split(separator: "/")
            if parts.count >= 3 {
                let vehicleIDString = String(parts[1])
                let typeString = String(parts[2])
                let fileManager = FileManager.default
                if let cachesDir = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
                    let fileURL = cachesDir.appendingPathComponent("vehicle-documents/\(vehicleIDString)/\(typeString)")
                    if let data = try? Data(contentsOf: fileURL) {
                        return UIImage(data: data)
                    }
                }
            }
        }
        return nil
    }
}
