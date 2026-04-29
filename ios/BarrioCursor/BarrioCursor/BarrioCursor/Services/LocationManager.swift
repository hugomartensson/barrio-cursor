import Foundation
import CoreLocation
import SwiftUI
import Combine
import MapKit

@MainActor
class LocationManager: NSObject, ObservableObject {
    @Published var location: CLLocation?
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var errorMessage: String?
    
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    // Computed property to check if location access is denied/restricted
    var isLocationDenied: Bool {
        authorizationStatus == .denied || authorizationStatus == .restricted
    }
    
    override init() {
        super.init()
        manager.delegate = self
        authorizationStatus = manager.authorizationStatus
        // Use best accuracy for precise location tracking on map
        // Location updates are separate from API event fetching
        manager.desiredAccuracy = kCLLocationAccuracyBest
        // Update location every 15 meters for smooth map tracking
        // This is just visual - event API calls are debounced separately
        manager.distanceFilter = 15.0
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            startUpdating()
        }
    }

    /// Call when Discover (or other flows) appears so we prompt for permission if needed and start updates when authorized.
    func requestLocationIfNeeded() {
        authorizationStatus = manager.authorizationStatus
        switch authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            startUpdating()
        default:
            break
        }
    }
    
    func requestPermission() {
        manager.requestWhenInUseAuthorization()
    }
    
    func startUpdating() {
        manager.startUpdatingLocation()
    }
    
    func stopUpdating() {
        manager.stopUpdatingLocation()
    }
    
    /// User's location, or Stockholm when we don't have one (permission denied, not yet determined, or no fix yet).
    var coordinate: CLLocationCoordinate2D {
        if let loc = location { return loc.coordinate }
        return CLLocationCoordinate2D(
            latitude: AppConfig.fallbackLatitude,
            longitude: AppConfig.fallbackLongitude
        )
    }

    /// Real-fix coordinate, or nil when permission is missing / no GPS fix yet.
    /// Use this for biasing search APIs so we don't bias Google Places results
    /// to Stockholm when the user is actually elsewhere.
    var realCoordinate: CLLocationCoordinate2D? {
        location?.coordinate
    }
    
    /// Geocode an address string to coordinates
    /// Per PRD Section 3: If location permission denied, user can manually enter address
    func geocodeAddress(_ address: String) async throws -> CLLocationCoordinate2D {
        let placemarks = try await geocoder.geocodeAddressString(address)
        
        guard let placemark = placemarks.first,
              let location = placemark.location else {
            throw LocationError.geocodingFailed("Could not find location for address")
        }
        
        return location.coordinate
    }
    
    /// Reverse geocode coordinates to address string
    /// PRD: Address is primary, coordinates derived - but we need address string for API
    func reverseGeocode(_ coordinate: CLLocationCoordinate2D) async throws -> String {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks = try await geocoder.reverseGeocodeLocation(location)
        
        guard let placemark = placemarks.first else {
            throw LocationError.geocodingFailed("Could not find address for location")
        }
        
        // Format address from placemark components
        var addressComponents: [String] = []
        if let streetNumber = placemark.subThoroughfare {
            addressComponents.append(streetNumber)
        }
        if let streetName = placemark.thoroughfare {
            addressComponents.append(streetName)
        }
        if let city = placemark.locality {
            addressComponents.append(city)
        }

        return addressComponents.joined(separator: ", ")
    }

    /// Returns a short display name for the coordinate: neighborhood (subLocality) or city (locality), for use in Discover header.
    func reverseGeocodeDisplayName(_ coordinate: CLLocationCoordinate2D) async -> String {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        guard let placemarks = try? await geocoder.reverseGeocodeLocation(location),
              let placemark = placemarks.first else {
            return "Current location"
        }
        if let neighborhood = placemark.subLocality, !neighborhood.isEmpty {
            return neighborhood
        }
        if let city = placemark.locality, !city.isEmpty {
            return city
        }
        if let area = placemark.administrativeArea, !area.isEmpty {
            return area
        }
        return "Current location"
    }
}

enum LocationError: LocalizedError {
    case geocodingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .geocodingFailed(let message):
            return message
        }
    }
}

extension LocationManager: CLLocationManagerDelegate {
    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        Task { @MainActor in
            self.location = location
        }
    }
    
    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.errorMessage = error.localizedDescription
        }
    }
    
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            self.authorizationStatus = manager.authorizationStatus
            
            switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                self.startUpdating()
            case .denied, .restricted:
                // PRD Section 3: If denied, user can manually enter address
                // Don't set error message here - let the UI handle the fallback
                break
            default:
                break
            }
        }
    }
}

