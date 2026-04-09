import Foundation
import CoreLocation

// MARK: - PRD-aligned Spot domain model
// Thin wrapper over API SpotData so the rest of the app can speak
// in PRD terms (Spot with owners/tags/saveCount) instead of backend DTOs.

nonisolated struct SpotOwner: Codable, Hashable {
    let id: String
    let handle: String?
    let initials: String
}

nonisolated struct Spot: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let neighborhood: String
    let description: String?
    let imageUrl: String?
    let location: CLLocationCoordinate2D
    let tags: [String]
    let owners: [SpotOwner]
    /// PRD: saveCount; updated when user toggles save.
    var saveCount: Int
    
    init(
        id: String,
        name: String,
        neighborhood: String,
        description: String?,
        imageUrl: String?,
        location: CLLocationCoordinate2D,
        tags: [String],
        owners: [SpotOwner],
        saveCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.neighborhood = neighborhood
        self.description = description
        self.imageUrl = imageUrl
        self.location = location
        self.tags = tags
        self.owners = owners
        self.saveCount = saveCount
    }
    
    // Custom Codable conformance to encode/decode CLLocationCoordinate2D
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case neighborhood
        case description
        case imageUrl
        case latitude
        case longitude
        case tags
        case owners
        case saveCount
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        neighborhood = try container.decode(String.self, forKey: .neighborhood)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        imageUrl = try container.decodeIfPresent(String.self, forKey: .imageUrl)
        let latitude = try container.decode(Double.self, forKey: .latitude)
        let longitude = try container.decode(Double.self, forKey: .longitude)
        location = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        tags = try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        owners = try container.decodeIfPresent([SpotOwner].self, forKey: .owners) ?? []
        saveCount = try container.decodeIfPresent(Int.self, forKey: .saveCount) ?? 0
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(neighborhood, forKey: .neighborhood)
        try container.encodeIfPresent(description, forKey: .description)
        try container.encodeIfPresent(imageUrl, forKey: .imageUrl)
        try container.encode(location.latitude, forKey: .latitude)
        try container.encode(location.longitude, forKey: .longitude)
        try container.encode(tags, forKey: .tags)
        try container.encode(owners, forKey: .owners)
        try container.encode(saveCount, forKey: .saveCount)
    }
    
    // Custom Hashable / Equatable to avoid needing CLLocationCoordinate2D Hashable
    static func == (lhs: Spot, rhs: Spot) -> Bool {
        return lhs.id == rhs.id &&
            lhs.name == rhs.name &&
            lhs.neighborhood == rhs.neighborhood &&
            lhs.description == rhs.description &&
            lhs.imageUrl == rhs.imageUrl &&
            lhs.location.latitude == rhs.location.latitude &&
            lhs.location.longitude == rhs.location.longitude &&
            lhs.tags == rhs.tags &&
            lhs.owners == rhs.owners &&
            lhs.saveCount == rhs.saveCount
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(name)
        hasher.combine(neighborhood)
        hasher.combine(description)
        hasher.combine(imageUrl)
        hasher.combine(location.latitude)
        hasher.combine(location.longitude)
        hasher.combine(tags)
        hasher.combine(owners)
        hasher.combine(saveCount)
    }
}

// MARK: - Mapping from API DTO

extension Spot {
    init(from data: SpotData) {
        let coord = CLLocationCoordinate2D(latitude: data.latitude, longitude: data.longitude)
        let owner = SpotOwner(
            id: data.ownerId,
            handle: data.ownerHandle,
            initials: (data.ownerHandle?.prefix(1).uppercased()) ?? "?"
        )
        
        self.init(
            id: data.id,
            name: data.name,
            neighborhood: data.neighborhood ?? data.address,
            description: data.description,
            imageUrl: data.imageUrl,
            location: coord,
            tags: data.categoryTag.map { [$0] } ?? [],
            owners: [owner],
            saveCount: data.saveCount ?? 0
        )
    }
}
