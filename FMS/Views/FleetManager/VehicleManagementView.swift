import SwiftUI

struct VehicleManagementView: View {
    @StateObject private var viewModel: VehicleManagementViewModel

    init(service: MockDataService, currentOrgID: UUID?) {
        _viewModel = StateObject(wrappedValue: VehicleManagementViewModel(service: service, currentOrgID: currentOrgID))
    }

    var body: some View {
        List {
            Section {
                ForEach(viewModel.filteredVehicles) { vehicle in
                    NavigationLink(destination: VehicleDetailView(viewModel: viewModel, vehicleID: vehicle.id)) {
                        GlassCard {
                            HStack {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(vehicle.displayName)
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Text(vehicle.plateNumber)
                                        .font(.subheadline)
                                        .foregroundStyle(AppTheme.textSecondary)
                                    Text(viewModel.user(for: vehicle.assignedDriverID)?.name ?? "Unassigned")
                                        .font(.footnote)
                                        .foregroundStyle(AppTheme.brand)
                                }
                                Spacer()
                                Text(vehicle.status.rawValue)
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(vehicle.status == .active ? AppTheme.success : AppTheme.warning)
                            }
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.deleteVehicle(vehicle)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            viewModel.prepareForEdit(vehicle)
                        } label: {
                            Label("Edit", systemImage: "pencil")
                        }
                        .tint(AppTheme.brand)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            } header: {
                Text("Fleet Assets")
            }
        }
        .appListStyle()
        .searchable(text: $viewModel.searchText)
        .navigationTitle("Vehicle Management")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    viewModel.prepareForAdd()
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(AppTheme.brand)
                }
            }
        }
        .sheet(isPresented: $viewModel.isPresentingForm) {
            VehicleFormSheet(viewModel: viewModel)
        }
    }
}

private struct VehicleFormSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: VehicleManagementViewModel

    var body: some View {
        NavigationStack {
            Form {
                Section("Vehicle Details") {
                    TextField("Display Name", text: $viewModel.displayName)
                    TextField("Plate Number", text: $viewModel.plateNumber)
                    TextField("Model", text: $viewModel.model)
                    Picker("Status", selection: $viewModel.status) {
                        ForEach(VehicleStatus.allCases, id: \.self) { value in
                            Text(value.rawValue).tag(value)
                        }
                    }
                    TextField("Odometer", text: $viewModel.odometer)
                        .keyboardType(.numberPad)
                }

                Section("Assignment") {
                    Picker("Assigned Driver", selection: $viewModel.assignedDriverID) {
                        Text("Unassigned").tag(Optional<UUID>.none)
                        ForEach(viewModel.drivers) { driver in
                            Text(driver.name).tag(Optional(driver.id))
                        }
                    }
                    DatePicker("Next Service", selection: $viewModel.nextServiceDate, displayedComponents: .date)
                    VStack(alignment: .leading) {
                        Text("Fuel Level")
                        Slider(value: $viewModel.fuelLevel, in: 0...100, step: 1)
                    }
                    VStack(alignment: .leading) {
                        Text("Utilization")
                        Slider(value: $viewModel.utilization, in: 0...100, step: 1)
                    }
                }
            }
            .navigationTitle(viewModel.selectedVehicle == nil ? "Add Vehicle" : "Edit Vehicle")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(viewModel.selectedVehicle == nil ? "Add" : "Save") {
                        viewModel.saveVehicle()
                        dismiss()
                    }
                    .disabled(viewModel.displayName.isEmpty || viewModel.plateNumber.isEmpty || viewModel.model.isEmpty || Int(viewModel.odometer) == nil)
                }
            }
        }
    }
}

private struct VehicleDetailView: View {
    @ObservedObject var viewModel: VehicleManagementViewModel
    let vehicleID: UUID

    private var vehicle: Vehicle? {
        viewModel.vehicle(for: vehicleID)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let vehicle {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(vehicle.displayName)
                                .font(.title3.weight(.bold))
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(vehicle.plateNumber)
                                .foregroundStyle(AppTheme.textSecondary)
                            Text("Assigned Driver: \(viewModel.user(for: vehicle.assignedDriverID)?.name ?? "Unassigned")")
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    SectionTitle(title: "Documents", subtitle: "RC, insurance, PUC, and permits")

                    let docs = viewModel.documents(for: vehicle.id)
                    if docs.isEmpty {
                        EmptyStateView(icon: "doc.text", title: "No documents uploaded", message: "Use the upload action to attach vehicle records.")
                    } else {
                        ForEach(docs) { document in
                            GlassCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(document.type.rawValue)
                                            .font(.headline)
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Text(document.documentNumber)
                                            .font(.subheadline)
                                            .foregroundStyle(AppTheme.textSecondary)
                                    }
                                    Spacer()
                                    Text(document.expiryDate.formatted(date: .abbreviated, time: .omitted))
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(document.isVerified ? AppTheme.success : AppTheme.warning)
                                }
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .navigationTitle("Vehicle Detail")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Upload") {
                    viewModel.prepareForDocumentUpload()
                }
                .foregroundStyle(AppTheme.brand)
            }
        }
        .sheet(isPresented: $viewModel.isPresentingDocumentSheet) {
            if let vehicle {
                DocumentUploadSheet(viewModel: viewModel, vehicleID: vehicle.id)
            }
        }
    }
}

private struct DocumentUploadSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: VehicleManagementViewModel
    let vehicleID: UUID

    var body: some View {
        NavigationStack {
            Form {
                Picker("Document Type", selection: $viewModel.docType) {
                    ForEach(DocumentType.allCases) { type in
                        Text(type.rawValue).tag(type)
                    }
                }
                TextField("Document Number", text: $viewModel.docNumber)
                DatePicker("Expiry Date", selection: $viewModel.docExpiryDate, displayedComponents: .date)
            }
            .navigationTitle("Upload Document")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        viewModel.saveDocument(for: vehicleID)
                        dismiss()
                    }
                    .disabled(viewModel.docNumber.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        VehicleManagementView(service: MockDataService(), currentOrgID: UUID())
    }
}
