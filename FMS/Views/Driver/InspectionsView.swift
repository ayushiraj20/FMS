import SwiftUI

struct InspectionsView: View {
    @Environment(AppViewModel.self) private var appViewModel: AppViewModel
    @State private var isPresentingInspectionSheet = false
    @State private var isPresentingDefectSheet = false

    private var currentUser: User? { appViewModel.currentUser }
    private var records: [InspectionRecord] {
        guard let currentUser else { return [] }
        return appViewModel.service.inspections.filter { $0.driverID == currentUser.id }.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            Section {
                Button("Run New Inspection") {
                    isPresentingInspectionSheet = true
                }
                .foregroundStyle(AppTheme.brand)

                Button("Report Vehicle Defect") {
                    isPresentingDefectSheet = true
                }
                .foregroundStyle(AppTheme.warning)
            }

            Section("History") {
                if records.isEmpty {
                    EmptyStateView(icon: "checklist", title: "No inspections yet", message: "Your completed pre-trip and post-trip inspections will appear here.")
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(records) { record in
                        GlassCard {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text(record.type.rawValue)
                                        .font(.headline)
                                        .foregroundStyle(AppTheme.textPrimary)
                                    Spacer()
                                    Text(record.passed ? "Passed" : "Attention Needed")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(record.passed ? AppTheme.success : AppTheme.warning)
                                }
                                Text(record.notes)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textSecondary)
                                Text(record.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.footnote)
                                    .foregroundStyle(AppTheme.textSecondary.opacity(0.8))
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
            }
        }
        .appListStyle()
        .navigationTitle("Inspections")
        .sheet(isPresented: $isPresentingInspectionSheet) {
            NewInspectionSheet()
                .environment(appViewModel)
        }
        .sheet(isPresented: $isPresentingDefectSheet) {
            DefectReportSheet()
                .environment(appViewModel)
        }
    }
}

private struct NewInspectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel: AppViewModel

    @State private var inspectionType: InspectionType = .preTrip
    @State private var notes = ""
    @State private var items = [
        InspectionItem(id: UUID(), title: "Brakes and parking brake", isChecked: true),
        InspectionItem(id: UUID(), title: "Lights and reflectors", isChecked: true),
        InspectionItem(id: UUID(), title: "Tyres and wheels", isChecked: true),
        InspectionItem(id: UUID(), title: "Mirrors and reverse visibility", isChecked: true),
        InspectionItem(id: UUID(), title: "Leaks, fluids, and underbody", isChecked: true)
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("Inspection Type") {
                    Picker("Type", selection: $inspectionType) {
                        ForEach(InspectionType.allCases) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }

                Section("Checklist") {
                    ForEach($items) { $item in
                        Toggle(item.title, isOn: $item.isChecked)
                    }
                }

                Section("Notes") {
                    TextField("Observations", text: $notes, axis: .vertical)
                }
            }
            .navigationTitle("New Inspection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let user = appViewModel.currentUser,
                              let vehicleID = user.assignedVehicleID else { return }
                        appViewModel.service.addInspection(driverID: user.id, vehicleID: vehicleID, type: inspectionType, notes: notes, items: items)
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct DefectReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel: AppViewModel

    @State private var severity: WorkOrderPriority = .medium
    @State private var description = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Severity", selection: $severity) {
                    ForEach(WorkOrderPriority.allCases) { item in
                        Text(item.rawValue).tag(item)
                    }
                }
                TextField("Describe the defect", text: $description, axis: .vertical)
            }
            .navigationTitle("Report Defect")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        guard let user = appViewModel.currentUser,
                              let vehicleID = user.assignedVehicleID else { return }
                        appViewModel.service.addDefect(driverID: user.id, vehicleID: vehicleID, severity: severity, description: description)
                        dismiss()
                    }
                    .disabled(description.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        InspectionsView()
            .environment(AppViewModel())
    }
}
