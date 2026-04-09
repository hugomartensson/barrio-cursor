import SwiftUI

/// Non-empty absolute HTTP(S) URL for `AsyncImage` (avoids invalid `URL(string: "")`).
private func portalMediaURL(_ string: String?) -> URL? {
    guard let raw = string?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
    guard let url = URL(string: raw), url.scheme == "http" || url.scheme == "https" else { return nil }
    return url
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
}

private let collectionAccentColors: [Color] = [.portalAccent, .portalLive, .portalPrimary]

extension PortalCollectionItem {
    init(from c: CollectionData) {
        id = c.id
        title = c.name
        subtitle = c.description ?? ""
        imageURL = c.coverImageURL
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
            } else {
                Text("0 mutuals")
                    .font(.portalMetadata)
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

    var body: some View {
        HStack(spacing: 0) {
            // Main cover image (flex-1)
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    AsyncImage(url: portalMediaURL(collection.imageURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().aspectRatio(contentMode: .fill)
                        default:
                            Rectangle().fill(Color.portalMuted)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                    EditorialBottomGradient(heightFraction: 0.65, cardHeight: geo.size.height)

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
                        .lineLimit(2)
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
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(isExpanded ? 16 : 12)
                }
            }
            .frame(maxWidth: .infinity)

            // Right — vertical miniature strip (real spot thumbnails when previewImageURLs provided)
            VStack(spacing: 4) {
                let urls = (collection.previewImageURLs ?? []).prefix(2)
                if !urls.isEmpty {
                    ForEach(Array(urls.enumerated()), id: \.offset) { _, urlString in
                        if let url = portalMediaURL(urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill)
                                default:
                                    Rectangle().fill(Color.portalMuted)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 20)
                            .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))
                        } else {
                            Rectangle()
                                .fill(Color.portalMuted)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 20)
                                .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))
                        }
                    }
                } else {
                    ForEach(0..<min(2, collection.itemCount ?? 2), id: \.self) { _ in
                        Rectangle()
                            .fill(Color.portalMuted)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 20)
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
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 24)
                }
            }
            .padding(4)
            .frame(width: collectionStripWidth)
            .background(Color.portalForeground.opacity(0.05))
        }
        .frame(width: effectiveWidth)
        .frame(height: effectiveWidth * (5/4)) // 4:5 aspect
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
