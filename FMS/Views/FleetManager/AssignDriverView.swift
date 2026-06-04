import SwiftUI

struct AssignDriverView: View {
    @State private var viewModel: AssignDriverViewModel
    @Environment(\.dismiss) private var dismiss

    init(service: MockDataService) {
        _viewModel = State(wrappedValue: AssignDriverViewModel(service: service))
    }

    var body: some View {
        AppScaffold {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Subtitle
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pair available vehicles with drivers")
                                .font(.subheadline)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)

                        // Smart Match Card
                        let possibleMatches = viewModel.smartMatchCount
                        if possibleMatches > 0 {
                            smartMatchBanner(possibleMatches: possibleMatches)
                        }

                        // Select Vehicle Section
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(title: "Step 1: Select Available Vehicle", subtitle: "\(viewModel.unassignedVehicles.count) vehicles unassigned")
                                .padding(.horizontal)
                            
                            if viewModel.unassignedVehicles.isEmpty {
                                EmptyStateView(icon: "truck.box", title: "No Vehicles Available", message: "All vehicles currently have drivers assigned.")
                                    .padding(.horizontal)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(viewModel.unassignedVehicles) { vehicle in
                                            vehicleSelectionCard(vehicle: vehicle)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                }
                            }
                        }

                        // Select Driver Section
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle(title: "Step 2: Select Available Driver", subtitle: driverSectionSubtitle)
                                .padding(.horizontal)

                            if viewModel.selectedVehicle == nil {
                                EmptyStateView(icon: "truck.box", title: "Select a Vehicle First", message: "Smart Assign will show only drivers licensed for the chosen vehicle.")
                                    .padding(.horizontal)
                            } else if viewModel.compatibleDriversForSelectedVehicle.isEmpty {
                                EmptyStateView(icon: "person.crop.circle.badge.exclamationmark", title: "No Compatible Drivers", message: "No available driver has the required licence for this vehicle.")
                                    .padding(.horizontal)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 16) {
                                        ForEach(viewModel.compatibleDriversForSelectedVehicle) { driver in
                                            driverSelectionCard(driver: driver)
                                        }
                                    }
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                                }
                            }
                        }

                        // Bottom Spacer to prevent overlap with confirmation button
                        Spacer().frame(height: 120)
                    }
                }

                // Toast Notification Overlay
                if viewModel.isShowingSuccessToast, let message = viewModel.assignmentSuccessMessage {
                    successToast(message: message)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(2)
                }

                // Sticky Action Button at the Bottom
                if viewModel.selectedVehicle != nil || viewModel.selectedDriver != nil {
                    bottomActionBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .zIndex(1)
                }
            }
        }
        .navigationTitle("Assign Driver")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.selectedVehicle)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.selectedDriver)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.isShowingSuccessToast)
    }

    // Banner for Auto Smart Matching
    private func smartMatchBanner(possibleMatches: Int) -> some View {
        return GlassCard {
            HStack(spacing: 16) {
                // Gradient Icon Badge
                ZStack {
                    Circle()
                        .fill(AppTheme.brand.opacity(0.12))
                        .frame(width: 50, height: 50)
                    Image(systemName: "wand.and.stars")
                        .font(.title3)
                        .foregroundStyle(AppTheme.brand)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Smart Match Available")
                        .font(.headline)
                        .foregroundStyle(AppTheme.textPrimary)
                    Text("Assign the selected vehicle to a licensed available driver.")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Spacer()

                Button {
                    withAnimation {
                        viewModel.smartMatchAll()
                    }
                } label: {
                    Text("Smart Assign")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(AppTheme.brand)
                        )
                }
            }
        }
        .padding(.horizontal)
    }

    private var driverSectionSubtitle: String {
        guard let vehicle = viewModel.selectedVehicle else {
            return "Select a vehicle to filter licensed drivers"
        }

        return "\(viewModel.compatibleDriversForSelectedVehicle.count) drivers eligible for \(viewModel.service.requiredLicenseSummary(for: vehicle))"
    }

    // Selection card for Vehicles
    private func vehicleSelectionCard(vehicle: Vehicle) -> some View {
        let isSelected = viewModel.selectedVehicle?.id == vehicle.id
        
        return Button {
            withAnimation {
                if isSelected {
                    viewModel.selectedVehicle = nil
                } else {
                    viewModel.selectedVehicle = vehicle
                }
            }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(vehicle.plateNumber)
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
                    Spacer()
                    Image(systemName: "box.truck.fill")
                        .font(.title3)
                        .foregroundStyle(isSelected ? .white : AppTheme.brand)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(vehicle.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? .white.opacity(0.9) : AppTheme.textPrimary)
                    Text(vehicle.model)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.7) : AppTheme.textSecondary)
                }

                Divider()
                    .background(isSelected ? .white.opacity(0.3) : AppTheme.border)

                HStack {
                    Label("\(vehicle.fuelLevel)%", systemImage: "fuelpump.fill")
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.9) : AppTheme.textSecondary)
                    Spacer()
                    Text("\(vehicle.odometer / 1000)k km")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(isSelected ? .white.opacity(0.9) : AppTheme.textSecondary)
                }

                Text("Requires \(viewModel.service.requiredLicenseSummary(for: vehicle))")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : AppTheme.textSecondary)
            }
            .padding(16)
            .frame(width: 210, height: 178)
            .background(isSelected ? AppTheme.brand : AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? .white.opacity(0.3) : AppTheme.border, lineWidth: 1)
            )
            .shadow(color: isSelected ? AppTheme.brand.opacity(0.3) : Color.clear, radius: 10, y: 4)
        }
    }

    // Selection card for Drivers
    private func driverSelectionCard(driver: User) -> some View {
        let isSelected = viewModel.selectedDriver?.id == driver.id
        
        return Button {
            withAnimation {
                if isSelected {
                    viewModel.selectedDriver = nil
                } else {
                    viewModel.selectedDriver = driver
                }
            }
        } label: {
            VStack(alignment: .center, spacing: 14) {
                // Avatar
                AvatarView(name: driver.name, size: 56)

                VStack(spacing: 4) {
                    Text(driver.name)
                        .font(.headline)
                        .foregroundStyle(isSelected ? .white : AppTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                    Text(driver.title)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.7) : AppTheme.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                }
                
                Text("Available")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(isSelected ? .white : AppTheme.success)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(isSelected ? .white.opacity(0.2) : AppTheme.success.opacity(0.12))
                    .clipShape(Capsule())

                Text(viewModel.service.driverLicenseSummary(for: driver))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isSelected ? .white.opacity(0.75) : AppTheme.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(16)
            .frame(width: 170, height: 198)
            .background(isSelected ? AppTheme.brand : AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(isSelected ? .white.opacity(0.3) : AppTheme.border, lineWidth: 1)
            )
            .shadow(color: isSelected ? AppTheme.brand.opacity(0.3) : Color.clear, radius: 10, y: 4)
        }
    }

    // Sticky confirm banner at the bottom
    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(AppTheme.border)
            
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    // Vehicle indicator summary
                    HStack {
                        Image(systemName: "box.truck.fill")
                            .foregroundStyle(viewModel.selectedVehicle != nil ? AppTheme.brand : AppTheme.textSecondary)
                        Text(viewModel.selectedVehicle?.plateNumber ?? "Select Vehicle")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(viewModel.selectedVehicle != nil ? AppTheme.textPrimary : AppTheme.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.2))
                    .clipShape(Capsule())
                    
                    Image(systemName: "arrow.right.arrow.left")
                        .font(.caption)
                        .foregroundStyle(AppTheme.textSecondary)
                    
                    // Driver indicator summary
                    HStack {
                        Image(systemName: "person.fill")
                            .foregroundStyle(viewModel.selectedDriver != nil ? AppTheme.brand : AppTheme.textSecondary)
                        Text(viewModel.selectedDriver?.name.components(separatedBy: " ").first ?? "Select Driver")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(viewModel.selectedDriver != nil ? AppTheme.textPrimary : AppTheme.textSecondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.2))
                    .clipShape(Capsule())
                }
                
                Button {
                    withAnimation {
                        viewModel.assignPair()
                    }
                } label: {
                    Text("Confirm Assignment")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(AppTheme.brand)
                        )
                }
                .disabled(viewModel.selectedVehicle == nil || viewModel.selectedDriver == nil)
                .opacity(viewModel.selectedVehicle == nil || viewModel.selectedDriver == nil ? 0.5 : 1.0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(AppTheme.surface.ignoresSafeArea())
        }
    }

    // success notification toast
    private func successToast(message: String) -> some View {
        VStack {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.white)
                    .font(.headline)
                Text(message)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(AppTheme.success)
            )
            .shadow(color: AppTheme.success.opacity(0.4), radius: 10, y: 4)
            .padding(.top, 40)
            Spacer()
        }
    }
}

#Preview {
    AssignDriverView(service: MockDataService())
}
