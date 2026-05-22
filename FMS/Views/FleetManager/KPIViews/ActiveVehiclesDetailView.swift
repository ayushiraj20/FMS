import SwiftUI

struct ActiveVehiclesDetailView: View {
    let vehicles: [Vehicle]

    private var activeVehicles: [Vehicle] {
        vehicles.filter {
            $0.status == .active || $0.status == .inService
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                summarySection

                ForEach(activeVehicles) { vehicle in
                    vehicleCard(vehicle)
                }
            }
            .padding(20)
        }
        .background(AppTheme.background)
        .navigationTitle("Active Vehicles")
        .navigationBarTitleDisplayMode(.inline)
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
        GlassCard {
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

                HStack(spacing: 16) {

                    infoPill(
                        title: "Status",
                        value: vehicle.status.rawValue,
                        color: AppTheme.success
                    )

                    infoPill(
                        title: "Health",
                        value: "Good",
                        color: .green
                    )
                    
                    infoPill(
                        title: "Fuel",
                        value: "78%",
                        color: .orange
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
    }
}

#Preview {
    NavigationStack {
        ActiveVehiclesDetailView(vehicles: [])
    }
}
