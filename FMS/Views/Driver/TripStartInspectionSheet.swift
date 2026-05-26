import SwiftUI

struct TripStartInspectionSheet: View {
    let trip: Trip?
    var onTripStarted: () -> Void

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
            ZStack(alignment: .bottom) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        headerSection
                        progressSection

                        VStack(alignment: .leading, spacing: 16) {
                            Text("Checklist")
                                .font(.system(.title3, design: .rounded).bold())
                                .foregroundStyle(DriverTheme.textPrimary)

                            LazyVStack(spacing: 12) {
                                ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                                    itemRow(idx: idx, item: item)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            Text("Additional Notes")
                                .font(.system(.title3, design: .rounded).bold())
                            TextEditor(text: $overallNotes)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(DriverTheme.cardFill, in: RoundedRectangle(cornerRadius: 16))
                                .scrollContentBackground(.hidden)
                                .overlay(
                                    Group {
                                        if overallNotes.isEmpty {
                                            Text("e.g. Minor scratch on left door...")
                                                .font(.subheadline)
                                                .foregroundStyle(DriverTheme.textSecondary)
                                                .padding(14)
                                                .allowsHitTesting(false)
                                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                                        }
                                    }
                                )
                        }

                        if !failedItems.isEmpty {
                            failureWarningSection
                        }

                        Spacer().frame(height: 100)
                    }
                    .padding(20)
                }

                submitButton
            }
            .background(
                ZStack {
                    DriverTheme.background.ignoresSafeArea()
                    GeometryReader { geo in
                        Circle()
                            .fill(DriverTheme.accent.opacity(0.1))
                            .frame(width: geo.size.width)
                            .blur(radius: 60)
                            .offset(x: geo.size.width * 0.4, y: -geo.size.height * 0.1)
                    }.ignoresSafeArea()
                }
            )
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
                Button("Proceed Anyway") { startTripAndDismiss() }
                Button("Cancel Trip", role: .cancel) { dismiss() }
            } message: {
                Text("You marked \(failedItems.count) item(s) as FAILED. Fleet Manager and Maintenance have been notified. Do you still want to start the trip?")
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let vehicle = appViewModel.assignedVehicle {
                HStack(spacing: 16) {
                    Image(systemName: "truck.box.fill")
                        .font(.title)
                        .foregroundStyle(DriverTheme.accent)
                        .frame(width: 60, height: 60)
                        .background(.ultraThinMaterial, in: Circle())

                    VStack(alignment: .leading, spacing: 4) {
                        Text(vehicle.displayName)
                            .font(.system(.title3, design: .rounded).bold())
                        Text("Plate: \(vehicle.plateNumber)")
                            .font(.subheadline)
                            .foregroundStyle(DriverTheme.textSecondary)
                    }
                }
            }

            if let t = trip {
                HStack(spacing: 8) {
                    Image(systemName: "map.fill").foregroundStyle(DriverTheme.accent)
                    Text("\(t.origin) → \(t.destination)").font(.subheadline.bold())
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(DriverTheme.accent.opacity(0.15), in: Capsule())
            }

            Text("Complete this checklist before starting your trip. Tap each item to mark Pass or Fail.")
                .font(.subheadline)
                .foregroundStyle(DriverTheme.textSecondary)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    private var progressSection: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.2)).frame(height: 8)
                    Capsule()
                        .fill(allChecked ? DriverTheme.successGreen : DriverTheme.accent)
                        .frame(width: geo.size.width * progress, height: 8)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: progress)
                }
            }
            .frame(height: 8)
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
        .padding(.vertical, 8)
    }

    private func itemRow(idx: Int, item: InspectionItem2) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    switch items[idx].status {
                    case .unchecked: items[idx].status = .passed
                    case .passed: items[idx].status = .failed
                    case .failed:
                        items[idx].status = .unchecked
                        items[idx].failureNote = ""
                    }
                    expandedItemID = items[idx].status == .failed ? item.id : nil
                }
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: item.icon)
                        .font(.title2)
                        .foregroundStyle(iconColor(item.status))
                        .frame(width: 32)
                        .symbolEffect(.bounce, value: item.status)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title).font(.system(.headline, design: .rounded))
                        Text(item.hint).font(.caption).foregroundStyle(DriverTheme.textSecondary)
                    }
                    Spacer()
                    statusBadge(item.status)
                }
                .padding(16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(item.status == .failed ? DriverTheme.criticalRed.opacity(0.5) : Color.clear, lineWidth: 2))
            }
            .buttonStyle(.plain)

            if item.status == .failed {
                VStack(spacing: 12) {
                    Text("Describe the issue:")
                        .font(.caption.bold())
                        .foregroundStyle(DriverTheme.textSecondary)
                    TextField("e.g. Brake feels spongy...", text: $items[idx].failureNote, axis: .vertical)
                        .font(.subheadline)
                        .padding(12)
                        .background(DriverTheme.cardFill, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(DriverTheme.criticalRed.opacity(0.05))
                .clipShape(CustomCorners(corners: [.bottomLeft, .bottomRight], radius: 16))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .scrollTransition { content, phase in
            content.scaleEffect(phase.isIdentity ? 1 : 0.95).opacity(phase.isIdentity ? 1 : 0.8)
        }
    }

    private var failureWarningSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").font(.title3).foregroundStyle(DriverTheme.criticalRed)
                Text("\(failedItems.count) Issue(s) Reported").font(.headline.bold()).foregroundStyle(DriverTheme.criticalRed)
            }
            ForEach(failedItems) { fi in
                HStack(spacing: 8) {
                    Image(systemName: "xmark.circle.fill").font(.caption).foregroundStyle(DriverTheme.criticalRed)
                    Text(fi.title + (fi.failureNote.isEmpty ? "" : ": \(fi.failureNote)")).font(.subheadline).foregroundStyle(DriverTheme.textPrimary)
                }
            }
            Text("These defects will be sent to Fleet Manager & Maintenance.")
                .font(.caption)
                .foregroundStyle(DriverTheme.textSecondary)
        }
        .padding(16)
        .background(DriverTheme.criticalRed.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(DriverTheme.criticalRed.opacity(0.3), lineWidth: 1))
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
                        Image(systemName: allChecked ? "play.fill" : "checkmark.circle")
                    }
                    Text(allChecked ? "Start Trip" : "Check All Items")
                        .font(.system(.title3, design: .rounded).bold())
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 60)
                .background(allChecked ? DriverTheme.accent : Color.gray, in: Capsule())
                .shadow(color: allChecked ? DriverTheme.accent.opacity(0.3) : .clear, radius: 8, y: 4)
            }
            .disabled(!allChecked || isSubmitting)
        }
        .padding(20)
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

        appViewModel.service.addInspection(driverID: user.id, vehicleID: vehicle.id, type: .preTrip, notes: combinedNotes, items: serviceItems)

        for fi in failedItems {
            let desc = fi.failureNote.isEmpty ? "Inspection failed: \(fi.title)" : "\(fi.title) — \(fi.failureNote)"
            appViewModel.service.addDefect(driverID: user.id, vehicleID: vehicle.id, severity: criticalItems.contains(fi.title) ? .critical : .medium, description: desc, title: "Pre-trip: \(fi.title)", images: nil)
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
        if let t = trip {
            appViewModel.service.startScheduledTrip(id: t.id)
        } else if let vehicle = appViewModel.assignedVehicle {
            appViewModel.service.startTrip(driverID: user.id, vehicleID: vehicle.id, origin: "Current Location", destination: "Destination")
        }
        dismiss()
        onTripStarted()
    }

    private let criticalItems = ["Brakes", "Tyres / Wheels", "Steering"]
    private func iconColor(_ status: ItemStatus) -> Color {
        switch status { case .unchecked: return .gray; case .passed: return DriverTheme.successGreen; case .failed: return DriverTheme.criticalRed }
    }
    @ViewBuilder private func statusBadge(_ status: ItemStatus) -> some View {
        switch status {
        case .unchecked: Circle().stroke(Color.gray.opacity(0.4), lineWidth: 2).frame(width: 28, height: 28)
        case .passed: Image(systemName: "checkmark.circle.fill").font(.title).foregroundStyle(DriverTheme.successGreen).symbolEffect(.bounce, options: .nonRepeating)
        case .failed: Image(systemName: "xmark.circle.fill").font(.title).foregroundStyle(DriverTheme.criticalRed).symbolEffect(.bounce, options: .nonRepeating)
        }
    }
}

#Preview {
    TripStartInspectionSheet(trip: nil, onTripStarted: {})
        .environment(AppViewModel())
        .environment(DriverViewModel())
}
