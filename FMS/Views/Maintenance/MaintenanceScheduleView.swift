import SwiftUI

struct MaintenanceScheduleView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @State private var isShowingAddSheet = false

    var body: some View {
        List {
            ForEach(appViewModel.service.schedules()) { schedule in
                let vehicle = appViewModel.service.vehicle(for: schedule.vehicleID)
                GlassCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(schedule.serviceType)
                                .font(.headline)
                                .foregroundStyle(AppTheme.textPrimary)
                            Text(vehicle?.displayName ?? "Vehicle")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 4) {
                            Text(schedule.status.rawValue)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(schedule.status == .overdue ? AppTheme.error : AppTheme.brand)
                            Text(schedule.dueDate.formatted(date: .abbreviated, time: .omitted))
                                .font(.footnote)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing) {
                    if schedule.status != .completed {
                        Button {
                            markScheduleCompleted(schedule)
                        } label: {
                            Label("Complete", systemImage: "checkmark.circle.fill")
                        }
                        .tint(AppTheme.success)
                    }

                    Button(role: .destructive) {
                        appViewModel.service.deleteMaintenanceSchedule(schedule)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .appListStyle()
        .refreshable {
            await appViewModel.service.syncMaintenanceData()
        }
        .task {
            await appViewModel.service.syncMaintenanceData()
        }
        .navigationTitle("Schedules")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                }
            }
        }
        .sheet(isPresented: $isShowingAddSheet) {
            NavigationStack {
                AddMaintenanceScheduleSheet()
                    .environment(appViewModel)
            }
        }
    }

    private func markScheduleCompleted(_ schedule: MaintenanceSchedule) {
        var updated = schedule
        updated.status = .completed
        appViewModel.service.updateMaintenanceSchedule(updated)
    }
}

// MARK: - Add Schedule Sheet

private struct AddMaintenanceScheduleSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel

    @State private var selectedVehicleID: UUID?
    @State private var serviceType = ""
    @State private var dueDate = Date()

    private var accent: Color { Color(hex: "#FF5A1F") }

    var body: some View {
        Form {
            Section("Vehicle") {
                Picker("Select Vehicle", selection: $selectedVehicleID) {
                    Text("Select a vehicle").tag(nil as UUID?)
                    ForEach(appViewModel.service.vehicles()) { vehicle in
                        Text("\(vehicle.displayName) (\(vehicle.plateNumber))").tag(vehicle.id as UUID?)
                    }
                }
            }

            Section("Service Details") {
                TextField("Service Type (e.g. Oil Change, Brake Inspection)", text: $serviceType)
                DatePicker("Due Date", selection: $dueDate, displayedComponents: .date)
            }
        }
        .navigationTitle("Add Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Add") {
                    addSchedule()
                }
                .font(.body.weight(.bold))
                .foregroundStyle(accent)
                .disabled(selectedVehicleID == nil || serviceType.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private func addSchedule() {
        guard let vehicleID = selectedVehicleID else { return }
        appViewModel.service.addMaintenanceSchedule(
            vehicleID: vehicleID,
            serviceType: serviceType.trimmingCharacters(in: .whitespaces),
            dueDate: dueDate
        )
        dismiss()
    }
}

#Preview {
    NavigationStack {
        MaintenanceScheduleView()
            .environment(AppViewModel())
    }
}
