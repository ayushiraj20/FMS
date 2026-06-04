import SwiftUI

struct TripStartInspectionSheet: View {
    let trip: Trip?
    var inspectionType: InspectionType = .preTrip
    var onInspectionCompleted: () -> Void

    @Environment(AppViewModel.self) private var appViewModel
    @Environment(DriverViewModel.self) private var driverVM
    @Environment(\.dismiss) private var dismiss

    @State private var items: [InspectionItem2] = InspectionItem2.defaultList()
    @State private var overallNotes: String = ""
    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var submittedSuccessfully = false
    @State private var expandedItemID: UUID?

    private var allChecked: Bool { items.allSatisfy { $0.status != .unchecked } }
    private var checkedCount: Int { items.filter { $0.status != .unchecked }.count }
    private var failedItems: [InspectionItem2] { items.filter { $0.status == .failed } }
    private var progress: Double { Double(checkedCount) / Double(max(items.count, 1)) }

    var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Vehicle & Route Info"), footer: Text("Complete this checklist before \(inspectionType == .preTrip ? "starting" : "ending") your trip. Tap each item to mark Pass or Fail.")) {
                    if let vehicle = appViewModel.assignedVehicle {
                        HStack(spacing: 12) {
                            Image(systemName: "truck.box.fill")
                                .font(.title3)
                                .foregroundStyle(DriverTheme.accent)
                                .frame(width: 32, height: 32)
                                .background(DriverTheme.accent.opacity(0.1), in: Circle())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(vehicle.displayName)
                                    .font(.headline)
                                Text("Plate: \(vehicle.plateNumber)")
                                    .font(.subheadline)
                                    .foregroundStyle(DriverTheme.textSecondary)
                            }
                        }
                    }
                    
                    if let t = trip {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "map.fill")
                                    .font(.caption)
                                    .foregroundStyle(DriverTheme.accent)
                                Text("Route Details")
                                    .font(.caption.bold())
                                    .foregroundStyle(DriverTheme.textSecondary)
                            }
                            Text("\(t.origin) → \(t.destination)")
                                .font(.subheadline)
                                .foregroundStyle(DriverTheme.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section(header: Text("Progress")) {
                    progressSection
                }

                Section(header: Text("Checklist")) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                        itemRow(idx: idx, item: item)
                    }
                }

                Section(header: Text("Additional Notes")) {
                    TextField("e.g. Minor scratch on left door...", text: $overallNotes, axis: .vertical)
                        .lineLimit(3...6)
                        .font(.subheadline)
                }

                if !failedItems.isEmpty {
                    Section {
                        failureWarningSection
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(DriverScreenBackground())
            .navigationTitle("\(inspectionType.rawValue) Inspection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                submitButton
            }
            .alert("Critical Issues Found", isPresented: Binding(
                get: { !failedItems.isEmpty && submittedSuccessfully },
                set: { _ in }
            )) {
                Button("Proceed Anyway") { startTripAndDismiss() }
                Button("Cancel Trip", role: .cancel) { dismiss() }
            } message: {
                Text("You marked \(failedItems.count) item(s) as FAILED. Fleet Manager and Maintenance have been notified. Do you still want to proceed?")
            }
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ProgressView(value: progress)
                .tint(allChecked ? DriverTheme.successGreen : DriverTheme.accent)
            HStack {
                Text("\(checkedCount) of \(items.count) checked")
                    .font(.caption.bold())
                    .foregroundStyle(DriverTheme.textSecondary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(allChecked ? DriverTheme.successGreen : DriverTheme.accent)
            }
        }
        .padding(.vertical, 4)
    }

    private func itemRow(idx: Int, item: InspectionItem2) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                // Category Icon
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(
                        item.status == .passed ? DriverTheme.successGreen :
                        item.status == .failed ? DriverTheme.criticalRed :
                        DriverTheme.textSecondary
                    )
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.body.bold())
                    Text(item.hint)
                        .font(.caption)
                        .foregroundStyle(DriverTheme.textSecondary)
                }
                
                Spacer()
                
                // Explicit Pass / Fail selector buttons (Compact)
                HStack(spacing: 8) {
                    // Pass Button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            items[idx].status = (items[idx].status == .passed) ? .unchecked : .passed
                            expandedItemID = nil
                        }
                    } label: {
                        Image(systemName: item.status == .passed ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.title3)
                            .foregroundStyle(item.status == .passed ? DriverTheme.successGreen : DriverTheme.successGreen.opacity(0.4))
                            .frame(width: 36, height: 36)
                            .background(item.status == .passed ? DriverTheme.successGreen.opacity(0.1) : Color.clear, in: Circle())
                    }
                    .buttonStyle(.plain)
                    
                    // Fail Button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if items[idx].status == .failed {
                                items[idx].status = .unchecked
                                items[idx].failureNote = ""
                                expandedItemID = nil
                            } else {
                                items[idx].status = .failed
                                expandedItemID = item.id
                            }
                        }
                    } label: {
                        Image(systemName: item.status == .failed ? "xmark.circle.fill" : "xmark.circle")
                            .font(.title3)
                            .foregroundStyle(item.status == .failed ? DriverTheme.criticalRed : DriverTheme.criticalRed.opacity(0.4))
                            .frame(width: 36, height: 36)
                            .background(item.status == .failed ? DriverTheme.criticalRed.opacity(0.1) : Color.clear, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }

            if item.status == .failed {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Describe the issue:")
                        .font(.caption.bold())
                        .foregroundStyle(DriverTheme.textSecondary)
                    TextField("e.g. Brake feels spongy...", text: $items[idx].failureNote, axis: .vertical)
                        .font(.subheadline)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(.top, 4)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var failureWarningSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").font(.subheadline).foregroundStyle(DriverTheme.criticalRed)
                Text("\(failedItems.count) Issue(s) Reported").font(.subheadline.bold()).foregroundStyle(DriverTheme.criticalRed)
            }
            ForEach(failedItems) { fi in
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill").font(.caption).foregroundStyle(DriverTheme.criticalRed)
                    Text(fi.title + (fi.failureNote.isEmpty ? "" : ": \(fi.failureNote)")).font(.caption).foregroundStyle(DriverTheme.textPrimary)
                }
            }
            Text("These defects will be sent to Fleet Manager & Maintenance.")
                .font(.caption2)
                .foregroundStyle(DriverTheme.textSecondary)
        }
        .padding(12)
        .background(DriverTheme.criticalRed.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(DriverTheme.criticalRed.opacity(0.3), lineWidth: 1))
    }

    private var submitButton: some View {
        VStack(spacing: 12) {
            if let err = submitError {
                Text(err).font(.caption).foregroundStyle(DriverTheme.criticalRed)
            }
            Button {
                Task { await submitAndStart() }
            } label: {
                HStack(spacing: 12) {
                    if isSubmitting {
                        ProgressView()
                    }
                    Text(inspectionType == .preTrip ? "Start Trip" : "End Trip")
                        .font(.system(.headline, design: .rounded).bold())
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(allChecked ? DriverTheme.accent : Color.gray.opacity(0.5))
            .controlSize(.large)
            .buttonBorderShape(.capsule)
            .disabled(!allChecked || isSubmitting)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 24)
        .background(.ultraThinMaterial)
    }

    private func submitAndStart() async {
        guard allChecked else { return }
        isSubmitting = true
        submitError = nil

        guard let user = appViewModel.currentUser else {
            submitError = "No user found."
            isSubmitting = false
            return
        }

        guard let vehicleID = trip?.vehicleID ?? appViewModel.assignedVehicle?.id else {
            submitError = "No vehicle associated with this trip."
            isSubmitting = false
            return
        }

        let serviceItems = items.map { InspectionItem(id: UUID(), title: $0.title, isChecked: $0.status == .passed) }
        var notesParts: [String] = items.filter { $0.status == .failed }.map { "[\($0.title)] \($0.failureNote.isEmpty ? "Failed" : $0.failureNote)" }
        if !overallNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { notesParts.append("General: \(overallNotes)") }
        let combinedNotes = notesParts.isEmpty ? "All items passed." : notesParts.joined(separator: " | ")

        appViewModel.service.addInspection(driverID: user.id, vehicleID: vehicleID, type: inspectionType, notes: combinedNotes, items: serviceItems)

        for fi in failedItems {
            let desc = fi.failureNote.isEmpty ? "Inspection failed: \(fi.title)" : "\(fi.title) — \(fi.failureNote)"
            appViewModel.service.addDefect(driverID: user.id, vehicleID: vehicleID, severity: criticalItems.contains(fi.title) ? .critical : .medium, description: desc, title: "\(inspectionType.rawValue): \(fi.title)", images: nil)
        }

        isSubmitting = false

        if !failedItems.isEmpty && failedItems.contains(where: { criticalItems.contains($0.title) }) {
            submittedSuccessfully = true
            return
        }
        startTripAndDismiss()
    }

    private func startTripAndDismiss() {
        if inspectionType == .preTrip {
            if let t = trip {
                appViewModel.service.startScheduledTrip(id: t.id)
            }
        } else {
            if let t = trip {
                appViewModel.service.endTrip(t)
            }
        }
        dismiss()
        onInspectionCompleted()
    }

    private let criticalItems = ["Brakes", "Tyres / Wheels", "Steering"]
}

#Preview {
    TripStartInspectionSheet(trip: nil, inspectionType: .preTrip, onInspectionCompleted: {})
        .environment(AppViewModel())
        .environment(DriverViewModel())
}
