import Foundation
import MapKit

@MainActor
enum TripRoutePlanningService {
  static func planRoutes(for trip: Trip) async -> TripRoutePlan? {
    guard let origin = trip.originCoordinate, let destination = trip.destinationCoordinate else {
      return nil
    }
    return await planRoutes(
      tripID: trip.id,
      origin: origin,
      destination: destination
    )
  }

  static func planRoutes(
    tripID: UUID,
    origin: CLLocationCoordinate2D,
    destination: CLLocationCoordinate2D
  ) async -> TripRoutePlan? {
    var routeSets: [[CLLocationCoordinate2D]] = []

    let primaryRoutes = await calculateMapKitRoutes(origin: origin, destination: destination)
    routeSets.append(contentsOf: primaryRoutes)

    if routeSets.count < 3 {
      let waypointRoutes = await calculateWaypointAlternates(
        origin: origin,
        destination: destination,
        existing: routeSets
      )
      for route in waypointRoutes where routeSets.count < 3 {
        if !routeSets.contains(where: { isSimilarRoute($0, to: route) }) {
          routeSets.append(route)
        }
      }
    }

    guard let mainRoute = routeSets.first, mainRoute.count >= 2 else { return nil }

    let alternatives = Array(routeSets.dropFirst().prefix(2))
    let paddedAlternatives: [[CLLocationCoordinate2D]]
    if alternatives.count == 2 {
      paddedAlternatives = alternatives
    } else if alternatives.count == 1 {
      paddedAlternatives = [alternatives[0], synthesizeOffsetRoute(origin: origin, destination: destination, variant: 1)]
    } else {
      paddedAlternatives = [
        synthesizeOffsetRoute(origin: origin, destination: destination, variant: 1),
        synthesizeOffsetRoute(origin: origin, destination: destination, variant: 2)
      ]
    }

    let mainDistanceKM = polylineLengthMeters(mainRoute) / 1_000
    let mainETAMinutes = (mainDistanceKM / 45.0) * 60.0

    return TripRoutePlan(
      tripID: tripID,
      origin: origin,
      destination: destination,
      mainRouteCoordinates: mainRoute,
      alternativeRouteCoordinates: paddedAlternatives,
      mainDistanceKM: mainDistanceKM,
      mainETAMinutes: mainETAMinutes
    )
  }

  private static func calculateSingleRoute(
    from origin: CLLocationCoordinate2D,
    to destination: CLLocationCoordinate2D
  ) async -> [CLLocationCoordinate2D] {
    let request = MKDirections.Request()
    request.source = mapItem(at: origin)
    request.destination = mapItem(at: destination)
    request.transportType = .automobile

    guard let route = try? await MKDirections(request: request).calculate().routes.first else {
      return []
    }
    return coordinates(from: route)
  }

  private static func calculateMapKitRoutes(
    origin: CLLocationCoordinate2D,
    destination: CLLocationCoordinate2D
  ) async -> [[CLLocationCoordinate2D]] {
    let request = MKDirections.Request()
    request.source = mapItem(at: origin)
    request.destination = mapItem(at: destination)
    request.transportType = .automobile
    request.requestsAlternateRoutes = true

    do {
      let response = try await MKDirections(request: request).calculate()
      return response.routes
        .map(coordinates(from:))
        .filter { $0.count >= 2 }
    } catch {
      print("[TripRoutePlanning] MapKit route error: \(error.localizedDescription)")
      return []
    }
  }

  private static func calculateWaypointAlternates(
    origin: CLLocationCoordinate2D,
    destination: CLLocationCoordinate2D,
    existing: [[CLLocationCoordinate2D]]
  ) async -> [[CLLocationCoordinate2D]] {
    let mid = CLLocationCoordinate2D(
      latitude: (origin.latitude + destination.latitude) / 2,
      longitude: (origin.longitude + destination.longitude) / 2
    )
    let variants = [
      offsetCoordinate(mid, from: origin, to: destination, kilometers: 8, direction: 1),
      offsetCoordinate(mid, from: origin, to: destination, kilometers: 8, direction: -1)
    ]

    var results: [[CLLocationCoordinate2D]] = []
    for waypoint in variants {
      let firstLeg = await calculateSingleRoute(from: origin, to: waypoint)
      let secondLeg = await calculateSingleRoute(from: waypoint, to: destination)
      guard !firstLeg.isEmpty, !secondLeg.isEmpty else { continue }

      var combined = firstLeg
      if let last = combined.last, let first = secondLeg.first, last.distance(to: first) < 25 {
        combined.append(contentsOf: secondLeg.dropFirst())
      } else {
        combined.append(contentsOf: secondLeg)
      }

      if combined.count >= 2, !existing.contains(where: { isSimilarRoute($0, to: combined) }) {
        results.append(combined)
      }
    }
    return results
  }

  private static func synthesizeOffsetRoute(
    origin: CLLocationCoordinate2D,
    destination: CLLocationCoordinate2D,
    variant: Int
  ) -> [CLLocationCoordinate2D] {
    let mid = CLLocationCoordinate2D(
      latitude: (origin.latitude + destination.latitude) / 2,
      longitude: (origin.longitude + destination.longitude) / 2
    )
    let waypoint = offsetCoordinate(
      mid,
      from: origin,
      to: destination,
      kilometers: Double(6 + variant * 3),
      direction: variant == 1 ? 1 : -1
    )
    return [origin, waypoint, destination]
  }

  private static func mapItem(at coordinate: CLLocationCoordinate2D) -> MKMapItem {
    MKMapItem(
      location: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude),
      address: nil
    )
  }

  private static func coordinates(from route: MKRoute) -> [CLLocationCoordinate2D] {
    let polyline = route.polyline
    var coords = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: polyline.pointCount)
    polyline.getCoordinates(&coords, range: NSRange(location: 0, length: polyline.pointCount))
    return coords.filter { CLLocationCoordinate2DIsValid($0) }
  }

  private static func polylineLengthMeters(_ coordinates: [CLLocationCoordinate2D]) -> CLLocationDistance {
    guard coordinates.count >= 2 else { return 0 }
    var total: CLLocationDistance = 0
    for index in 1..<coordinates.count {
      total += coordinates[index - 1].distance(to: coordinates[index])
    }
    return total
  }

  private static func isSimilarRoute(
    _ lhs: [CLLocationCoordinate2D],
    to rhs: [CLLocationCoordinate2D]
  ) -> Bool {
    guard let lhsStart = lhs.first, let rhsStart = rhs.first,
          let lhsEnd = lhs.last, let rhsEnd = rhs.last else {
      return false
    }
    let startDelta = lhsStart.distance(to: rhsStart)
    let endDelta = lhsEnd.distance(to: rhsEnd)
    return startDelta < 400 && endDelta < 400
  }

  private static func offsetCoordinate(
    _ coordinate: CLLocationCoordinate2D,
    from origin: CLLocationCoordinate2D,
    to destination: CLLocationCoordinate2D,
    kilometers: Double,
    direction: Double
  ) -> CLLocationCoordinate2D {
    let bearing = atan2(
      destination.longitude - origin.longitude,
      destination.latitude - origin.latitude
    )
    let perpendicular = bearing + (.pi / 2 * direction)
    let meters = kilometers * 1_000
    let deltaLat = (meters * cos(perpendicular)) / 111_000
    let deltaLng = (meters * sin(perpendicular)) / (111_000 * max(cos(coordinate.latitude * .pi / 180), 0.2))
    return CLLocationCoordinate2D(
      latitude: coordinate.latitude + deltaLat,
      longitude: coordinate.longitude + deltaLng
    )
  }
}
