import Foundation
import CoreLocation
import Combine

// MARK: - Shared Enums and Types
// 
// IMPORTANT: Types defined here are shared across multiple views.
// Do NOT redefine these types in individual view files - it causes "ambiguous for type lookup" errors.
//
// When to add a type here:
// - Used by 2+ views (e.g., DiscoverFilters used by DiscoverView and MapView)
// - Shared filter/sort options
// - Common UI enums
//
// When NOT to add here:
// - View-specific helper types (keep in view file)
// - API response types (keep in APIService.swift with the methods that use them)
// - Domain models (keep in separate Model files: Event.swift, User.swift, etc.)

// PRD Section 5.2: Discover time intent pills (Tonight, Tomorrow, This Weekend, Pick a date)
enum DiscoverTimeIntent: CaseIterable {
    case tonight
    case tomorrow
    case thisWeekend
    case pickDate

    var label: String {
        switch self {
        case .tonight: return "Tonight"
        case .tomorrow: return "Tomorrow"
        case .thisWeekend: return "This Weekend"
        case .pickDate: return "Custom range"
        }
    }
}

// PRD Section 5.2: Discover categories (Food, Drinks, Music, Art, Markets, Community)
enum DiscoverCategory: String, CaseIterable, Hashable {
    case food
    case drinks
    case music
    case art
    case markets
    case community
    
    var label: String {
        switch self {
        case .food: return "Food"
        case .drinks: return "Drinks"
        case .music: return "Music"
        case .art: return "Art"
        case .markets: return "Markets"
        case .community: return "Community"
        }
    }

    /// Per-category color for filter pills (matches EventCategory)
    var colorHex: String {
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

@MainActor
final class DiscoverFilters: ObservableObject {
    /// Selected time intent (nil = browse mode)
    @Published var time: DiscoverTimeIntent? = nil
    /// Selected content categories (empty = all)
    @Published var categories: Set<DiscoverCategory> = []
    /// When true, only show events from people the user follows (shared Discover + Map)
    @Published var followingOnly: Bool = false
    /// When set, both Discover and Map use this location instead of current device location (nil = use current location)
    @Published var searchLocation: CLLocationCoordinate2D? = nil
    /// When time == .pickDate, filter events to this range (inclusive). Nil = show all until user picks.
    @Published var customDateRange: (start: Date, end: Date)? = nil
    /// True when event or collection detail is pushed (hide map pill)
    @Published var isDetailPresented: Bool = false
}

// PRD Section 5.3: Sort options (used in DiscoverView)
enum SortOption: String, CaseIterable {
    case soonest = "Soonest"
    case distance = "Distance"
    case popular = "Popular"
    
    var displayName: String { rawValue }
}

// Make CLLocationCoordinate2D Equatable for onChange(of:) support
extension CLLocationCoordinate2D: @retroactive Equatable {
    public static func == (lhs: CLLocationCoordinate2D, rhs: CLLocationCoordinate2D) -> Bool {
        lhs.latitude == rhs.latitude && lhs.longitude == rhs.longitude
    }
}
