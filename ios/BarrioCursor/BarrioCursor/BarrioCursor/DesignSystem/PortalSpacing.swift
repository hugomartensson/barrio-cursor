import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Screen bounds (MainActor-only to avoid unsafeForcedSync from concurrent context)
@MainActor
enum PortalScreenBounds {
    static var width: CGFloat {
#if canImport(UIKit)
        UIScreen.main.bounds.width
#else
        393
#endif
    }
}

// MARK: - portal· Design System — Spacing & Layout Tokens

extension CGFloat {
    /// Page-level horizontal padding — 16pt
    static let portalPagePadding: CGFloat = 16
    /// Vertical spacing between sections — 24pt
    static let portalSectionSpacing: CGFloat = 24
    /// Gap between cards in horizontal stacks — 12pt
    static let portalCardGap: CGFloat = 12
    /// Default corner radius for cards/containers — 1rem (PRD)
    static let portalRadius: CGFloat = 16
    /// Editorial / magazine cards — sharp "clipped" corners (rounded-sm)
    static let portalRadiusSm: CGFloat = 8
    /// Category pills everywhere — rectangular with slightly rounded corners (not full pill)
    static let portalCategoryPillRadius: CGFloat = 6
    /// Date sidebar width on event cards — 72pt (reference design)
    static let portalDateSidebarWidth: CGFloat = 72
    /// Tab bar height (no search) — 49pt
    static let portalBottomNavHeight: CGFloat = 49
    /// Tab bar + search bar height (search bar lifted from icons)
    static let portalBottomNavWithSearchHeight: CGFloat = 108
}

// MARK: - Signature Colors (deterministic per-entity assignment)

extension Color {
    static let signatureColors: [Color] = [
        Color(hex: "#E94560"),
        Color(hex: "#F45A2A"),
        Color(hex: "#9B59B6"),
        Color(hex: "#3498DB"),
        Color(hex: "#27AE60"),
        Color(hex: "#F39C12"),
        Color(hex: "#1ABC9C"),
        Color(hex: "#E74C3C"),
    ]

    static let signatureCoral = Color(hex: "#E94560")
}

// MARK: - Card & CTA shadows (reference design)

extension View {
    /// Card shadow: subtle structural depth (1pt + 6pt)
    func portalCardShadow() -> some View {
        self
            .shadow(color: Color.portalForeground.opacity(0.05), radius: 1, x: 0, y: 1)
            .shadow(color: Color.portalForeground.opacity(0.07), radius: 6, x: 0, y: 3)
    }

    /// Warm CTA shadow: amber-tinted for primary buttons (e.g. Explore)
    func portalWarmShadow() -> some View {
        self.shadow(color: Color.portalPrimary.opacity(0.35), radius: 4, x: 0, y: 2)
    }
}
