import SwiftUI

// MARK: - Trip Start Inspection Sheet
// Shown when driver taps "Start Trip" but hasn't completed today's pre-trip inspection.
// After all items are checked and submitted, it starts the trip automatically.

struct TripStartInspectionSheet: View {
    let trip: Trip?                         // nil = ad-hoc trip
    var onTripStarted: () -> Void           // called after inspection + trip start

    @Environment(AppViewModel.self) private var appViewModel
    @Environment(DriverViewModel.self) private var driverVM
    @Environment(\.dismiss) private var dismiss

    // Local inspection state (independent of driverVM so we don't clash)
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
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header info
                        headerSection

                        // Progress
                        progressSection

                        // Checklist
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Inspection Checklist")
                                .font(.headline)
                                .foregroundStyle(.primary)

                            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                                itemRow(idx: idx, item: item)
                            }
                        }

                        // Global notes
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Additional Notes / Defects")
                                .font(.headline)
                                .foregroundStyle(.primary)
                            TextEditor(text: $overallNotes)
                                .frame(minHeight: 80)
                                .padding(10)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .scrollContentBackground(.hidden)
                                .overlay(
                                    Group {
                                        if overallNotes.isEmpty {
                                            Text("e.g. 'Minor scratch on left door, fuel at 60%'")
                                                .font(.subheadline)
                                                .foregroundStyle(Color(.placeholderText))
                                                .padding(14)
                                                .allowsHitTesting(false)
                                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                        }
                                    }
                                )
                        }

                        // Failure warning
                        if !failedItems.isEmpty {
                            failureWarningSection
                        }

                        // Submit button spacer
                        Spacer().frame(height: 80)
                    }
                    .padding(20)
                }

                // Fixed bottom button
                submitButton
            }
            .background(Color(.systemBackground).ignoresSafeArea())
            .navigationTitle("Pre-Trip Inspection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("Critical Issues Found", isPresented: Binding(
                get: { !failedItems.isEmpty && submittedSuccessfully },
                set: { _ in }
            )) {
                Button("Proceed Anyway") {
                    startTripAndDismiss()
                }
                Button("Cancel Trip", role: .cancel) {
                    dismiss()
                }
            } message: {
                Text("You marked \(failedItems.count) item(s) as FAILED. Fleet Manager and Maintenance have been notified. Do you still want to start the trip?")
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let vehicle = appViewModel.assignedVehicle {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.orange.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(systemName: "truck.box.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.orange)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(vehicle.displayName)
                            .font(.system(size: 17, weight: .bold))
                        Text("Plate: \(vehicle.plateNumber)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let t = trip {
                HStack(spacing: 8) {
                    Image(systemName: "map.fill")
                        .foregroundStyle(.blue)
                        .font(.caption)
                    Text("\(t.origin)  →  \(t.destination)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(Color.blue.opacity(0.08))
                .clipShape(Capsule())
            }

            Text("Complete this checklist before starting your trip. Tap each item to mark Pass ✓ or Fail ✗. Add notes for any issues.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Progress")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(checkedCount)/\(items.count) checked")
                    .font(.subheadline)
                    .foregroundStyle(allChecked ? .green : .orange)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray5)).frame(height: 8)
                    Capsule()
                        .fill(allChecked ? Color.green : Color.orange)
                        .frame(width: geo.size.width * progress, height: 8)
                        .animation(.spring(response: 0.4), value: progress)
                }
            }
            .frame(height: 8)
        }
    }

    // MARK: - Item Row

    private func itemRow(idx: Int, item: InspectionItem2) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    // Cycle: unchecked → passed → failed → unchecked
                    switch items[idx].status {
                    case .unchecked: items[idx].status = .passed
                    case .passed:    items[idx].status = .failed
                    case .failed:
                        items[idx].status = .unchecked
                        items[idx].failureNote = ""
                    }
                    expandedItemID = items[idx].status == .failed ? item.id : nil
                }
            } label: {
                HStack(spacing: 14) {
                    // Icon
                    Image(systemName: item.icon)
                        .font(.system(size: 20))
                        .foregroundStyle(iconColor(item.status))
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(item.hint)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Status badge
                    statusBadge(item.status)
                }
                .padding(14)
                .background(rowBackground(item.status))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            // Expanded failure note
            if item.status == .failed {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Describe the issue:")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    TextField("e.g. Brake feels spongy, tyre pressure low...", text: $items[idx].failureNote, axis: .vertical)
                        .font(.subheadline)
                        .lineLimit(2...4)
                        .padding(10)
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.04))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.22), value: item.status)
    }

    // MARK: - Failure Warning

    private var failureWarningSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text("\(failedItems.count) Issue\(failedItems.count == 1 ? "" : "s") Reported")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.red)
            }
            ForEach(failedItems) { fi in
                HStack(spacing: 6) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red).font(.caption)
                    Text(fi.title + (fi.failureNote.isEmpty ? "" : ": \(fi.failureNote)"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Text("These defects will be sent to Fleet Manager & Maintenance.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .italic()
        }
        .padding(14)
        .background(Color.red.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        VStack(spacing: 0) {
            Divider()
            VStack(spacing: 10) {
                if let err = submitError {
                    Text(err)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Button {
                    Task { await submitAndStart() }
                } label: {
                    HStack(spacing: 10) {
                        if isSubmitting {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: allChecked ? "play.fill" : "checkmark.circle")
                        }
                        Text(allChecked ? "Submit Inspection & Start Trip" : "Check All Items to Continue")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        RoundedRectangle(cornerRadius: 14)
                            .fill(allChecked ? Color.orange : Color.gray.opacity(0.4))
                    )
                }
                .disabled(!allChecked || isSubmitting)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Logic

    private func submitAndStart() async {
        guard allChecked else { return }
        isSubmitting = true
        submitError = nil

        guard let user = appViewModel.currentUser,
              let vehicle = appViewModel.assignedVehicle else {
            submitError = "No user or vehicle found. Please try again."
            isSubmitting = false
            return
        }

        // Build InspectionItem array for MockDataService
        let serviceItems = items.map {
            InspectionItem(id: UUID(), title: $0.title, isChecked: $0.status == .passed)
        }

        // Combine per-item failure notes + overall notes
        var notesParts: [String] = items
            .filter { $0.status == .failed }
            .map { "[\($0.title)] \($0.failureNote.isEmpty ? "Failed" : $0.failureNote)" }
        if !overallNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notesParts.append("General: \(overallNotes)")
        }
        let combinedNotes = notesParts.isEmpty ? "All items passed." : notesParts.joined(separator: " | ")

        // Save inspection to service + Supabase
        appViewModel.service.addInspection(
            driverID: user.id,
            vehicleID: vehicle.id,
            type: .preTrip,
            notes: combinedNotes,
            items: serviceItems
        )

        // Report defects to fleet manager for any failed items
        for fi in failedItems {
            let desc = fi.failureNote.isEmpty ? "Inspection failed: \(fi.title)" : "\(fi.title) — \(fi.failureNote)"
            appViewModel.service.addDefect(
                driverID: user.id,
                vehicleID: vehicle.id,
                severity: criticalItems.contains(fi.title) ? .critical : .medium,
                description: desc,
                title: "Pre-trip: \(fi.title)",
                images: nil
            )
        }

        isSubmitting = false

        // If critical failures, show alert before starting trip
        if !failedItems.isEmpty && failedItems.contains(where: { criticalItems.contains($0.title) }) {
            submittedSuccessfully = true
            return
        }

        // No critical failures — start trip right away
        startTripAndDismiss()
    }

    private func startTripAndDismiss() {
        guard let user = appViewModel.currentUser else { return }

        if let t = trip {
            appViewModel.service.startScheduledTrip(id: t.id)
        } else if let vehicle = appViewModel.assignedVehicle {
            appViewModel.service.startTrip(
                driverID: user.id,
                vehicleID: vehicle.id,
                origin: "Current Location",
                destination: "Destination"
            )
        }

        dismiss()
        onTripStarted()
    }

    // MARK: - Helpers

    private let criticalItems = ["Brakes", "Tyres / Wheels", "Steering"]

    private func iconColor(_ status: ItemStatus) -> Color {
        switch status {
        case .unchecked: return .gray
        case .passed:    return .green
        case .failed:    return .red
        }
    }

    @ViewBuilder
    private func statusBadge(_ status: ItemStatus) -> some View {
        switch status {
        case .unchecked:
            Circle()
                .stroke(Color.gray.opacity(0.4), lineWidth: 2)
                .frame(width: 28, height: 28)
        case .passed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(.red)
        }
    }

    private func rowBackground(_ status: ItemStatus) -> Color {
        switch status {
        case .unchecked: return Color(.systemGray6)
        case .passed:    return Color.green.opacity(0.08)
        case .failed:    return Color.red.opacity(0.08)
        }
    }
}

// MARK: - Local Models

enum ItemStatus { case unchecked, passed, failed }

struct InspectionItem2: Identifiable {
    let id = UUID()
    let title: String
    let hint: String
    let icon: String
    var status: ItemStatus = .unchecked
    var failureNote: String = ""

    static func defaultList() -> [InspectionItem2] {
        [
            InspectionItem2(title: "Brakes", hint: "Test brake pedal feel and response", icon: "stop.circle.fill"),
            InspectionItem2(title: "Tyres / Wheels", hint: "Check pressure, tread depth & lug nuts", icon: "circle.circle.fill"),
            InspectionItem2(title: "Lights & Indicators", hint: "Headlights, tail lights, hazards", icon: "lightbulb.fill"),
            InspectionItem2(title: "Steering", hint: "No excessive play, wheels aligned", icon: "steeringwheel"),
            InspectionItem2(title: "Mirrors & Wipers", hint: "Clean, adjusted and fully functional", icon: "eye.fill"),
            InspectionItem2(title: "Fuel Level", hint: "Ensure sufficient fuel for the trip", icon: "fuelpump.fill"),
            InspectionItem2(title: "Engine Oil & Fluids", hint: "Oil, coolant, brake fluid levels", icon: "drop.fill"),
            InspectionItem2(title: "Horn", hint: "Audible and functioning", icon: "speaker.wave.3.fill"),
            InspectionItem2(title: "Seatbelt", hint: "Latches correctly, no fraying", icon: "seatbelt"),
            InspectionItem2(title: "Fire Extinguisher", hint: "Present and within service date", icon: "flame.fill"),
            InspectionItem2(title: "Documents", hint: "Insurance, RC, permits on board", icon: "doc.fill"),
            InspectionItem2(title: "Body / Cargo", hint: "No damage, cargo secured properly", icon: "shippingbox.fill"),
        ]
    }
}
