import MapKit
import SwiftUI

struct FleetVehicleDetailSheet: View {
    let location: FleetVehicleLocation

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(location.vehicle.displayName)
                            .font(.title3.weight(.semibold))
                        Text(location.vehicle.plateNumber)
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.textSecondary)
                        StatusBadgeView(text: location.vehicle.status.rawValue, color: location.statusColor)
                    }
                    .padding(.vertical, 4)
                }

                Section("Route") {
                    FleetRouteMapView(location: location)
                        .frame(height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

                    detailRow("From", value: location.route.originName)
                    detailRow("To", value: location.route.destinationName)
                    detailRow("Progress", value: location.route.progressText)
                }

                Section("Location") {
                    detailRow("Area", value: location.locality)
                    detailRow("Coordinates", value: coordinateText)
                    detailRow("Updated", value: location.lastUpdatedText)
                }

                Section("Vehicle") {
                    detailRow("Model", value: location.vehicle.model)
                    detailRow("Fuel", value: location.vehicle.fuelDisplayString)
                    detailRow("Odometer", value: "\(location.vehicle.odometer.formatted()) km")
                    detailRow("Next service", value: formattedDate(location.vehicle.nextServiceDate))
                }

                Section("Assignment") {
                    detailRow("Driver", value: location.driverText)
                    detailRow("Route", value: location.routeText)
                }
            }
            .navigationTitle("Vehicle Info")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var coordinateText: String {
        String(format: "%.4f, %.4f", location.coordinate.latitude, location.coordinate.longitude)
    }

    private func detailRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(AppTheme.textSecondary)
            Spacer(minLength: 20)
            Text(value)
                .multilineTextAlignment(.trailing)
                .foregroundStyle(AppTheme.textPrimary)
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}
