import MapKit
import SwiftUI

/// Shared map overlay for fleet manager and driver — one optimal route polyline per trip.
struct TripRoutesMapContent: MapContent {
    let plan: TripRoutePlan
    var showLabels: Bool = true
    var showAlternatives: Bool = false

    var body: some MapContent {
        MapPolyline(coordinates: plan.mainRouteCoordinates)
            .stroke(.blue, style: StrokeStyle(lineWidth: 6, lineCap: .round, lineJoin: .round))

        if showAlternatives {
            ForEach(Array(plan.alternativeRouteCoordinates.enumerated()), id: \.offset) { index, route in
                MapPolyline(coordinates: route)
                    .stroke(
                        Color.orange,
                        style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round, dash: [8, 6])
                    )
            }
        }

        if showLabels {
            Annotation("Start", coordinate: plan.origin) {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
            }

            Annotation("Destination", coordinate: plan.destination) {
                Circle()
                    .fill(Color.red)
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(.white, lineWidth: 2))
            }
        }
    }
}

enum TripRouteMapCamera {
    static func position(for plan: TripRoutePlan, current: CLLocationCoordinate2D? = nil) -> MapCameraPosition {
        var coordinates = plan.allRoutes.flatMap { $0 }
        if let current {
            coordinates.append(current)
        }
        return .region(FleetMapRegion.region(for: coordinates))
    }
}

struct TripRouteLegendView: View {
    var showAlternatives: Bool = false

    var body: some View {
        HStack(spacing: 12) {
            legendItem(color: .blue, label: "Optimal", dashed: false)
            if showAlternatives {
                legendItem(color: .orange, label: "Alt", dashed: true)
            }
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial, in: Capsule())
    }

    private func legendItem(color: Color, label: String, dashed: Bool) -> some View {
        HStack(spacing: 4) {
            Capsule()
                .fill(color)
                .frame(width: 18, height: 3)
                .overlay {
                    if dashed {
                        Capsule()
                            .stroke(color, style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
                            .frame(width: 18, height: 3)
                    }
                }
            Text(label)
        }
    }
}
