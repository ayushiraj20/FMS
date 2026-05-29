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
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // Action Buttons
                VStack(spacing: 16) {
                    Button {
                        isPresentingInspectionSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title2)
                            Text("Run New Inspection")
                                .font(.system(.headline, design: .rounded).bold())
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(DriverTheme.accent, in: Capsule())
                        .shadow(color: DriverTheme.accent.opacity(0.3), radius: 8, y: 4)
                    }

                    Button {
                        isPresentingDefectSheet = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.title2)
                            Text("Report Vehicle Defect")
                                .font(.system(.headline, design: .rounded).bold())
                        }
                        .foregroundStyle(DriverTheme.warningAmber)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(DriverTheme.warningAmber.opacity(0.15), in: Capsule())
                        .overlay(Capsule().stroke(DriverTheme.warningAmber.opacity(0.3), lineWidth: 1))
                    }
                }
                .padding(.top, 16)

                // History Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("History")
                        .font(.system(.title2, design: .rounded).bold())
                        .foregroundStyle(DriverTheme.textPrimary)

                    if records.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checklist")
                                .font(.system(size: 48))
                                .foregroundStyle(DriverTheme.textSecondary.opacity(0.5))
                            Text("No inspections yet")
                                .font(.headline)
                            Text("Your completed pre-trip and post-trip inspections will appear here.")
                                .font(.subheadline)
                                .foregroundStyle(DriverTheme.textSecondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding(.vertical, 40)
                        .frame(maxWidth: .infinity)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))
                    } else {
                        LazyVStack(spacing: 16) {
                            ForEach(records) { record in
                                inspectionCard(record)
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
        .refreshable {
            await appViewModel.service.syncWithDatabase()
        }
        .background(DriverScreenBackground())
        .navigationTitle("Inspections")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $isPresentingInspectionSheet) {
            NewInspectionSheet()
                .environment(appViewModel)
        }
        .sheet(isPresented: $isPresentingDefectSheet) {
            DefectReportView()
                .environment(appViewModel)
        }
    }

    private func inspectionCard(_ record: InspectionRecord) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.type.rawValue)
                        .font(.system(.headline, design: .rounded).bold())
                        .foregroundStyle(DriverTheme.textPrimary)
                    Text(record.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(DriverTheme.textSecondary)
                }
                Spacer()
                Text(record.passed ? "Passed" : "Attention")
                    .font(.caption2.bold())
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(record.passed ? DriverTheme.successGreen.opacity(0.15) : DriverTheme.warningAmber.opacity(0.15), in: Capsule())
                    .foregroundStyle(record.passed ? DriverTheme.successGreen : DriverTheme.warningAmber)
            }

            if !record.notes.isEmpty {
                Text(record.notes)
                    .font(.subheadline)
                    .foregroundStyle(DriverTheme.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    // Type Selection
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Inspection Type")
                            .font(.system(.title3, design: .rounded).bold())
                        
                        HStack(spacing: 12) {
                            ForEach(InspectionType.allCases) { type in
                                let isSelected = inspectionType == type
                                Button {
                                    withAnimation { inspectionType = type }
                                } label: {
                                    Text(type.rawValue)
                                        .font(.system(.subheadline, design: .rounded).bold())
                                        .foregroundStyle(isSelected ? .white : DriverTheme.textPrimary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(isSelected ? DriverTheme.accent : DriverTheme.cardFill, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))

                    // Checklist
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Checklist")
                            .font(.system(.title3, design: .rounded).bold())
                        
                        VStack(spacing: 12) {
                            ForEach($items) { $item in
                                HStack {
                                    Text(item.title)
                                        .font(.system(.body, design: .rounded))
                                    Spacer()
                                    Toggle("", isOn: $item.isChecked)
                                        .labelsHidden()
                                        .tint(DriverTheme.successGreen)
                                }
                                .padding()
                                .background(DriverTheme.cardFill, in: RoundedRectangle(cornerRadius: 16))
                            }
                        }
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))

                    // Notes
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Notes")
                            .font(.system(.title3, design: .rounded).bold())
                        
                        TextEditor(text: $notes)
                            .frame(minHeight: 100)
                            .padding(8)
                            .background(DriverTheme.cardFill, in: RoundedRectangle(cornerRadius: 16))
                            .scrollContentBackground(.hidden)
                    }
                    .padding(20)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24))

                    // Save Button
                    Button {
                        guard let user = appViewModel.currentUser, let vehicle = appViewModel.assignedVehicle else { return }
                        appViewModel.service.addInspection(driverID: user.id, vehicleID: vehicle.id, type: inspectionType, notes: notes, items: items)
                        dismiss()
                    } label: {
                        Text("Save Inspection")
                            .font(.system(.title3, design: .rounded).bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(DriverTheme.accent, in: Capsule())
                    }
                }
                .padding(20)
            }
            .background(DriverTheme.background.ignoresSafeArea())
            .navigationTitle("New Inspection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
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
