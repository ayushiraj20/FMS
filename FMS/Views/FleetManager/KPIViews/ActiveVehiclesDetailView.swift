import SwiftUI

struct ActiveVehiclesDetailView: View {
    @Environment(AppViewModel.self) private var appViewModel
    let vehicles: [Vehicle]
    @State private var selectedVehicle: Vehicle?

    private var activeVehicles: [Vehicle] {
        appViewModel.service.vehicles.filter {
            $0.status == .active || $0.status == .inService
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                summarySection

                if activeVehicles.isEmpty {
                    EmptyStateView(
                        icon: "truck.box.fill",
                        title: "No Active Vehicles",
                        message: "There are no vehicles currently active on duty."
                    )
                } else {
                    ForEach(activeVehicles) { vehicle in
                        Button {
                            selectedVehicle = vehicle
                        } label: {
                            vehicleCard(vehicle)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .navigationTitle("Active Vehicles")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedVehicle) { vehicle in
            let driverName = getDriverName(for: vehicle)
            VehicleDetailSheet(vehicle: vehicle, driverName: driverName)
        }
    }

    // MARK: - Summary

    private var summarySection: some View {
        GlassCard {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Currently Active")
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.textSecondary)

                    Text("\(activeVehicles.count)")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(AppTheme.textPrimary)
                }

                Spacer()

                Image(systemName: "truck.box.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(AppTheme.brand)
            }
        }
    }

    // MARK: - Vehicle Card

    private func vehicleCard(_ vehicle: Vehicle) -> some View {
        let activeDefects = appViewModel.service.defects.filter { $0.vehicleID == vehicle.id && !$0.isResolved }
        let healthText = activeDefects.isEmpty ? "Good" : (activeDefects.contains { $0.severity == .critical } ? "Critical" : "Needs Service")
        let healthColor = activeDefects.isEmpty ? AppTheme.success : (activeDefects.contains { $0.severity == .critical } ? AppTheme.error : AppTheme.warning)

        return GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(vehicle.displayName)
                            .font(.headline)
                            .foregroundStyle(AppTheme.textPrimary)

                        Text(vehicle.plateNumber)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppTheme.textSecondary)
                }

                Divider()
                    .background(AppTheme.border)

                HStack(spacing: 16) {
                    infoPill(
                        title: "Status",
                        value: vehicle.status.rawValue,
                        color: vehicle.status == .active ? AppTheme.success : Color(hex: "#00a2ff")
                    )

                    infoPill(
                        title: "Health",
                        value: healthText,
                        color: healthColor
                    )
                    
                    infoPill(
                        title: "Fuel",
                        value: "\(vehicle.fuelLevel)%",
                        color: vehicle.fuelLevel < 30 ? AppTheme.error : (vehicle.fuelLevel < 60 ? AppTheme.warning : AppTheme.success)
                    )
                }
            }
        }
    }

    private func infoPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(AppTheme.textSecondary)

            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    private func getDriverName(for vehicle: Vehicle) -> String {
        guard let driverID = vehicle.assignedDriverID else {
            return "Unassigned"
        }
        return appViewModel.service.users.first { $0.id == driverID }?.name ?? "Unknown Driver"
    }
}

// MARK: - Vehicle Detail Sheet

struct VehicleDetailSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var appViewModel
    let vehicle: Vehicle
    let driverName: String

    private var activeDefects: [DefectReport] {
        appViewModel.service.defects.filter { $0.vehicleID == vehicle.id && !$0.isResolved }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Section
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.brand.opacity(0.12))
                                .frame(width: 80, height: 80)
                            Image(systemName: "box.truck.fill")
                                .font(.system(size: 36))
                                .foregroundStyle(AppTheme.brand)
                        }
                        .padding(.top, 16)

                        VStack(spacing: 4) {
                            Text(vehicle.displayName)
                                .font(.title3.bold())
                                .foregroundStyle(AppTheme.textPrimary)
                            
                            Text(vehicle.plateNumber)
                                .font(.headline.monospaced())
                                .foregroundStyle(AppTheme.textSecondary)
                            
                            Text(vehicle.model)
                                .font(.caption)
                                .foregroundStyle(AppTheme.textSecondary)
                        }
                    }

                    // Status and Health Summary Row
                    HStack(spacing: 16) {
                        // Status Card
                        VStack(alignment: .leading, spacing: 6) {
                            Text("STATUS")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.textSecondary)
                            
                            Text(vehicle.status.rawValue.uppercased())
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(vehicle.status == .active ? AppTheme.success : Color(hex: "#00a2ff"))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(AppTheme.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        
                        // Health Card
                        let healthText = activeDefects.isEmpty ? "GOOD" : (activeDefects.contains { $0.severity == .critical } ? "CRITICAL" : "NEEDS SERVICE")
                        let healthColor = activeDefects.isEmpty ? AppTheme.success : (activeDefects.contains { $0.severity == .critical } ? AppTheme.error : AppTheme.warning)
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("HEALTH")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(AppTheme.textSecondary)
                            
                            Text(healthText)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(healthColor)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(AppTheme.surfaceSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.horizontal)

                    // Operational Metrics
                    GlassCard {
                        VStack(spacing: 16) {
                            // Fuel progress bar
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Label("Fuel Level", systemImage: "fuelpump.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.textSecondary)
                                    Spacer()
                                    Text("\(vehicle.fuelLevel)%")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                                
                                let fuelColor = vehicle.fuelLevel < 30 ? AppTheme.error : (vehicle.fuelLevel < 60 ? AppTheme.warning : AppTheme.success)
                                
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(AppTheme.border).frame(height: 8)
                                        Capsule()
                                            .fill(fuelColor)
                                            .frame(width: geo.size.width * CGFloat(Double(vehicle.fuelLevel) / 100.0), height: 8)
                                    }
                                }
                                .frame(height: 8)
                            }

                            Divider().background(AppTheme.border)

                            // Utilization meter
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Label("Monthly Utilization", systemImage: "chart.bar.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.textSecondary)
                                    Spacer()
                                    Text("\(vehicle.utilization)%")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(AppTheme.textPrimary)
                                }
                                
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(AppTheme.border).frame(height: 8)
                                        Capsule()
                                            .fill(AppTheme.brand)
                                            .frame(width: geo.size.width * CGFloat(Double(vehicle.utilization) / 100.0), height: 8)
                                    }
                                }
                                .frame(height: 8)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Details list
                    GlassCard {
                        VStack(spacing: 14) {
                            detailRow(icon: "gauge", label: "Odometer", value: "\(vehicle.odometer.formatted()) km")
                            Divider().background(AppTheme.border)
                            detailRow(icon: "person.fill", label: "Assigned Driver", value: driverName)
                            Divider().background(AppTheme.border)
                            detailRow(icon: "calendar", label: "Next Service Date", value: vehicle.nextServiceDate.formatted(date: .long, time: .omitted))
                        }
                    }
                    .padding(.horizontal)

                    // Active Defects Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("ACTIVE DEFECT REPORTS (\(activeDefects.count))")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(AppTheme.textSecondary)
                            .padding(.horizontal)

                        if activeDefects.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppTheme.success)
                                Text("No outstanding defects reported on this vehicle.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.textPrimary)
                                Spacer()
                            }
                            .padding()
                            .background(AppTheme.surfaceSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .padding(.horizontal)
                        } else {
                            ForEach(activeDefects) { defect in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(defect.title ?? "Defect Report")
                                            .font(.subheadline.bold())
                                            .foregroundStyle(AppTheme.textPrimary)
                                        Spacer()
                                        Text(defect.severity.rawValue.uppercased())
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundStyle(.white)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(defect.severity == .critical ? AppTheme.error : AppTheme.warning)
                                            .clipShape(Capsule())
                                    }
                                    
                                    Text(defect.description)
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.textSecondary)
                                        .lineLimit(2)
                                    
                                    Text("Reported: \(defect.reportedDate.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.system(size: 9))
                                        .foregroundStyle(AppTheme.textSecondary.opacity(0.8))
                                }
                                .padding()
                                .background(AppTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                                .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppTheme.border, lineWidth: 1))
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(AppTheme.background.ignoresSafeArea())
            .navigationTitle("Vehicle Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func detailRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(AppTheme.brand)
                .frame(width: 24)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.textPrimary)
        }
    }
}

#Preview {
    NavigationStack {
        ActiveVehiclesDetailView(vehicles: [])
            .environment(AppViewModel())
    }
}
