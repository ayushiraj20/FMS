import SwiftUI

struct DefectReportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var issueType: DefectIssueType = .engine
    @State private var severity: WorkOrderPriority = .medium
    @State private var description = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Vehicle auto-filled
                    if let vehicle = appViewModel.service.vehicle(for: appViewModel.currentUser?.assignedVehicleID) {
                        DriverGlassCard {
                            HStack(spacing: 12) {
                                Image(systemName: "truck.box.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(DriverTheme.accent)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Vehicle")
                                        .font(.system(size: 13))
                                        .foregroundStyle(DriverTheme.textSecondary)
                                    Text("\(vehicle.plateNumber) — \(vehicle.displayName)")
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(DriverTheme.textPrimary)
                                }
                                Spacer()
                            }
                        }
                    }

                    // Issue Type
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Issue Type")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DriverTheme.textPrimary)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 8)], spacing: 8) {
                            ForEach(DefectIssueType.allCases) { type in
                                Button {
                                    issueType = type
                                } label: {
                                    Text(type.rawValue)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(issueType == type ? .white : DriverTheme.textPrimary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 10)
                                        .frame(maxWidth: .infinity)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .fill(issueType == type ? DriverTheme.accent : DriverTheme.cardFill)
                                        )
                                }
                            }
                        }
                    }

                    // Severity
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Severity")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DriverTheme.textPrimary)

                        Picker("Severity", selection: $severity) {
                            ForEach(WorkOrderPriority.allCases) { level in
                                Text(level.rawValue).tag(level)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DriverTheme.textPrimary)

                        TextEditor(text: $description)
                            .frame(minHeight: 100)
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(DriverTheme.cardFill)
                            )
                            .scrollContentBackground(.hidden)
                    }

                    // Add Photos
                    Button {
                        // Camera/library picker
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 18))
                            Text("Add Photos")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(DriverTheme.accent)
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(DriverTheme.cardFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(DriverTheme.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [8, 4]))
                                )
                        )
                    }

                    // Submit
                    Button("Submit") {
                        guard let user = appViewModel.currentUser,
                              let vehicleID = user.assignedVehicleID else { return }
                        appViewModel.service.addDefect(
                            driverID: user.id,
                            vehicleID: vehicleID,
                            severity: severity,
                            description: "[\(issueType.rawValue)] \(description)"
                        )
                        dismiss()
                    }
                    .buttonStyle(DriverAccentButtonStyle())
                    .disabled(description.isEmpty)
                    .opacity(description.isEmpty ? 0.5 : 1)
                }
                .padding(20)
            }
            .background(DriverTheme.background.ignoresSafeArea())
            .navigationTitle("Report Defect")
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
    DefectReportView()
        .environmentObject(AppViewModel())
}
