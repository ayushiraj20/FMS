//Created by Mayurakshi Das

import SwiftUI

struct CompleteWorkOrderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel
    @State private var workOrder: WorkOrder
    @State private var technicianNotes = ""
    @State private var allStepsCompleted = true
    @State private var completedOrder: WorkOrder?

    let vehicle: Vehicle?
    let labourHoursText: String
    let partName: String

    init(workOrder: WorkOrder, vehicle: Vehicle?, labourHoursText: String, partName: String) {
        _workOrder = State(initialValue: workOrder)
        self.vehicle = vehicle
        self.labourHoursText = labourHoursText
        self.partName = partName
    }

    private var accent: Color { Color(hex: "#FF9500") }
    private var headingText: Color { Color.dynamic(light: "#25262D", dark: "#E7E3E8") }
    private var detailText: Color { Color.dynamic(light: "#715B54", dark: "#E3C8BE") }
    private var cardBackground: Color { Color.dynamic(light: "#FFFFFF", dark: "#1B1C22") }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                summaryCard
                metricRow
                notesCard
                completionToggle
                confirmButton
                photoCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 28)
        }
        .navigationTitle("Complete Work Order")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .foregroundStyle(detailText)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button("Confirm") {
                    confirmCompletion()
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(accent)
                .disabled(!allStepsCompleted)
            }
        }
        .navigationDestination(item: $completedOrder) { order in
            WorkOrderCompletionSuccessView(
                workOrder: order,
                vehicle: vehicle,
                timeLogged: labourHoursText
            )
            .environment(appViewModel)
        }
    }

    private var summaryCard: some View {
        CompletionCard {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(workOrder.title)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(headingText)
                        .lineLimit(2)

                    Label("\(vehicle?.displayName ?? "Vehicle") • ID: \(vehicle?.plateNumber ?? "N/A")", systemImage: "truck.box")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(detailText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Divider()
                        .overlay(Color.dynamic(light: "#E6D8D2", dark: "#353741"))

                    HStack {
                        Text("Completion Status")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(detailText)

                        Text("COMPLETED AT \(Date.now.formatted(date: .omitted, time: .shortened).uppercased())")
                            .font(.caption.monospaced().weight(.bold))
                            .foregroundStyle(Color.dynamic(light: "#7A2618", dark: "#FFD1C6"))
                    }
                }

                Spacer()

                Image(systemName: "wrench.and.screwdriver.fill")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Color.dynamic(light: "#7A2618", dark: "#FFD1C6"))
                    .frame(width: 52, height: 52)
                    .background(Color.dynamic(light: "#EEF0F4", dark: "#30323A"), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
    }

    private var metricRow: some View {
        HStack(spacing: 12) {
            CompletionCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("LABOUR")
                            .font(.caption2.monospaced().weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(detailText)
                        Spacer()
                        Image(systemName: "pencil")
                            .foregroundStyle(accent)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(labourHoursText)
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(headingText)
                        Text("hrs")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(detailText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            CompletionCard {
                VStack(alignment: .leading, spacing: 14) {
                    Text("PARTS USED")
                        .font(.caption2.monospaced().weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(detailText)

                    Label("\(partName)\n(1 set)", systemImage: "shippingbox")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(headingText)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var notesCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TECHNICIAN NOTES (OPTIONAL)")
                .font(.caption2.monospaced().weight(.bold))
                .tracking(1.3)
                .foregroundStyle(detailText)

            TextField("Detail any observations or additional maintenance suggested...", text: $technicianNotes, axis: .vertical)
                .lineLimit(4...6)
                .font(.subheadline)
                .foregroundStyle(headingText)
                .padding(16)
                .frame(minHeight: 96, alignment: .topLeading)
                .background(cardBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.dynamic(light: "#E6D8D2", dark: "#353741"), lineWidth: 1)
                )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var completionToggle: some View {
        CompletionCard {
            Toggle(isOn: $allStepsCompleted) {
                Label("All required steps\ncompleted?", systemImage: "checklist.checked")
                    .font(.headline)
                    .foregroundStyle(headingText)
            }
            .tint(accent)
        }
    }

    private var confirmButton: some View {
        Button {
            confirmCompletion()
        } label: {
            Label("Confirm Completion", systemImage: "checkmark.circle.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(Color.dynamic(light: "#431300", dark: "#240900"))
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(
                    LinearGradient(
                        colors: [Color(hex: "#FF9500"), Color(hex: "#D93A00")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .shadow(color: accent.opacity(0.28), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(!allStepsCompleted)
        .opacity(allStepsCompleted ? 1 : 0.55)
    }

    private var photoCard: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.dynamic(light: "#30343C", dark: "#0B1014"),
                    Color(hex: "#FF9500").opacity(0.28)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )

            HStack {
                Image(systemName: "camera.fill")
                    .font(.title2)
                    .foregroundStyle(.white)

                Text("RETAKE PHOTO")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.black.opacity(0.3), in: Capsule())
        }
        .frame(height: 84)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.dynamic(light: "#E6D8D2", dark: "#353741"), lineWidth: 1)
        )
    }

    private func confirmCompletion() {
        guard allStepsCompleted else { return }

        var updatedOrder = workOrder
        updatedOrder.status = .completed
        updatedOrder.completedDate = .now
        let trimmedNotes = technicianNotes.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedOrder.repairSummary = trimmedNotes.isEmpty ? "Work completed by maintenance staff." : trimmedNotes

        appViewModel.service.updateWorkOrder(updatedOrder)
        
        // Persist part usage if a specific part name was specified
        if partName != "None" && !partName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            Task {
                do {
                    guard let orgID = appViewModel.currentOrganization?.id else { return }
                    let spareParts = try await SupabaseService.shared.fetchSpareParts(organizationID: orgID)
                    if let matchedPart = spareParts.first(where: { 
                        $0.name.localizedCaseInsensitiveContains(partName) || 
                        partName.localizedCaseInsensitiveContains($0.name) 
                    }) {
                        let partUsage = WorkOrderPartUsage(
                            workOrderID: workOrder.id,
                            sparePartID: matchedPart.id,
                            partName: matchedPart.name,
                            partNumber: matchedPart.partNumber,
                            quantityUsed: 1
                        )
                        appViewModel.service.saveWorkOrderParts([partUsage], workOrderID: workOrder.id, decrementStock: true)
                    }
                } catch {
                    print("[CompleteWorkOrderView] Error persisting part usage: \(error)")
                }
            }
        }

        workOrder = updatedOrder
        completedOrder = updatedOrder
    }
}

private struct CompletionCard<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.dynamic(light: "#FFFFFF", dark: "#1B1C22").opacity(0.96))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.dynamic(light: "#E6D8D2", dark: "#353741"), lineWidth: 1)
                    )
            )
    }
}

#Preview {
    NavigationStack {
        CompleteWorkOrderView(
            workOrder: MockDataService().workOrders[0],
            vehicle: MockDataService().vehicles[0],
            labourHoursText: "1.5",
            partName: "Front Brake Pads"
        )
        .environment(AppViewModel())
    }
}
