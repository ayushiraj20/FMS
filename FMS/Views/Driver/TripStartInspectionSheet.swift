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
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    progressSection

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Checklist")
                                .font(.system(.headline, design: .rounded).bold())
                                .foregroundStyle(DriverTheme.textPrimary)
                            Spacer()
                            HStack(spacing: 8) {
                                Text("Pass")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(DriverTheme.successGreen)
                                    .frame(width: 36)
                                Text("Fail")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(DriverTheme.criticalRed)
                                    .frame(width: 36)
                            }
                            .padding(.trailing, 12)
                        }

                        LazyVStack(spacing: 10) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                                itemRow(idx: idx, item: item)
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Additional Notes")
                            .font(.system(.headline, design: .rounded).bold())
                        TextEditor(text: $overallNotes)
                            .font(.subheadline)
                            .frame(minHeight: 80)
                            .padding(8)
                            .background(DriverTheme.cardFill, in: RoundedRectangle(cornerRadius: 12))
                            .scrollContentBackground(.hidden)
                            .background(Color.clear)
                            .overlay(
                                Group {
                                    if overallNotes.isEmpty {
                                        Text("e.g. Minor scratch on left door...")
                                            .font(.subheadline)
                                            .foregroundStyle(DriverTheme.textSecondary)
                                            .padding(12)
                                            .allowsHitTesting(false)
                                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                    }
                                }
                            )
                    }

                    if !failedItems.isEmpty {
                        failureWarningSection
                    }
                }
                .padding(16)
            }
            .background(DriverScreenBackground())
            .safeAreaInset(edge: .bottom) {
                submitButton
            }
            .navigationTitle("\(inspectionType.rawValue) Inspection")
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
                Button("Proceed Anyway") { startTripAndDismiss() }
                Button("Cancel Trip", role: .cancel) { dismiss() }
            } message: {
                Text("You marked \(failedItems.count) item(s) as FAILED. Fleet Manager and Maintenance have been notified. Do you still want to proceed?")
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let vehicle = appViewModel.assignedVehicle {
                HStack(spacing: 12) {
                    Image(systemName: "box.truck.fill")
                        .font(.title2)
                        .foregroundStyle(DriverTheme.accent)
                        .frame(width: 48, height: 48)
                        .background(.ultraThinMaterial, in: Circle())

                    VStack(alignment: .leading, spacing: 2) {
                        Text(vehicle.displayName)
                            .font(.system(.headline, design: .rounded).bold())
                        Text("Plate: \(vehicle.plateNumber)")
                            .font(.subheadline)
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                }
            }

            if let t = trip {
                HStack(spacing: 6) {
                    Image(systemName: "map.fill").foregroundStyle(DriverTheme.accent)
                    Text("\(t.origin) → \(t.destination)").font(.caption.bold())
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(DriverTheme.accent.opacity(0.15), in: Capsule())
            }

            Text("Complete this checklist before \(inspectionType == .preTrip ? "starting" : "ending") your trip. Tap each item to mark Pass or Fail.")
                .font(.footnote)
                .foregroundStyle(DriverTheme.textSecondary)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var progressSection: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.2)).frame(height: 6)
                    Capsule()
                        .fill(allChecked ? DriverTheme.successGreen : DriverTheme.accent)
                        .frame(width: geo.size.width * progress, height: 6)
                        .animation(.spring(duration: 0.5, bounce: 0.3), value: progress)
                }
            }
            .frame(height: 6)
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
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Category Icon
                Image(systemName: item.icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(
                        item.status == .passed ? DriverTheme.successGreen :
                        item.status == .failed ? DriverTheme.criticalRed :
                        DriverTheme.textSecondary
                    )
                    .frame(width: 28)
                    .symbolEffect(.bounce, value: item.status)

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.system(.subheadline, design: .rounded).bold())
                        .foregroundStyle(DriverTheme.textPrimary)
                    Text(item.hint)
                        .font(.caption)
                        .foregroundStyle(DriverTheme.textSecondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Explicit Pass / Fail selector buttons (Compact)
                HStack(spacing: 8) {
                    // Pass Button
                    Button {
                        withAnimation(.spring(duration: 0.3, bounce: 0.3)) {
                            items[idx].status = (items[idx].status == .passed) ? .unchecked : .passed
                            expandedItemID = nil
                        }
                    } label: {
                        Image(systemName: item.status == .passed ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.title3)
                            .foregroundStyle(item.status == .passed ? DriverTheme.successGreen : DriverTheme.successGreen.opacity(0.4))
                            .frame(width: 36, height: 36)
                            .background(item.status == .passed ? DriverTheme.successGreen.opacity(0.12) : Color.clear, in: Circle())
                    }
                    .buttonStyle(.plain)
                    
                    // Fail Button
                    Button {
                        withAnimation(.spring(duration: 0.3, bounce: 0.3)) {
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
                            .background(item.status == .failed ? DriverTheme.criticalRed.opacity(0.12) : Color.clear, in: Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(DriverTheme.elevatedCard)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(
                        item.status == .failed ? DriverTheme.criticalRed.opacity(0.4) :
                        item.status == .passed ? DriverTheme.successGreen.opacity(0.4) :
                        DriverTheme.accent.opacity(0.1),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: item.status == .failed ? DriverTheme.criticalRed.opacity(0.04) :
                       item.status == .passed ? DriverTheme.successGreen.opacity(0.04) :
                       Color.clear,
                radius: 4,
                y: 2
            )

            if item.status == .failed {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Describe the issue:")
                        .font(.caption.bold())
                        .foregroundStyle(DriverTheme.textSecondary)
                    TextField("e.g. Brake feels spongy...", text: $items[idx].failureNote, axis: .vertical)
                        .font(.subheadline)
                        .padding(10)
                        .background(DriverTheme.cardFill, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .strokeBorder(DriverTheme.criticalRed.opacity(0.25), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(DriverTheme.criticalRed.opacity(0.04))
                .clipShape(CustomCorners(corners: [.bottomLeft, .bottomRight], radius: 14))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .scrollTransition { content, phase in
            content.scaleEffect(phase.isIdentity ? 1 : 0.98).opacity(phase.isIdentity ? 1 : 0.8)
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
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: allChecked ? "checkmark.circle.fill" : "checklist")
                    }
                    Text(inspectionType == .preTrip ? "Start Trip" : "End Trip")
                        .font(.system(.headline, design: .rounded).bold())
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(allChecked ? DriverTheme.accent : Color.gray.opacity(0.5), in: Capsule())
                .shadow(color: allChecked ? DriverTheme.accent.opacity(0.3) : .clear, radius: 6, y: 3)
            }
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

        guard let user = appViewModel.currentUser, let vehicle = appViewModel.assignedVehicle else {
            submitError = "No user or vehicle found."
            isSubmitting = false
            return
        }

        let serviceItems = items.map { InspectionItem(id: UUID(), title: $0.title, isChecked: $0.status == .passed) }
        var notesParts: [String] = items.filter { $0.status == .failed }.map { "[\($0.title)] \($0.failureNote.isEmpty ? "Failed" : $0.failureNote)" }
        if !overallNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { notesParts.append("General: \(overallNotes)") }
        let combinedNotes = notesParts.isEmpty ? "All items passed." : notesParts.joined(separator: " | ")

        appViewModel.service.addInspection(driverID: user.id, vehicleID: vehicle.id, type: inspectionType, notes: combinedNotes, items: serviceItems)

        for fi in failedItems {
            let desc = fi.failureNote.isEmpty ? "Inspection failed: \(fi.title)" : "\(fi.title) — \(fi.failureNote)"
            appViewModel.service.addDefect(driverID: user.id, vehicleID: vehicle.id, severity: criticalItems.contains(fi.title) ? .critical : .medium, description: desc, title: "\(inspectionType.rawValue): \(fi.title)", images: nil)
        }

        isSubmitting = false

        if !failedItems.isEmpty && failedItems.contains(where: { criticalItems.contains($0.title) }) {
            submittedSuccessfully = true
            return
        }
        startTripAndDismiss()
    }

    private func startTripAndDismiss() {
        guard let user = appViewModel.currentUser else { return }
        if inspectionType == .preTrip {
            if let t = trip {
                appViewModel.service.startScheduledTrip(id: t.id)
            } else if let vehicle = appViewModel.assignedVehicle {
                appViewModel.service.startTrip(driverID: user.id, vehicleID: vehicle.id, origin: "Current Location", destination: "Destination")
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
