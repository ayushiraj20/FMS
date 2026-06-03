import SwiftUI
import PhotosUI

struct DefectReportView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel

    @State private var issueType: DefectIssueType = .engine
    @State private var severity: WorkOrderPriority = .medium
    @State private var title = ""
    @State private var description = ""

    // Real image capture
    @State private var capturedImages: [UIImage] = []
    @State private var isShowingPhotoSource = false
    @State private var isShowingCamera = false
    @State private var cameraImage: UIImage? = nil
    @State private var selectedPhotoItems: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    if let vehicle = appViewModel.assignedVehicle {
                        HStack(spacing: 16) {
                            Image(systemName: "car.front.waves.up.fill")
                                .font(.title)
                                .foregroundStyle(DriverTheme.accent)
                                .frame(width: 60, height: 60)
                                .background(.ultraThinMaterial, in: Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Reporting for")
                                    .font(.subheadline)
                                    .foregroundStyle(DriverTheme.textSecondary)
                                Text("\(vehicle.plateNumber) — \(vehicle.displayName)")
                                    .font(.system(.title3, design: .rounded).bold())
                            }
                            Spacer()
                        }
                        .padding(20)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                    }

                    formSection(title: "Issue Details") {
                        VStack(alignment: .leading, spacing: 16) {
                            TextField("Enter title e.g. Brake noise", text: $title)
                                .font(.system(.body, design: .rounded))
                                .padding(16)
                                .background(DriverTheme.cardFill, in: RoundedRectangle(cornerRadius: 16))

                            Text("Issue Type")
                                .font(.subheadline.bold())
                                .foregroundStyle(DriverTheme.textSecondary)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(DefectIssueType.allCases) { type in
                                        Button {
                                            withAnimation {
                                                issueType = type
                                                if title.isEmpty { title = "\(type.rawValue) Issue" }
                                            }
                                        } label: {
                                            Text(type.rawValue)
                                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                                .foregroundStyle(issueType == type ? .white : DriverTheme.textPrimary)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(issueType == type ? DriverTheme.accent : DriverTheme.cardFill, in: Capsule())
                                                .shadow(color: issueType == type ? DriverTheme.accent.opacity(0.3) : .clear, radius: 8, y: 4)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    formSection(title: "Severity") {
                        HStack(spacing: 0) {
                            ForEach(WorkOrderPriority.allCases) { level in
                                let isSelected = severity == level
                                Button {
                                    withAnimation { severity = level }
                                } label: {
                                    Text(level.rawValue)
                                        .font(.system(.subheadline, design: .rounded).bold())
                                        .foregroundStyle(isSelected ? .white : DriverTheme.textSecondary)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(isSelected ? priorityColor(for: level) : .clear)
                                        .clipShape(Capsule())
                                        .contentShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(4)
                        .background(DriverTheme.cardFill, in: Capsule())
                    }

                    formSection(title: "Description") {
                        TextEditor(text: $description)
                            .frame(minHeight: 120)
                            .font(.system(.body, design: .rounded))
                            .padding(8)
                            .background(DriverTheme.cardFill, in: RoundedRectangle(cornerRadius: 16))
                            .scrollContentBackground(.hidden)
                    }

                    // MARK: - Photos (Camera + Gallery)
                    formSection(title: "Photos") {
                        VStack(alignment: .leading, spacing: 12) {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 16) {
                                    // Add Photo button — opens action sheet
                                    Button {
                                        isShowingPhotoSource = true
                                    } label: {
                                        VStack(spacing: 8) {
                                            Image(systemName: "camera.fill").font(.title2)
                                            Text("Add Photo").font(.caption.bold())
                                        }
                                        .foregroundStyle(DriverTheme.accent)
                                        .frame(width: 100, height: 100)
                                        .background(DriverTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(DriverTheme.accent.opacity(0.3), style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
                                    }

                                    // Captured image thumbnails
                                    ForEach(Array(capturedImages.enumerated()), id: \.offset) { index, img in
                                        ZStack(alignment: .topTrailing) {
                                            Image(uiImage: img)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .clipShape(RoundedRectangle(cornerRadius: 16))

                                            Button {
                                                withAnimation { _ = capturedImages.remove(at: index) }
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .font(.title3)
                                                    .foregroundStyle(DriverTheme.criticalRed, .white)
                                                    .padding(6)
                                            }
                                        }
                                        .transition(.scale.combined(with: .opacity))
                                    }
                                }
                                .padding(.vertical, 8)
                            }

                            if !capturedImages.isEmpty {
                                Text("\(capturedImages.count) photo\(capturedImages.count == 1 ? "" : "s") attached")
                                    .font(.caption)
                                    .foregroundStyle(DriverTheme.successGreen)
                            }
                        }
                    }

                    Button {
                        guard let user = appViewModel.currentUser, let vehicle = appViewModel.assignedVehicle else { return }
                        let issueTitle = title.isEmpty ? "\(issueType.rawValue) Defect" : title
                        appViewModel.service.addDefect(
                            driverID: user.id, vehicleID: vehicle.id, severity: severity,
                            description: "[\(issueType.rawValue)] \(description)", title: issueTitle,
                            photoImages: capturedImages.isEmpty ? nil : capturedImages
                        )
                        dismiss()
                    } label: {
                        Text("Submit Report")
                            .font(.system(.title3, design: .rounded).bold())
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .background(description.isEmpty ? Color.gray : DriverTheme.accent, in: Capsule())
                    }
                    .disabled(description.isEmpty)
                    .padding(.top, 16)
                }
                .padding(20)
            }
            .background(
                ZStack {
                    DriverTheme.background.ignoresSafeArea()
                    GeometryReader { geo in
                        Circle()
                            .fill(priorityColor(for: severity).opacity(0.1))
                            .frame(width: geo.size.width)
                            .blur(radius: 80)
                            .offset(x: geo.size.width * 0.2, y: -geo.size.height * 0.1)
                            .animation(.easeInOut, value: severity)
                    }
                    .ignoresSafeArea()
                }
            )
            .navigationTitle("Report Defect")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            // Action sheet: Camera vs Photo Library
            .confirmationDialog("Add Photo", isPresented: $isShowingPhotoSource, titleVisibility: .visible) {
                Button("Take Photo") {
                    isShowingCamera = true
                }
                Button("Choose from Library") {
                    // PhotosPicker is presented inline below
                    isShowingPhotoSource = false
                    // Trigger the PhotosPicker via the overlay modifier
                    showGalleryPicker = true
                }
                Button("Cancel", role: .cancel) { }
            }
            // Camera sheet
            .fullScreenCover(isPresented: $isShowingCamera) {
                CameraView(image: $cameraImage) { capturedImage in
                    withAnimation {
                        capturedImages.append(capturedImage)
                    }
                }
                .ignoresSafeArea()
            }
            // Gallery picker sheet
            .photosPicker(
                isPresented: $showGalleryPicker,
                selection: $selectedPhotoItems,
                maxSelectionCount: 5,
                matching: .images,
                photoLibrary: .shared()
            )
            .onChange(of: selectedPhotoItems) { _, newItems in
                Task {
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            await MainActor.run {
                                withAnimation {
                                    capturedImages.append(uiImage)
                                }
                            }
                        }
                    }
                    // Clear selection so user can pick again later
                    selectedPhotoItems.removeAll()
                }
            }
        }
    }

    @State private var showGalleryPicker = false

    private func formSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.title3, design: .rounded).bold())
            content()
        }
        .padding(20)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private func priorityColor(for priority: WorkOrderPriority) -> Color {
        switch priority {
        case .low: return DriverTheme.successGreen
        case .medium: return DriverTheme.warningAmber
        case .high, .critical: return DriverTheme.criticalRed
        }
    }
}

#Preview {
    DefectReportView()
        .environment(AppViewModel())
}
