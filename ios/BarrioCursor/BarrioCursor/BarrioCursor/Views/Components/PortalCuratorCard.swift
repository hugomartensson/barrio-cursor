import SwiftUI

/// Non-empty loadable URL for remote images (absolute https or Supabase-relative paths).
private func portalMediaURL(_ string: String?) -> URL? {
    MediaURL.httpsURL(from: string)
}

// MARK: - portal· Suggested user (People you know) — from API GET /users/suggested or mock
struct SuggestedUserItem: Identifiable {
    let id: String
    let name: String
    let handle: String
    let followerCount: String // e.g. "48k"
    let initial: String
    let accentColor: Color
    let city: String
    let saveCount: Int
    let mutualCount: Int
    let categoryLabels: [String]
    let profileImageURL: String?
}

private let suggestedUserAccentColors: [Color] = [.portalPrimary, .portalAccent, .portalLive]

extension SuggestedUserItem {
    init(from c: SuggestedUserData) {
        id = c.id
        handle = c.handle ?? "?"
        name = handle
        initial = c.initials.flatMap { $0.prefix(1).uppercased() } ?? String(handle.prefix(1)).uppercased()
        followerCount = c.followerCount >= 1000 ? String(format: "%.1fk", Double(c.followerCount) / 1000) : "\(c.followerCount)"
        accentColor = suggestedUserAccentColors[abs(c.id.hashValue) % suggestedUserAccentColors.count]
        let firstCity = c.cities.first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        city = firstCity.isEmpty ? "" : firstCity
        saveCount = 0
        mutualCount = 0
        categoryLabels = ["Food", "Music", "Art"]
        profileImageURL = c.profilePictureUrl
    }
}

// MARK: - portal· Collection (browse) — from API GET /collections/recommended or mock
struct PortalCollectionItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let imageURL: String?
    let ownerInitial: String
    let ownerHandle: String
    let accentColor: Color
    let itemCount: Int?
    let saveCount: Int?
    let categoryLabels: [String]
    /// First 2–3 spot image URLs for the right-hand strip miniatures. When nil, strip shows placeholders.
    let previewImageURLs: [String]?

    /// Cover for the main panel: explicit cover, else first preview thumbnail (helps when API omits `coverImageURL`).
    var resolvedCoverImageURLString: String? {
        if let u = imageURL?.trimmingCharacters(in: .whitespacesAndNewlines), !u.isEmpty { return u }
        return previewImageURLs?.first(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
    }
}

private let collectionAccentColors: [Color] = [.portalAccent, .portalLive, .portalPrimary]

extension PortalCollectionItem {
    init(from c: CollectionData) {
        id = c.id
        title = c.name
        subtitle = c.description ?? ""
        let cover = c.coverImageURL?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let cover, !cover.isEmpty {
            imageURL = cover
        } else if let first = c.previewSpotImageURLs?.first?.trimmingCharacters(in: .whitespacesAndNewlines), !first.isEmpty {
            imageURL = first
        } else {
            imageURL = nil
        }
        ownerHandle = c.ownerHandle ?? "?"
        ownerInitial = c.ownerInitials.flatMap { $0.prefix(1).uppercased() } ?? String(ownerHandle.prefix(1)).uppercased()
        accentColor = collectionAccentColors[abs(c.id.hashValue) % collectionAccentColors.count]
        itemCount = c.itemCount
        saveCount = c.saveCount
        categoryLabels = ["Food", "Music", "Art"]
        previewImageURLs = c.previewSpotImageURLs
    }
}

// MARK: - User card (Discovery) — Vinyl sleeve style: 96pt avatar ring, centered, no card bg, 140pt wide
private let userCardWidth: CGFloat = 140
private let userAvatarRingSize: CGFloat = 96
private let userAvatarImageSize: CGFloat = 78

struct SuggestedUserCard: View {
    let user: SuggestedUserItem

    var body: some View {
        VStack(alignment: .center, spacing: 6) {
            avatarWithRing
            Text(user.name)
                .font(.portalDisplay14)
                .foregroundColor(.portalForeground)
                .lineLimit(1)
                .multilineTextAlignment(.center)
            statsRow
        }
        .frame(width: userCardWidth)
    }

    /// 96pt ring (neutral border), 78pt image inside; optional groove overlay.
    private var avatarWithRing: some View {
        ZStack {
            // Decorative groove rings (vinyl)
            Circle()
                .strokeBorder(Color.portalBorder.opacity(0.3), lineWidth: 1)
                .frame(width: userAvatarRingSize - 12, height: userAvatarRingSize - 12)
            Circle()
                .strokeBorder(Color.portalBorder.opacity(0.15), lineWidth: 1)
                .frame(width: userAvatarRingSize - 24, height: userAvatarRingSize - 24)
            // Avatar image (78pt)
            avatarContent
                .frame(width: userAvatarImageSize, height: userAvatarImageSize)
                .clipShape(Circle())
        }
        .frame(width: userAvatarRingSize, height: userAvatarRingSize)
        .overlay(Circle().stroke(Color.portalBorder, lineWidth: 1))
    }

    private var avatarContent: some View {
        Group {
            if let urlString = user.profileImageURL, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Circle()
                            .fill(user.accentColor)
                            .overlay(Text(user.initial).font(.portalDisplay18).foregroundColor(.portalPrimaryForeground))
                    }
                }
            } else {
                Circle()
                    .fill(user.accentColor)
                    .overlay(
                        Text(user.initial)
                            .font(.portalDisplay18)
                            .foregroundColor(.portalPrimaryForeground)
                    )
            }
        }
    }

    /// Two rows: location (full width so name fits), then mutuals (avatars + count).
    private var statsRow: some View {
        VStack(alignment: .center, spacing: 4) {
            if !user.city.isEmpty && user.city != "—" {
                HStack(spacing: 2) {
                    Image(systemName: "mappin")
                        .font(.portalMinText)
                    Text(user.city)
                        .font(.portalMetadata)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)
            }
            if user.mutualCount > 0 {
                HStack(spacing: 4) {
                    HStack(spacing: -3) {
                        ForEach(Array(mutualPlaceholderAvatars.prefix(3).enumerated()), id: \.offset) { _, u in
                            Circle()
                                .fill(u.color)
                                .frame(width: 18, height: 18)
                                .overlay(
                                    Text(u.initials)
                                        .font(.system(size: 9, weight: .regular))
                                        .foregroundColor(.white)
                                )
                                .overlay(Circle().stroke(Color.portalBackground, lineWidth: 1))
                        }
                    }
                    Text("\(user.mutualCount) mutuals")
                        .font(.portalMetadata)
                }
            }
        }
        .foregroundColor(.portalMutedForeground)
    }
}

private let mutualPlaceholderAvatars: [(initials: String, color: Color)] = [
    ("A", Color(hex: "#3498DB")),
    ("B", Color(hex: "#E74C3C")),
    ("C", Color(hex: "#27AE60")),
]

// MARK: - Collection card (Discovery) — Magazine cover + 52pt side miniature strip, 260pt wide, 4:5
private let collectionCardWidth: CGFloat = 260
private let collectionStripWidth: CGFloat = 52

struct PortalCollectionCard: View {
    let collection: PortalCollectionItem
    var isSaved: Bool = false
    var onSaveToggle: (() -> Void)? = nil
    /// When set, card uses this width (e.g. feed width when expanded). Otherwise uses default 260pt.
    var cardWidth: CGFloat? = nil
    /// When true (e.g. "See more" view), use larger fonts.
    var isExpanded: Bool = false
    private var effectiveWidth: CGFloat { cardWidth ?? collectionCardWidth }
    private var categoryFontSize: CGFloat { isExpanded ? 14 : 13 }
    private var titleFontSize: CGFloat { isExpanded ? 22 : 20 }
    private var bylineFontSize: CGFloat { isExpanded ? 14 : 13 }
    private var curatorAvatarSize: CGFloat { isExpanded ? 26 : 22 }
    private var curatorInitialFontSize: CGFloat { 13 }
    private var cardHeight: CGFloat { effectiveWidth * (5 / 4) }
    /// Magazine panel is everything except the fixed 52pt miniature strip (do not use `maxWidth: .infinity` here — it can swallow the strip in `HStack` layout).
    private var mainPanelWidth: CGFloat { effectiveWidth - collectionStripWidth }

    /// Thumbnail column: fixed width; row heights derived from `rowCount` so tiles are not crushed to ~20pt.
    private var collectionMiniatureStrip: some View {
        let pad: CGFloat = 4
        let innerW = collectionStripWidth - pad * 2
        let urls = Array((collection.previewImageURLs ?? []).prefix(2))
        let showBadge = (collection.itemCount ?? 0) > 2
        let badgeH: CGFloat = showBadge ? 26 : 0
        let gap: CGFloat = 4
        let rowCount: Int = {
            if !urls.isEmpty { return urls.count }
            return min(2, collection.itemCount ?? 2)
        }()
        let gapAfterRows = showBadge && rowCount > 0 ? gap : 0
        let gapBetweenRows = rowCount > 1 ? CGFloat(rowCount - 1) * gap : 0
        let availableH = cardHeight - pad * 2 - badgeH - gapBetweenRows - gapAfterRows
        let thumbH: CGFloat = rowCount > 0 ? max(30, availableH / CGFloat(rowCount)) : 0

        return VStack(spacing: gap) {
            if !urls.isEmpty {
                ForEach(Array(urls.enumerated()), id: \.offset) { _, urlString in
                    if let url = portalMediaURL(urlString) {
                        CachedRemoteImage(
                            url: url,
                            placeholder: { Rectangle().fill(Color.portalMuted).overlay { ProgressView() } },
                            failure: { Rectangle().fill(Color.portalMuted) }
                        )
                        .frame(width: innerW, height: thumbH)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))
                    } else {
                        Rectangle()
                            .fill(Color.portalMuted)
                            .frame(width: innerW, height: thumbH)
                            .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))
                    }
                }
            } else {
                ForEach(0..<min(2, collection.itemCount ?? 2), id: \.self) { _ in
                    Rectangle()
                        .fill(Color.portalMuted)
                        .frame(width: innerW, height: thumbH)
                        .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))
                }
            }
            if let n = collection.itemCount, n > 2 {
                RoundedRectangle(cornerRadius: .portalRadiusSm)
                    .fill(Color.portalForeground.opacity(0.3))
                    .overlay(
                        Text("+\(n - 2)")
                            .font(.portalBadge)
                            .foregroundColor(.portalCard.opacity(0.8))
                    )
                    .frame(width: innerW, height: badgeH)
            }
        }
        .padding(pad)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Main cover — width is explicit so the strip always reserves 52pt.
            ZStack(alignment: .bottomLeading) {
                if let coverURL = collection.resolvedCoverImageURLString,
                   !coverURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    CachedRemoteImage(
                        url: portalMediaURL(coverURL),
                        placeholder: { Rectangle().fill(Color.portalMuted).overlay { ProgressView() } },
                        failure: { CollectionCoverFallback(seed: collection.title, letter: collection.title.prefix(1).uppercased()) }
                    )
                    .frame(width: mainPanelWidth, height: cardHeight)
                    .clipped()
                } else {
                    CollectionCoverFallback(seed: collection.title, letter: collection.title.prefix(1).uppercased())
                        .frame(width: mainPanelWidth, height: cardHeight)
                        .clipped()
                }

                EditorialBottomGradient(heightFraction: 0.62, cardHeight: cardHeight)
                    .frame(width: mainPanelWidth, height: cardHeight)
                    .zIndex(0)

                VStack {
                    HStack {
                        Spacer(minLength: 0)
                        if onSaveToggle != nil {
                            PortalSaveButton(isSaved: isSaved, count: collection.saveCount ?? 0, surface: .dark) {
                                onSaveToggle?()
                            }
                            .background(Circle().fill(.ultraThinMaterial))
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.top, 10)
                    Spacer(minLength: 0)
                }
                .frame(width: mainPanelWidth, height: cardHeight)
                .zIndex(1)

                VStack(alignment: .leading, spacing: isExpanded ? 8 : 6) {
                    HStack(spacing: 4) {
                        ForEach(Array(collection.categoryLabels.prefix(2).enumerated()), id: \.offset) { _, label in
                            Text(label)
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.12)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.categoryPillColor(for: label).opacity(0.2))
                                .foregroundColor(.portalCard)
                                .clipShape(RoundedRectangle(cornerRadius: .portalCategoryPillRadius))
                        }
                    }
                    Text(collection.title)
                        .font(.portalDisplayBlack(size: titleFontSize))
                        .foregroundColor(.portalCard)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .minimumScaleFactor(0.88)
                        .shadow(color: .black.opacity(0.45), radius: 4, x: 0, y: 1)
                    HStack(spacing: 6) {
                        Circle()
                            .fill(Color.portalPrimary)
                            .frame(width: curatorAvatarSize, height: curatorAvatarSize)
                            .overlay(
                                Text(collection.ownerInitial)
                                    .font(.system(size: curatorInitialFontSize, weight: .regular))
                                    .foregroundColor(.portalPrimaryForeground)
                            )
                        Text("by \(collection.ownerHandle)")
                            .font(.portalItalic(size: bylineFontSize))
                            .foregroundColor(.portalCard.opacity(0.7))
                            .shadow(color: .black.opacity(0.4), radius: 3, x: 0, y: 1)
                    }
                }
                .padding(.horizontal, isExpanded ? 16 : 12)
                .padding(.bottom, isExpanded ? 16 : 12)
                .frame(width: mainPanelWidth, alignment: .bottomLeading)
                .zIndex(3)
            }
            .frame(width: mainPanelWidth, height: cardHeight)
            .clipped()

            // Right — vertical miniature strip (real spot thumbnails when previewImageURLs provided)
            collectionMiniatureStrip
                .frame(width: collectionStripWidth, height: cardHeight)
                .background(Color.portalForeground.opacity(0.05))
        }
        .frame(width: effectiveWidth)
        .frame(height: cardHeight) // 4:5 aspect
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))
        .overlay(
            RoundedRectangle(cornerRadius: .portalRadiusSm)
                .stroke(Color.portalBorder, lineWidth: 1)
        )
        .portalCardShadow()
    }
}

// MARK: - Mock data
extension SuggestedUserItem {
    static let mock: [SuggestedUserItem] = [
        SuggestedUserItem(id: "1", name: "Mia Chen", handle: "mia_eats", followerCount: "48k", initial: "M", accentColor: .portalPrimary, city: "NYC", saveCount: 48, mutualCount: 12, categoryLabels: ["Food", "Music", "Art"], profileImageURL: nil),
        SuggestedUserItem(id: "2", name: "The Night Edit", handle: "nightedit", followerCount: "72k", initial: "NE", accentColor: .portalAccent, city: "NYC", saveCount: 72, mutualCount: 8, categoryLabels: ["Music", "Art"], profileImageURL: nil),
        SuggestedUserItem(id: "3", name: "Weekend Atlas", handle: "weekendatlas", followerCount: "30k", initial: "W", accentColor: .portalLive, city: "Brooklyn", saveCount: 30, mutualCount: 5, categoryLabels: ["Food", "Art"], profileImageURL: nil),
    ]
}

extension PortalCollectionItem {
    static let mock: [PortalCollectionItem] = [
        PortalCollectionItem(id: "1", title: "The Night Edit", subtitle: "Late Night Done Right", imageURL: nil, ownerInitial: "NE", ownerHandle: "nightedit", accentColor: .portalAccent, itemCount: 12, saveCount: 2100, categoryLabels: ["Food", "Music", "Art"], previewImageURLs: nil),
        PortalCollectionItem(id: "2", title: "Weekend Atlas", subtitle: "A Red Saturday Brooklyn", imageURL: nil, ownerInitial: "W", ownerHandle: "weekendatlas", accentColor: .portalLive, itemCount: 8, saveCount: nil, categoryLabels: ["Food", "Art"], previewImageURLs: nil),
    ]
}

// MARK: - Branded fallback for collections with no cover

/// Deterministic gradient + first letter, shown when a collection has no
/// cover image and no spot media to fall back to. Same name → same gradient.
struct CollectionCoverFallback: View {
    let seed: String
    let letter: String

    private static let palettes: [[Color]] = [
        [Color(hex: "#2F7168"), Color(hex: "#3D8A80")],
        [Color(hex: "#E94560"), Color(hex: "#FF6B6B")],
        [Color(hex: "#5B6CFF"), Color(hex: "#7C5BFF")],
        [Color(hex: "#F2994A"), Color(hex: "#F2C94C")],
        [Color(hex: "#27AE60"), Color(hex: "#6FCF97")],
        [Color(hex: "#9B51E0"), Color(hex: "#BB6BD9")],
    ]

    private var palette: [Color] {
        Self.palettes[abs(seed.hashValue) % Self.palettes.count]
    }

    var body: some View {
        ZStack {
            LinearGradient(colors: palette, startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(letter)
                .font(.system(size: 64, weight: .bold))
                .foregroundColor(.white.opacity(0.85))
        }
    }
}
