import Foundation
import CoreLocation
import Combine

class LocationService: NSObject, ObservableObject {
    static let shared = LocationService()

    @Published var currentLocation: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isUpdating = false

    private let locationManager = CLLocationManager()

    private override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        authorizationStatus = locationManager.authorizationStatus
    }

    func requestAuthorization() {
        locationManager.requestWhenInUseAuthorization()
    }

    func startUpdating() {
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else {
            requestAuthorization()
            return
        }
        isUpdating = true
        locationManager.startUpdatingLocation()
    }

    func stopUpdating() {
        isUpdating = false
        locationManager.stopUpdatingLocation()
    }

    func updateOnce() {
        guard authorizationStatus == .authorizedWhenInUse ||
              authorizationStatus == .authorizedAlways else {
            requestAuthorization()
            return
        }
        locationManager.requestLocation()
    }

    // MARK: - Distance Calculations

    func distance(to coordinate: CLLocationCoordinate2D) -> CLLocationDistance? {
        guard let currentLocation = currentLocation else { return nil }
        let targetLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return currentLocation.distance(from: targetLocation)
    }

    func distanceInFeet(to coordinate: CLLocationCoordinate2D) -> Double? {
        guard let meters = distance(to: coordinate) else { return nil }
        return meters * 3.28084
    }

    func formattedDistance(to coordinate: CLLocationCoordinate2D) -> String? {
        guard let feet = distanceInFeet(to: coordinate) else { return nil }
        if feet < 1000 {
            return "\(Int(feet)) ft"
        } else {
            let miles = feet / 5280
            if miles < 0.1 {
                return "\(Int(feet)) ft"
            } else {
                return String(format: "%.1f mi", miles)
            }
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        currentLocation = locations.last
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location error: \(error.localizedDescription)")
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            updateOnce()
        }
    }
}
