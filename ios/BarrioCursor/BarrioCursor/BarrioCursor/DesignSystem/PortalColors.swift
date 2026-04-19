import SwiftUI

// MARK: - portal· Design System — Color Palette
// Gray neutrals, teal accent, rose live state.
//
// Usage: Prefer .foregroundColor(.portalXxx) in views. When using .foregroundStyle()
// with a portal color, use Color.portalXxx explicitly (e.g. .foregroundStyle(Color.portalMutedForeground.opacity(0.8)))
// so the type is unambiguous for ShapeStyle.

extension Color {
    // MARK: Base
    /// Page background — grayish off-white (neutral, not warm)
    static let portalBackground = Color(hex: "#F2F2F0")
    /// Primary text — near-black
    static let portalForeground = Color(hex: "#1F1810")
    /// Card surfaces #FFFFFF
    static let portalCard = Color(hex: "#FFFFFF")
    
    // MARK: Primary accent
    /// CTAs, active filter pills, wordmark dot — teal green
    static let portalPrimary = Color(hex: "#2F7168")
    /// Text on primary
    static let portalPrimaryForeground = Color(hex: "#FFFFFF")
    
    // MARK: Secondary & Muted
    /// Secondary surfaces — neutral grey
    static let portalSecondary = Color(hex: "#E8E8E6")
    /// Muted backgrounds
    static let portalMuted = Color(hex: "#E0E0DE")
    /// Secondary text, labels
    static let portalMutedForeground = Color(hex: "#6B6B68")
    
    // MARK: Semantic
    /// Friend attribution / personal colors (can be varied per user)
    static let portalAccent = Color(hex: "#2563EB")
    /// Live / happening now badges (PRD: warm rose)
    static let portalLive = Color(hex: "#F25C8C")
    /// Errors #E03E3E
    static let portalDestructive = Color(hex: "#E03E3E")
    
    // MARK: Border
    /// Borders, dividers
    static let portalBorder = Color(hex: "#E0E0DE")
    
    // MARK: Category pill colors (Discovery card design)
    static let portalCategoryFood = Color(hue: 340/360, saturation: 0.70, brightness: 0.52)
    static let portalCategoryMusic = Color(hue: 260/360, saturation: 0.60, brightness: 0.52)
    static let portalCategoryArt = Color(hue: 32/360, saturation: 0.95, brightness: 0.52)
    
    /// Category pill color by display name (Food, Music, Art, etc.)
    static func categoryPillColor(for category: String) -> Color {
        switch category.lowercased() {
        case "food": return portalCategoryFood
        case "drinks": return Color(hue: 280/360, saturation: 0.55, brightness: 0.55)
        case "cafe": return Color(hue: 28/360, saturation: 0.45, brightness: 0.40)
        case "music": return portalCategoryMusic
        case "art": return portalCategoryArt
        case "markets": return Color(hue: 145/360, saturation: 0.55, brightness: 0.45)
        case "community": return Color(hue: 38/360, saturation: 0.85, brightness: 0.55)
        default: return portalMutedForeground
        }
    }
    
    // MARK: Gradients (as LinearGradient helpers)
    /// Portal primary gradient — for CTAs and active pills (teal)
    static var portalGradientPrimary: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "#2F7168"), Color(hex: "#3D8A80")],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Dark overlay for image cards (strong bottom scrim for white text on light photos)
    static var portalGradientOverlay: LinearGradient {
        LinearGradient(
            colors: [Color.clear, Color.black.opacity(0.9)],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}
