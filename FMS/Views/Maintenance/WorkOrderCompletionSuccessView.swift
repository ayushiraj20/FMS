import SwiftUI

struct WorkOrderCompletionSuccessView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel

    let workOrder: WorkOrder
    let vehicle: Vehicle?
    let timeLogged: String

    private var accent: Color { Color(hex: "#FF5A1F") }
    private var headingText: Color { Color.dynamic(light: "#25262D", dark: "#E7E3E8") }
    private var detailText: Color { Color.dynamic(light: "#715B54", dark: "#E3C8BE") }

    var body: some View {
        ScrollView {
            VStack(spacing: 26) {
                header
                successMark
                titleBlock
                completionSummary
                message
                backButton
                receiptButton
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 34)
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var header: some View {
        HStack {
            Text("FleetOS")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.dynamic(light: "#7A2618", dark: "#FFD1C6"))

            Spacer()

            Text(userInitials)
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(Circle().fill(accent))
                .overlay(Circle().stroke(Color.dynamic(light: "#E6D8D2", dark: "#353741"), lineWidth: 1))
        }
        .padding(.bottom, 10)
    }

    private var successMark: some View {
        Image(systemName: "checkmark")
            .font(.system(size: 50, weight: .bold))
            .foregroundStyle(Color.dynamic(light: "#431300", dark: "#240900"))
            .frame(width: 94, height: 94)
            .background(Circle().fill(accent))
            .padding(.top, 8)
    }

    private var titleBlock: some View {
        VStack(spacing: 12) {
            Text("Work Order Complete")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(headingText)
                .multilineTextAlignment(.center)

            Text("#WO-\(String(workOrder.id.uuidString.prefix(4)))")
                .font(.caption.monospaced().weight(.bold))
                .foregroundStyle(Color.dynamic(light: "#7A2618", dark: "#FFD1C6"))
                .padding(.horizontal, 18)
                .padding(.vertical, 8)
                .background(accent.opacity(0.14), in: Capsule())
                .overlay(Capsule().stroke(accent.opacity(0.32), lineWidth: 1))
        }
    }

    private var completionSummary: some View {
        VStack(spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("VEHICLE")
                        .font(.caption2.monospaced().weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(detailText)
                    Text(vehicle?.displayName ?? "Assigned Vehicle")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(headingText)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "truck.box")
                    .font(.title3)
                    .foregroundStyle(Color.dynamic(light: "#7A2618", dark: "#FFD1C6"))
            }

            Divider()
                .overlay(Color.dynamic(light: "#E6D8D2", dark: "#353741"))

            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("TIME LOGGED")
                        .font(.caption2.monospaced().weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(detailText)
                    Text("\(timeLogged)h")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(headingText)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 5) {
                    Text("INSPECTOR")
                        .font(.caption2.monospaced().weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(detailText)
                    Text(shortInspectorName)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(headingText)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.dynamic(light: "#FFFFFF", dark: "#1B1C22").opacity(0.96))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.dynamic(light: "#E6D8D2", dark: "#58372B"), lineWidth: 1)
                )
        )
    }

    private var message: some View {
        Text("The inspection logs and maintenance records have been synchronized with the FleetOS cloud.")
            .font(.subheadline)
            .foregroundStyle(detailText)
            .multilineTextAlignment(.center)
            .lineSpacing(4)
            .padding(.horizontal, 22)
    }

    private var backButton: some View {
        Button {
            NotificationCenter.default.post(name: .maintenanceDashboardRequested, object: nil)
            dismiss()
        } label: {
            HStack(spacing: 10) {
                Text("Back to Dashboard")
                Image(systemName: "arrow.right")
            }
            .font(.headline.weight(.bold))
            .foregroundStyle(Color.dynamic(light: "#431300", dark: "#240900"))
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .shadow(color: accent.opacity(0.3), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
    }

    private var receiptButton: some View {
        Button {
        } label: {
            Text("View Digital Receipt")
                .font(.headline.weight(.semibold))
                .foregroundStyle(headingText)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .background(Color.clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.dynamic(light: "#E6D8D2", dark: "#58372B"), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var userInitials: String {
        guard let name = appViewModel.currentUser?.name else { return "MS" }
        let initials = name
            .split(separator: " ")
            .prefix(2)
            .compactMap { $0.first }
            .map(String.init)
            .joined()
        return initials.isEmpty ? "MS" : initials.uppercased()
    }

    private var shortInspectorName: String {
        guard let name = appViewModel.currentUser?.name else { return "Staff" }
        let parts = name.split(separator: " ")
        guard let first = parts.first, let last = parts.last, first != last else {
            return name
        }
        return "\(first.prefix(1)). \(last)"
    }
}

#Preview {
    NavigationStack {
        WorkOrderCompletionSuccessView(
            workOrder: MockDataService().workOrders[0],
            vehicle: MockDataService().vehicles[0],
            timeLogged: "1.5"
        )
        .environmentObject(AppViewModel())
    }
}
