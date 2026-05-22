import SwiftUI

struct PreTripInspectionView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @EnvironmentObject private var driverVM: DriverViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            progressBar

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    // Title
                    Text("Pre-trip Inspection")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(DriverTheme.textPrimary)

                    if let vehicle = appViewModel.service.vehicle(for: appViewModel.currentUser?.assignedVehicleID) {
                        Text(vehicle.plateNumber)
                            .font(.system(size: 15))
                            .foregroundStyle(DriverTheme.textSecondary)
                    }

                    // Segmented control
                    Picker("Type", selection: $driverVM.inspectionType) {
                        Text("Pre-Trip").tag(InspectionType.preTrip)
                        Text("Post-Trip").tag(InspectionType.postTrip)
                    }
                    .pickerStyle(.segmented)

                    // Inspection items
                    ForEach(Array(driverVM.inspectionItems.enumerated()), id: \.element.id) { index, item in
                        inspectionItemRow(item: item, index: index)
                    }
                }
                .padding(20)
                .padding(.bottom, 80)
            }

            // Submit button
            VStack {
                Button("Submit Inspection") {
                    driverVM.submitInspection(service: appViewModel.service, user: appViewModel.currentUser)
                    if !driverVM.hasCriticalFailures {
                        dismiss()
                    }
                }
                .buttonStyle(DriverAccentButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .background(DriverTheme.background)
        }
        .background(DriverTheme.background.ignoresSafeArea())
        .navigationTitle("Inspection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .alert("Critical Issues Reported", isPresented: $driverVM.showInspectionCriticalAlert) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Trip start will be blocked until critical items (Brakes, Tires) are resolved. Fleet Manager and Maintenance team have been notified.")
        }
        .onDisappear {
            driverVM.resetInspection()
        }
    }

    private var progressBar: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(hex: "E5E5EA"))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(DriverTheme.accent)
                        .frame(width: geometry.size.width * driverVM.inspectionProgress, height: 6)
                        .animation(.easeInOut(duration: 0.3), value: driverVM.inspectionProgress)
                }
            }
            .frame(height: 6)

            Text("\(driverVM.inspectionCheckedCount)/\(driverVM.inspectionItems.count) items checked")
                .font(.system(size: 13))
                .foregroundStyle(DriverTheme.accent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }

    private func inspectionItemRow(item: DriverInspectionItem, index: Int) -> some View {
        VStack(spacing: 0) {
            Button {
                driverVM.toggleInspectionItem(at: index)
            } label: {
                HStack(spacing: 14) {
                    // Item icon
                    Image(systemName: item.iconName)
                        .font(.system(size: 22))
                        .foregroundStyle(iconColor(for: item.status))
                        .frame(width: 32)

                    // Item name
                    Text(item.title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DriverTheme.textPrimary)

                    Spacer()

                    // Status icon
                    statusIcon(for: item.status)
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(DriverTheme.elevatedCard)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(DriverTheme.cardBorder, lineWidth: 0.5)
                        )
                        .shadow(color: DriverTheme.cardShadow, radius: 4)
                )
            }
            .buttonStyle(.plain)

            // Expanded section for failed items
            if item.status == .failed {
                VStack(spacing: 12) {
                    Button {
                        // Camera picker would go here
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14))
                            Text("Add Photo")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundStyle(DriverTheme.textSecondary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(DriverTheme.cardFill)
                        )
                    }

                    TextField("Enter a description", text: Binding(
                        get: { driverVM.inspectionItems[index].failureDescription },
                        set: { driverVM.inspectionItems[index].failureDescription = $0 }
                    ))
                    .font(.system(size: 15))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(DriverTheme.cardFill)
                    )
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: item.status)
    }

    private func iconColor(for status: InspectionItemStatus) -> Color {
        switch status {
        case .unchecked: return .gray
        case .passed: return DriverTheme.successGreen
        case .failed: return DriverTheme.criticalRed
        }
    }

    @ViewBuilder
    private func statusIcon(for status: InspectionItemStatus) -> some View {
        switch status {
        case .unchecked:
            Circle()
                .stroke(Color.gray.opacity(0.4), lineWidth: 2)
                .frame(width: 28, height: 28)
        case .passed:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(DriverTheme.successGreen)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 28))
                .foregroundStyle(DriverTheme.criticalRed)
        }
    }
}

#Preview {
    NavigationStack {
        PreTripInspectionView()
            .environmentObject(AppViewModel())
            .environmentObject(DriverViewModel())
    }
}
