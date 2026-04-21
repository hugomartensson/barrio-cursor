import Foundation
import CoreLocation

// MARK: - Result types returned by /search/suggest

struct SpotSearchResult: Identifiable, Hashable {
    let id: String
    let name: String
    let address: String
    let neighborhood: String?
    let lat: Double
    let lng: Double
    let category: String
    let imageUrl: String?
    let saveCount: Int

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

struct NeighborhoodSearchResult: Identifiable, Hashable {
    let slug: String
    let name: String
    let city: String
    let lat: Double
    let lng: Double

    var id: String { slug }

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lng)
    }
}

struct PlaceSearchResult: Identifiable, Hashable {
    let placeId: String
    let primaryText: String
    let secondaryText: String
    let types: [String]

    var id: String { placeId }
}

enum LocationSearchResult: Identifiable, Hashable {
    case spot(SpotSearchResult)
    case neighborhood(NeighborhoodSearchResult)
    case place(PlaceSearchResult)

    var id: String {
        switch self {
        case .spot(let s): return "spot_\(s.id)"
        case .neighborhood(let n): return "neighborhood_\(n.id)"
        case .place(let p): return "place_\(p.placeId)"
        }
    }
}

// MARK: - Post-resolution payload

/// What callers receive once a search result is fully resolved to coordinates.
struct ResolvedLocation {
    let coordinate: CLLocationCoordinate2D
    let formattedAddress: String
    let neighborhood: String?
    /// Present for Google Place results; nil for spot/neighborhood results.
    let placeId: String?
    /// Present when user picked an existing Barrio spot.
    let spotId: String?
}
