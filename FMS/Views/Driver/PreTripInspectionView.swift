import SwiftUI

struct PreTripInspectionView: View {
    @Environment(AppViewModel.self) private var appViewModel
    @Environment(DriverViewModel.self) private var driverVM
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var driverVM = driverVM
        VStack(spacing: 0) {
            progressBar

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Vehicle Inspection")
                            .font(.system(.largeTitle, design: .rounded).bold())
                        if let vehicle = appViewModel.assignedVehicle {
                            Text(vehicle.plateNumber)
                                .font(.system(.headline, design: .rounded))
                                .foregroundStyle(DriverTheme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    Picker("Type", selection: $driverVM.inspectionType) {
                        Text("Pre-Trip").tag(InspectionType.preTrip)
                        Text("Post-Trip").tag(InspectionType.postTrip)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 20)

                    LazyVStack(spacing: 16) {
                        ForEach(Array(driverVM.inspectionItems.enumerated()), id: \.element.id) { index, item in
                            inspectionItemRow(item: item, index: index)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
            }
            .background(
                ZStack {
                    DriverTheme.background.ignoresSafeArea()
                    GeometryReader { geo in
                        Circle()
                            .fill(DriverTheme.accent.opacity(0.1))
                            .frame(width: geo.size.width)
                            .blur(radius: 80)
                            .offset(x: -geo.size.width * 0.2, y: geo.size.height * 0.2)
                    }.ignoresSafeArea()
                }
            )

            // Submit button
            VStack {
                Button {
                    driverVM.submitInspection(service: appViewModel.service, user: appViewModel.currentUser)
                    if !driverVM.hasCriticalFailures {
                        dismiss()
                    }
                } label: {
                    Text("Submit Inspection")
                        .font(.system(.title3, design: .rounded).bold())
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 60)
                        .background(DriverTheme.accent, in: Capsule())
                        .shadow(color: DriverTheme.accent.opacity(0.3), radius: 10, y: 5)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .padding(.top, 10)
                .background(.ultraThinMaterial)
            }
        }
        .navigationTitle("Inspection")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .alert("Critical Issues Reported", isPresented: $driverVM.showInspectionCriticalAlert) {
            Button("OK", role: .cancel) { dismiss() }
        } message: {
            Text("Trip start will be blocked until critical items (Brakes, Tires) are resolved. Fleet Manager and Maintenance team have been notified.")
        }
        .onDisappear {
            driverVM.resetInspection()
        }
    }

    private var progressBar: some View {
        VStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.gray.opacity(0.2)).frame(height: 8)
                    Capsule()
                        .fill(DriverTheme.accent)
                        .frame(width: geometry.size.width * driverVM.inspectionProgress, height: 8)
                        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: driverVM.inspectionProgress)
                }
            }
            .frame(height: 8)

            HStack {
                Text("\(driverVM.inspectionCheckedCount) of \(driverVM.inspectionItems.count) checked")
                    .font(.caption.bold())
                    .foregroundStyle(DriverTheme.textSecondary)
                Spacer()
                Text("\(Int(driverVM.inspectionProgress * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(DriverTheme.accent)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func inspectionItemRow(item: DriverInspectionItem, index: Int) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    driverVM.toggleInspectionItem(at: index)
                }
            } label: {
                HStack(spacing: 16) {
                    Image(systemName: item.iconName)
                        .font(.title2)
                        .foregroundStyle(iconColor(for: item.status))
                        .frame(width: 32)
                        .symbolEffect(.bounce, value: item.status)

                    Text(item.title)
                        .font(.system(.headline, design: .rounded))
                        .foregroundStyle(DriverTheme.textPrimary)

                    Spacer()

                    statusIcon(for: item.status)
                }
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .strokeBorder(item.status == .failed ? DriverTheme.criticalRed.opacity(0.5) : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)

            if item.status == .failed {
                VStack(spacing: 16) {
                    Button {
                        // Camera picker
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "camera.fill")
                            Text("Add Photo")
                        }
                        .font(.subheadline.bold())
                        .foregroundStyle(DriverTheme.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(DriverTheme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(DriverTheme.accent.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [6, 4])))
                    }

                    TextField("Describe the issue...", text: Binding(
                        get: { driverVM.inspectionItems[index].failureDescription },
                        set: { driverVM.inspectionItems[index].failureDescription = $0 }
                    ))
                    .font(.system(.body, design: .rounded))
                    .padding(16)
                    .background(DriverTheme.cardFill, in: RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(DriverTheme.criticalRed.opacity(0.05))
                .clipShape(CustomCorners(corners: [.bottomLeft, .bottomRight], radius: 20))
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .scrollTransition { content, phase in
            content.scaleEffect(phase.isIdentity ? 1 : 0.95).opacity(phase.isIdentity ? 1 : 0.8)
        }
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
            Circle().stroke(Color.gray.opacity(0.4), lineWidth: 2).frame(width: 28, height: 28)
        case .passed:
            Image(systemName: "checkmark.circle.fill")
                .font(.title)
                .foregroundStyle(DriverTheme.successGreen)
                .symbolEffect(.bounce, options: .nonRepeating)
        case .failed:
            Image(systemName: "xmark.circle.fill")
                .font(.title)
                .foregroundStyle(DriverTheme.criticalRed)
                .symbolEffect(.bounce, options: .nonRepeating)
        }
    }
}

// Helper for custom corners
struct CustomCorners: Shape {
    var corners: UIRectCorner
    var radius: CGFloat
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}

#Preview {
    NavigationStack {
        PreTripInspectionView()
            .environment(AppViewModel())
            .environment(DriverViewModel())
    }
}
