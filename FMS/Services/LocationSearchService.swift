import Foundation
import MapKit
import Observation

/// Wraps MKLocalSearchCompleter to provide real-time location suggestions,
/// geocoding, and route calculation using Apple MapKit.
@Observable
@MainActor
final class LocationSearchService: NSObject {
    // MARK: - Published State
    var suggestions: [MKLocalSearchCompletion] = []
    var isSearching: Bool = false

    // Route result
    var routePolyline: MKPolyline?
    var routeCoordinates: [CLLocationCoordinate2D] = []
    var routeDistanceKM: Double = 0
    var routeETAMinutes: Double = 0
    var isCalculatingRoute: Bool = false

    // MARK: - Private
    private let completer = MKLocalSearchCompleter()
    private var currentQuery: String = ""

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = [.address, .pointOfInterest, .query]
        // Bias results towards India
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: 22.5, longitude: 79.0),
            span: MKCoordinateSpan(latitudeDelta: 30, longitudeDelta: 30)
        )
    }

    // MARK: - Search
    func search(query: String) {
        currentQuery = query
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            suggestions = []
            isSearching = false
            return
        }
        isSearching = true
        completer.queryFragment = query
    }

    func clearSuggestions() {
        suggestions = []
        isSearching = false
        completer.queryFragment = ""
    }

    // MARK: - Geocode a suggestion to coordinates
    func geocode(_ completion: MKLocalSearchCompletion) async -> CLLocationCoordinate2D? {
        let request = MKLocalSearch.Request(completion: completion)
        request.resultTypes = [.address, .pointOfInterest]
        do {
            let response = try await MKLocalSearch(request: request).start()
            return response.mapItems.first?.location.coordinate
        } catch {
            print("[LocationSearch] Geocode error: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Calculate Route
    func calculateRoute(
        from origin: CLLocationCoordinate2D,
        to destination: CLLocationCoordinate2D
    ) async {
        isCalculatingRoute = true
        defer { isCalculatingRoute = false }

        let request = MKDirections.Request()
        request.source = MKMapItem(location: CLLocation(latitude: origin.latitude, longitude: origin.longitude), address: nil as MKAddress?)
        request.destination = MKMapItem(location: CLLocation(latitude: destination.latitude, longitude: destination.longitude), address: nil as MKAddress?)
        request.transportType = .automobile

        do {
            let directions = MKDirections(request: request)
            let response = try await directions.calculate()
            if let route = response.routes.first {
                routePolyline = route.polyline
                routeDistanceKM = route.distance / 1000.0
                routeETAMinutes = route.expectedTravelTime / 60.0

                // Extract polyline points for Map rendering
                let pointCount = route.polyline.pointCount
                let points = route.polyline.points()
                var coords: [CLLocationCoordinate2D] = []
                coords.reserveCapacity(pointCount)
                for i in 0..<pointCount {
                    coords.append(points[i].coordinate)
                }
                routeCoordinates = coords
            }
        } catch {
            print("[LocationSearch] Route calculation error: \(error.localizedDescription)")
            routePolyline = nil
            routeCoordinates = []
            routeDistanceKM = 0
            routeETAMinutes = 0
        }
    }

    func clearRoute() {
        routePolyline = nil
        routeCoordinates = []
        routeDistanceKM = 0
        routeETAMinutes = 0
    }
}

// MARK: - MKLocalSearchCompleterDelegate
extension LocationSearchService: MKLocalSearchCompleterDelegate {
    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.suggestions = completer.results
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.isSearching = false
            print("[LocationSearch] Completer error: \(error.localizedDescription)")
        }
    }
}
