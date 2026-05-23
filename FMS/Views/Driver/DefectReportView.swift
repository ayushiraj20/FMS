import SwiftUI

struct DefectReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel

    @State private var issueType: DefectIssueType = .engine
    @State private var severity: WorkOrderPriority = .medium
    @State private var title = ""
    @State private var description = ""
    @State private var uploadedImages: [String] = []

    private let sampleImages = ["brake_defect", "engine_smoke", "tire_wear", "scratch_defect"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Vehicle auto-filled
                    if let vehicle = appViewModel.assignedVehicle {
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

                    // Issue Title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Issue Title")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(DriverTheme.textPrimary)

                        TextField("e.g. Brake noise during driving", text: $title)
                            .font(.system(size: 15))
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(DriverTheme.cardFill)
                            )
                            .foregroundStyle(DriverTheme.textPrimary)
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
                                    if title.isEmpty {
                                        title = "\(type.rawValue) Issue"
                                    }
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

                    // Photo preview grid (if any uploaded)
                    if !uploadedImages.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Attached Photos")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(DriverTheme.textSecondary)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(uploadedImages, id: \.self) { img in
                                        ZStack(alignment: .topTrailing) {
                                            Image(systemName: "photo.fill")
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 70, height: 70)
                                                .foregroundStyle(DriverTheme.accent.opacity(0.4))
                                                .padding(10)
                                                .background(DriverTheme.cardFill)
                                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                            
                                            Button {
                                                withAnimation {
                                                    uploadedImages.removeAll { $0 == img }
                                                }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(DriverTheme.criticalRed)
                                                    .background(Circle().fill(.white))
                                                    .font(.system(size: 18))
                                            }
                                            .offset(x: 5, y: -5)
                                        }
                                    }
                                }
                                .padding(.top, 5)
                            }
                        }
                    }

                    // Add Photos
                    Button {
                        // Add a mock defect photo sequentially
                        let nextIndex = uploadedImages.count % sampleImages.count
                        let nextImg = sampleImages[nextIndex] + "_\(UUID().uuidString.prefix(4))"
                        withAnimation {
                            uploadedImages.append(nextImg)
                        }
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 18))
                            Text("Add Photo")
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
                              let vehicle = appViewModel.assignedVehicle else { return }
                        
                        let issueTitle = title.isEmpty ? "\(issueType.rawValue) Defect" : title
                        appViewModel.service.addDefect(
                            driverID: user.id,
                            vehicleID: vehicle.id,
                            severity: severity,
                            description: "[\(issueType.rawValue)] \(description)",
                            title: issueTitle,
                            images: uploadedImages.isEmpty ? nil : uploadedImages
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
        .environment(AppViewModel())
}
