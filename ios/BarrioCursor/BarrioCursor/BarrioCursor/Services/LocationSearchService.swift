import Foundation
import Observation
import CoreLocation

// MARK: - Server response decodables

private struct SearchSuggestResponse: Decodable {
    let data: SearchSuggestData
}

private struct SearchSuggestData: Decodable {
    let spots: [SpotSuggestion]
    let neighborhoods: [NeighborhoodSuggestion]
    let places: [PlaceSuggestion]
}

private struct SpotSuggestion: Decodable {
    let id: String
    let name: String
    let address: String
    let neighborhood: String?
    let lat: Double
    let lng: Double
    let category: String
    let imageUrl: String?
    let saveCount: Int
}

private struct NeighborhoodSuggestion: Decodable {
    let slug: String
    let name: String
    let city: String
    let lat: Double
    let lng: Double
}

private struct PlaceSuggestion: Decodable {
    let placeId: String
    let primaryText: String
    let secondaryText: String
    let types: [String]
}

private struct PlaceDetailsResponse: Decodable {
    let data: PlaceDetailsData
}

private struct PlaceDetailsData: Decodable {
    let placeId: String
    let lat: Double
    let lng: Double
    let formattedAddress: String
    let name: String
    let neighborhood: String?
    let city: String?
}

// MARK: - Service

@MainActor
@Observable
final class LocationSearchService {

    struct SearchSections {
        var spots: [SpotSearchResult] = []
        var neighborhoods: [NeighborhoodSearchResult] = []
        var places: [PlaceSearchResult] = []

        var isEmpty: Bool { spots.isEmpty && neighborhoods.isEmpty && places.isEmpty }

        static let empty = SearchSections()
    }

    var sections: SearchSections = .empty
    var isSearching: Bool = false
    var error: String? = nil

    // Each new search session gets a UUID; reset after a completed Place Details call
    // so Google session-based billing stays accurate.
    private(set) var sessionToken = UUID().uuidString
    private var searchTask: Task<Void, Never>?

    // MARK: - Public API

    /// Fire a debounced suggest call. Call on every keystroke.
    func search(query: String, near center: CLLocationCoordinate2D, token: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else {
            sections = .empty
            isSearching = false
            return
        }

        isSearching = true
        searchTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 300_000_000) // 300 ms debounce
            guard !Task.isCancelled else { return }

            do {
                let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
                let endpoint = "/search/suggest?q=\(encoded)&lat=\(center.latitude)&lng=\(center.longitude)&sessionToken=\(self.sessionToken)"
                let response: SearchSuggestResponse = try await APIService.shared.get(endpoint, token: token)
                guard !Task.isCancelled else { return }
                self.sections = SearchSections(
                    spots: response.data.spots.map {
                        SpotSearchResult(id: $0.id, name: $0.name, address: $0.address,
                                         neighborhood: $0.neighborhood, lat: $0.lat, lng: $0.lng,
                                         category: $0.category, imageUrl: $0.imageUrl, saveCount: $0.saveCount)
                    },
                    neighborhoods: response.data.neighborhoods.map {
                        NeighborhoodSearchResult(slug: $0.slug, name: $0.name, city: $0.city, lat: $0.lat, lng: $0.lng)
                    },
                    places: response.data.places.map {
                        PlaceSearchResult(placeId: $0.placeId, primaryText: $0.primaryText,
                                          secondaryText: $0.secondaryText, types: $0.types)
                    }
                )
                self.isSearching = false
                self.error = nil
            } catch {
                guard !Task.isCancelled else { return }
                self.isSearching = false
                self.error = nil // Fail silently; don't disrupt UX
            }
        }
    }

    /// Resolve a Google Place ID to a `ResolvedLocation`. Resets the session token after success.
    func resolvePlace(placeId: String, token: String) async throws -> ResolvedLocation {
        let endpoint = "/search/place/\(placeId)?sessionToken=\(sessionToken)"
        let response: PlaceDetailsResponse = try await APIService.shared.get(endpoint, token: token)
        // Reset token: Place Details closes the billing session.
        sessionToken = UUID().uuidString
        let d = response.data
        return ResolvedLocation(
            coordinate: CLLocationCoordinate2D(latitude: d.lat, longitude: d.lng),
            formattedAddress: d.formattedAddress,
            neighborhood: d.neighborhood,
            placeId: d.placeId,
            spotId: nil
        )
    }

    /// Clear results and cancel any in-flight search.
    func clear() {
        searchTask?.cancel()
        sections = .empty
        isSearching = false
    }
}
