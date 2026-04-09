import Foundation
import CoreLocation
import SwiftUI

// Mark as nonisolated to avoid MainActor isolation warnings when used in actor contexts
nonisolated struct Event: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String
    let category: EventCategory
    let address: String // PRD: Address is primary, coordinates derived
    let neighborhood: String? // Neighborhood extracted at creation time from placemark
    let latitude: Double
    let longitude: Double
    let startTime: Date
    let endTime: Date?
    let createdAt: Date
    var saveCount: Int
    let distance: Int?
    let media: [MediaItem]
    let user: EventUser
    
    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    var distanceFormatted: String {
        guard let distance = distance else { return "" }
        if distance < 1000 {
            return "\(distance)m"
        } else {
            let km = Double(distance) / 1000.0
            return String(format: "%.1fkm", km)
        }
    }
    
    /// PRD: isOngoing – derived from start/end time window.
    var isOngoing: Bool {
        let now = Date()
        return startTime <= now && (endTime ?? startTime) > now
    }

    /// Short place label for cards (neighborhood / district), not full postal address.
    var displayNeighborhood: String {
        AddressFormatting.shortLocationLabel(neighborhood: neighborhood, address: address)
    }

    /// City name for Discover cards (consistent, no postal codes).
    var displayCity: String {
        AddressFormatting.cityName(neighborhood: neighborhood, address: address)
    }
}

nonisolated struct EventUser: Codable, Hashable {
    let id: String
    let name: String
}

nonisolated struct MediaItem: Codable, Identifiable, Hashable {
    let id: String
    let url: String
    let type: MediaType
    let order: Int
    let thumbnailUrl: String? // PRD: Thumbnail for videos
}

enum MediaType: String, Codable {
    case photo
}

// PRD categories: Food, Drinks, Music, Art, Markets, Community
enum EventCategory: String, Codable, CaseIterable {
    case food
    case drinks
    case music
    case art
    case markets
    case community
    
    var displayName: String {
        switch self {
        case .food: return "Food"
        case .drinks: return "Drinks"
        case .music: return "Music"
        case .art: return "Art"
        case .markets: return "Markets"
        case .community: return "Community"
        }
    }
    
    var icon: String {
        switch self {
        case .food: return "fork.knife"
        case .drinks: return "wineglass"
        case .music: return "music.note"
        case .art: return "paintpalette"
        case .markets: return "bag"
        case .community: return "person.3"
        }
    }
    
    var color: String {
        switch self {
        case .food: return "#FF6B6B"
        case .drinks: return "#9B59B6"
        case .music: return "#3498DB"
        case .art: return "#E67E22"
        case .markets: return "#27AE60"
        case .community: return "#F39C12"
        }
    }
}

// API Response wrappers
nonisolated struct EventResponse: Codable {
    let data: Event
}

nonisolated struct EventsListResponse: Codable {
    let data: [Event]
}

nonisolated struct SaveResponse: Codable {
    let data: SaveData
}

nonisolated struct SaveData: Codable {
    let saved: Bool
    let saveCount: Int
}

// Social/Following API Response types
nonisolated struct FollowResponse: Codable {
    let data: FollowData
}

nonisolated struct FollowData: Codable {
    let following: Bool
    let followerCount: Int
    let followingCount: Int
}

nonisolated struct FollowersListResponse: Codable {
    let data: [FollowerUser]
}

nonisolated struct FollowingListResponse: Codable {
    let data: [FollowerUser]
}

nonisolated struct FollowerUser: Codable, Identifiable {
    let id: String
    let name: String
    let profilePictureUrl: String?
    let followerCount: Int
    let isFollowing: Bool
}

nonisolated struct FollowRequestsResponse: Codable {
    let data: [FollowRequest]
}

nonisolated struct FollowRequest: Codable, Identifiable {
    let id: String
    let fromUserId: String
    let fromUserName: String
    let fromUserProfilePictureUrl: String?
    let status: String // "pending" | "accepted" | "declined"
    let createdAt: String
}

nonisolated struct SuccessResponse: Codable {
    let data: SuccessData
}

nonisolated struct SuccessData: Codable {
    let message: String
}

// MARK: - Event Portal Extensions
// Signature colors and live event detection

extension Event {
    /// Algorithmically assigned signature color for this event
    /// Uses hash-based assignment for deterministic color consistency
    var signatureColor: Color {
        let colors = Color.signatureColors
        guard !colors.isEmpty else { return .portalPrimary }
        // Use event ID hash for deterministic color assignment (abs to avoid negative index)
        let hash = abs(self.id.hashValue)
        return colors[hash % colors.count]
    }
    
    /// Whether this event is currently happening (live)
    /// Uses exact time window: startTime <= now && endTime > now
    var isLive: Bool {
        let now = Date()
        return startTime <= now && (endTime ?? startTime) > now
    }
}

