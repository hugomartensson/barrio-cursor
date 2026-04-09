import SwiftUI

// MARK: - portal· Design System — Typography
// Display / wordmark = DM Sans Black (bundled). Editorial italic = DM Sans Italic. Body = system.

private enum PortalFontNames {
    /// Bundled in Resources/Fonts/
    static let displayBlack = "DMSans-Black"
    static let displayItalic = "DMSans-Italic"
}

extension Font {
    static func portalDisplayBlack(size: CGFloat) -> Font {
        .custom(PortalFontNames.displayBlack, size: size)
    }

    static func portalItalic(size: CGFloat) -> Font {
        .custom(PortalFontNames.displayItalic, size: size)
    }

    // MARK: Wordmark
    static let portalWordmark: Font = .custom(PortalFontNames.displayBlack, size: 48)
    static let portalWordmarkItalic: Font = .custom(PortalFontNames.displayItalic, size: 48)

    // MARK: Display / Headlines
    static let portalDisplay72: Font = .custom(PortalFontNames.displayBlack, size: 72)
    static let portalDisplay28: Font = .custom(PortalFontNames.displayBlack, size: 28)
    static let portalDisplay22: Font = .custom(PortalFontNames.displayBlack, size: 22)
    static let portalDisplay20: Font = .custom(PortalFontNames.displayBlack, size: 20)
    static let portalDisplay24: Font = .custom(PortalFontNames.displayBlack, size: 24)
    static let portalDisplay18: Font = .custom(PortalFontNames.displayBlack, size: 18)
    static let portalDisplay14: Font = .custom(PortalFontNames.displayBlack, size: 14)
    /// Editorial italic accent (DM Sans — no serif)
    static let portalSerifItalic: Font = .custom(PortalFontNames.displayItalic, size: 18)
    static let portalSerifItalicSmall: Font = .custom(PortalFontNames.displayItalic, size: 13)

    // MARK: Section labels (system)
    static let portalSectionLabel: Font = .system(size: 10, weight: .bold)
    /// Discover section titles (EVENTS, SPOTS, …) — 12pt bold + wide tracking in views
    static let portalSectionTitle: Font = .system(size: 12, weight: .bold)
    /// Minimum readable size; no UI text smaller than "See more" (13pt)
    static let portalMinText: Font = .system(size: 13, weight: .regular)

    // MARK: Body / UI (system sans)
    static let portalBody: Font = .system(size: 17, weight: .regular)
    static let portalLabelSemibold: Font = .system(size: 12, weight: .semibold)
    static let portalLabel: Font = .system(size: 15, weight: .medium)
    static let portalMetadata: Font = .system(size: 13, weight: .regular)
    static let portalCategoryPill: Font = .system(size: 13, weight: .semibold)
    static let portalBadge: Font = .system(size: 13, weight: .semibold)
    static let portalMetadataLight: Font = .system(size: 13, weight: .regular)
}
