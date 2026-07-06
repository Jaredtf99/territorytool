import Combine
import CoreLocation
import Foundation

@MainActor
final class TerritoryLocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var location: CLLocation?

    private let manager = CLLocationManager()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    var canShowLocation: Bool {
        authorizationStatus == .authorizedAlways || authorizationStatus == .authorizedWhenInUse
    }

    var isDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }

    func requestLocation() {
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            manager.requestLocation()
        default:
            break
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if canShowLocation { manager.requestLocation() }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        location = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Location is optional; the explorer keeps its current ordering.
    }
}

extension TerritoryMapGeometry {
    var representativeCoordinate: CLLocationCoordinate2D {
        if let largestPolygon = polygons.max(by: { $0.coordinates.count < $1.coordinates.count }),
           !largestPolygon.coordinates.isEmpty {
            let count = Double(largestPolygon.coordinates.count)
            return CLLocationCoordinate2D(
                latitude: largestPolygon.coordinates.reduce(0) { $0 + $1.latitude } / count,
                longitude: largestPolygon.coordinates.reduce(0) { $0 + $1.longitude } / count
            )
        }
        return CLLocationCoordinate2D(
            latitude: (bounds.north + bounds.south) / 2,
            longitude: (bounds.east + bounds.west) / 2
        )
    }
}
