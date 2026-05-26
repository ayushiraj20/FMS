import MapKit
import SwiftUI

struct FleetRouteMapView: View {
    let location: FleetVehicleLocation

    var body: some View {
        Map(initialPosition: .region(FleetMapRegion.region(for: location.route.coordinates))) {
            if let origin = location.route.coordinates.first {
                Annotation("Start", coordinate: origin) {
                    routeMarker(systemName: "smallcircle.filled.circle", color: AppTheme.textSecondary)
                }
            }

            if let destination = location.route.coordinates.last {
                Annotation("End", coordinate: destination) {
                    routeMarker(systemName: "mappin.circle.fill", color: AppTheme.brand)
                }
            }

            if location.route.coordinates.count >= 2 {
                MapPolyline(coordinates: location.route.coordinates)
                    .stroke(AppTheme.brand, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }

            Annotation(location.vehicle.displayName, coordinate: location.coordinate) {
                FleetMapPinView(location: location)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: true))
    }

    private func routeMarker(systemName: String, color: Color) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 20, weight: .semibold))
            .foregroundStyle(color)
            .padding(6)
            .background(.background, in: Circle())
            .overlay(Circle().stroke(color, lineWidth: 1))
    }
}
