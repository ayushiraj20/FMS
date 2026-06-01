import Foundation
import MapKit

/// Planned driving routes for a trip: one recommended main route and two alternatives.
struct TripRoutePlan: Identifiable, Codable {
    let tripID: UUID
    let origin: CLLocationCoordinate2D
    let destination: CLLocationCoordinate2D
    let mainRouteCoordinates: [CLLocationCoordinate2D]
    let alternativeRouteCoordinates: [[CLLocationCoordinate2D]]
    let mainDistanceKM: Double
    let mainETAMinutes: Double
    let generatedAt: Date

    var id: UUID { tripID }

    static let corridorToleranceMeters: CLLocationDistance = 50

    var allRoutes: [[CLLocationCoordinate2D]] {
        [mainRouteCoordinates] + alternativeRouteCoordinates
    }

    func mainPolyline() -> MKPolyline {
        MKPolyline(coordinates: mainRouteCoordinates)
    }

    func alternativePolylines() -> [MKPolyline] {
        alternativeRouteCoordinates.map { MKPolyline(coordinates: $0) }
    }

    // MARK: - Codable (coordinates as lat/lng pairs)

    enum CodingKeys: String, CodingKey {
        case tripID
        case originLat
        case originLng
        case destinationLat
        case destinationLng
        case mainRouteCoordinates
        case alternativeRouteCoordinates
        case mainDistanceKM
        case mainETAMinutes
        case generatedAt
    }

    init(
        tripID: UUID,
        origin: CLLocationCoordinate2D,
        destination: CLLocationCoordinate2D,
        mainRouteCoordinates: [CLLocationCoordinate2D],
        alternativeRouteCoordinates: [[CLLocationCoordinate2D]],
        mainDistanceKM: Double,
        mainETAMinutes: Double,
        generatedAt: Date = .now
    ) {
        self.tripID = tripID
        self.origin = origin
        self.destination = destination
        self.mainRouteCoordinates = mainRouteCoordinates
        self.alternativeRouteCoordinates = alternativeRouteCoordinates
        self.mainDistanceKM = mainDistanceKM
        self.mainETAMinutes = mainETAMinutes
        self.generatedAt = generatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        tripID = try container.decode(UUID.self, forKey: .tripID)
        let originLat = try container.decode(Double.self, forKey: .originLat)
        let originLng = try container.decode(Double.self, forKey: .originLng)
        let destinationLat = try container.decode(Double.self, forKey: .destinationLat)
        let destinationLng = try container.decode(Double.self, forKey: .destinationLng)
        origin = CLLocationCoordinate2D(latitude: originLat, longitude: originLng)
        destination = CLLocationCoordinate2D(latitude: destinationLat, longitude: destinationLng)
        mainRouteCoordinates = try container.decode([[Double]].self, forKey: .mainRouteCoordinates).map(Self.coordinate(from:))
        alternativeRouteCoordinates = try container.decode([[[Double]]].self, forKey: .alternativeRouteCoordinates)
            .map { $0.map(Self.coordinate(from:)) }
        mainDistanceKM = try container.decode(Double.self, forKey: .mainDistanceKM)
        mainETAMinutes = try container.decode(Double.self, forKey: .mainETAMinutes)
        generatedAt = try container.decode(Date.self, forKey: .generatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tripID, forKey: .tripID)
        try container.encode(origin.latitude, forKey: .originLat)
        try container.encode(origin.longitude, forKey: .originLng)
        try container.encode(destination.latitude, forKey: .destinationLat)
        try container.encode(destination.longitude, forKey: .destinationLng)
        try container.encode(mainRouteCoordinates.map(Self.pair(from:)), forKey: .mainRouteCoordinates)
        try container.encode(alternativeRouteCoordinates.map { $0.map(Self.pair(from:)) }, forKey: .alternativeRouteCoordinates)
        try container.encode(mainDistanceKM, forKey: .mainDistanceKM)
        try container.encode(mainETAMinutes, forKey: .mainETAMinutes)
        try container.encode(generatedAt, forKey: .generatedAt)
    }

    private static func pair(from coordinate: CLLocationCoordinate2D) -> [Double] {
        [coordinate.latitude, coordinate.longitude]
    }

    private static func coordinate(from pair: [Double]) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
    }
}

enum TripRouteCorridorStatus: Equatable {
    case onMainRoute
    case onAlternativeRoute(index: Int)
    case outsideCorridor(distanceMeters: CLLocationDistance)
    case unavailable
}

enum TripRouteGeofenceEvaluator {
    static func corridorStatus(
        for coordinate: CLLocationCoordinate2D,
        plan: TripRoutePlan,
        toleranceMeters: CLLocationDistance = TripRoutePlan.corridorToleranceMeters
    ) -> TripRouteCorridorStatus {
        let mainDistance = RouteGeometry.distance(from: coordinate, toPolyline: plan.mainRouteCoordinates)
        if mainDistance <= toleranceMeters {
            return .onMainRoute
        }

        for (index, alternative) in plan.alternativeRouteCoordinates.enumerated() {
            let alternativeDistance = RouteGeometry.distance(from: coordinate, toPolyline: alternative)
            if alternativeDistance <= toleranceMeters {
                return .onAlternativeRoute(index: index)
            }
        }

        let nearest = min(
            mainDistance,
            plan.alternativeRouteCoordinates
                .map { RouteGeometry.distance(from: coordinate, toPolyline: $0) }
                .min() ?? mainDistance
        )
        return .outsideCorridor(distanceMeters: nearest)
    }
}

enum RouteGeometry {
    static func distance(
        from coordinate: CLLocationCoordinate2D,
        toPolyline polyline: [CLLocationCoordinate2D]
    ) -> CLLocationDistance {
        guard !polyline.isEmpty else { return .greatestFiniteMagnitude }
        if polyline.count == 1 {
            return coordinate.distance(to: polyline[0])
        }

        var minimum = CLLocationDistance.greatestFiniteMagnitude
        for index in 0..<(polyline.count - 1) {
            let segmentDistance = distance(
                from: coordinate,
                toSegmentStart: polyline[index],
                segmentEnd: polyline[index + 1]
            )
            minimum = min(minimum, segmentDistance)
        }
        return minimum
    }

    static func distance(
        from coordinate: CLLocationCoordinate2D,
        toSegmentStart start: CLLocationCoordinate2D,
        segmentEnd end: CLLocationCoordinate2D
    ) -> CLLocationDistance {
        let startLocation = CLLocation(latitude: start.latitude, longitude: start.longitude)
        let endLocation = CLLocation(latitude: end.latitude, longitude: end.longitude)
        let point = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)

        let segmentLength = startLocation.distance(from: endLocation)
        guard segmentLength > 0.5 else {
            return point.distance(from: startLocation)
        }

        let startX = start.longitude
        let startY = start.latitude
        let endX = end.longitude
        let endY = end.latitude
        let pointX = coordinate.longitude
        let pointY = coordinate.latitude

        let projection = ((pointX - startX) * (endX - startX) + (pointY - startY) * (endY - startY))
            / (pow(endX - startX, 2) + pow(endY - startY, 2))
        let clamped = min(max(projection, 0), 1)
        let projected = CLLocationCoordinate2D(
            latitude: startY + (endY - startY) * clamped,
            longitude: startX + (endX - startX) * clamped
        )
        return point.distance(from: CLLocation(latitude: projected.latitude, longitude: projected.longitude))
    }
}

extension Trip {
    var originCoordinate: CLLocationCoordinate2D? {
        guard let originLat, let originLng else { return nil }
        return CLLocationCoordinate2D(latitude: originLat, longitude: originLng)
    }

    var destinationCoordinate: CLLocationCoordinate2D? {
        guard let destinationLat, let destinationLng else { return nil }
        return CLLocationCoordinate2D(latitude: destinationLat, longitude: destinationLng)
    }

    var hasRoutableEndpoints: Bool {
        originCoordinate != nil && destinationCoordinate != nil
    }
}

extension MKPolyline {
    convenience init(coordinates: [CLLocationCoordinate2D]) {
        if coordinates.isEmpty {
            self.init()
            return
        }
        var mutable = coordinates
        self.init(coordinates: &mutable, count: mutable.count)
    }
}
