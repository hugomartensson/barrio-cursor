import SwiftUI

// MARK: - Spot (portal Discover — from API GET /spots or mock)

/// Display label for spot category tag — matches filter pills: "Music" not "music".
private func spotCategoryDisplayLabel(_ raw: String) -> String {
    DiscoverCategory(rawValue: raw.lowercased())?.label ?? raw.capitalized
}

/// Friend who saved this spot (for detail social proof)
struct SpotFriendSaved: Hashable {
    let name: String
    let initials: String
}

struct PortalSpotItem: Identifiable, Hashable {
    let id: String
    let name: String
    let neighborhood: String
    let imageURL: String?
    let categoryLabel: String?
    let ownerHandle: String
    let ownerInitial: String
    var saveCount: Int
    let description: String?
    let tags: [String]
    let distanceText: String?
    let friendsWhoSaved: [SpotFriendSaved]

    init(
        id: String,
        name: String,
        neighborhood: String,
        imageURL: String?,
        categoryLabel: String?,
        ownerHandle: String,
        ownerInitial: String,
        saveCount: Int,
        description: String? = nil,
        tags: [String] = [],
        distanceText: String? = nil,
        friendsWhoSaved: [SpotFriendSaved] = []
    ) {
        self.id = id
        self.name = name
        self.neighborhood = neighborhood
        self.imageURL = imageURL
        self.categoryLabel = categoryLabel
        self.ownerHandle = ownerHandle
        self.ownerInitial = ownerInitial
        self.saveCount = saveCount
        self.description = description
        self.tags = tags
        self.distanceText = distanceText
        self.friendsWhoSaved = friendsWhoSaved
    }
}

extension PortalSpotItem {
    /// Build from domain Spot (PRD-aligned model)
    init(from spot: Spot) {
        let primaryOwner = spot.owners.first
        self.init(
            id: spot.id,
            name: spot.name,
            neighborhood: spot.neighborhood,
            imageURL: spot.imageUrl,
            categoryLabel: spot.tags.first,
            ownerHandle: primaryOwner?.handle ?? "?",
            ownerInitial: primaryOwner?.initials ?? "?",
            saveCount: spot.saveCount,
            description: spot.description,
            tags: spot.tags
        )
    }
}

// MARK: - Magazine clipping style — 200pt wide, 4:5, sharp corners, drop-cap title, dark gradient

private let spotCardWidth: CGFloat = 200

struct PortalSpotCard: View {
    let spot: PortalSpotItem
    /// When set, card uses this width (e.g. feed width when expanded). Otherwise uses default 200pt.
    var cardWidth: CGFloat? = nil
    var isSaved: Bool = false
    var onSaveToggle: (() -> Void)? = nil
    /// When true (e.g. "See more" view), use larger fonts.
    var isExpanded: Bool = false
    private var effectiveWidth: CGFloat { cardWidth ?? spotCardWidth }
    private var categoryFontSize: CGFloat { isExpanded ? 14 : 13 }
    private var neighborhoodFontSize: CGFloat { isExpanded ? 14 : 13 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Image panel with overlay and text
            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    AsyncImage(url: URL(string: spot.imageURL ?? "")) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.portalMuted)
                                .overlay { ProgressView() }
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        case .failure:
                            Rectangle()
                                .fill(Color.portalMuted)
                                .overlay(
                                    Image(systemName: "fork.knife")
                                        .font(.title2)
                                        .foregroundColor(.portalMutedForeground)
                                )
                        @unknown default:
                            Rectangle().fill(Color.portalMuted)
                        }
                    }
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()

                    EditorialBottomGradient(heightFraction: 0.6, cardHeight: geo.size.height)

                    // Save button top-right only when parent provides onSaveToggle; otherwise overlay shows it
                    if onSaveToggle != nil {
                        VStack {
                            HStack {
                                Spacer(minLength: 0)
                                PortalSaveButton(isSaved: isSaved, count: spot.saveCount, surface: .dark, action: { onSaveToggle?() })
                                .padding(.top, 10)
                                .padding(.trailing, 10)
                            }
                            Spacer(minLength: 0)
                        }
                        .zIndex(1)
                    }

                    // Text overlay (bottom of image) — tag matches filter: same color, "Music" not "music"
                    VStack(alignment: .leading, spacing: isExpanded ? 8 : 6) {
                        if let cat = spot.categoryLabel {
                            Text(spotCategoryDisplayLabel(cat))
                                .font(.system(size: 11, weight: .semibold))
                                .tracking(0.12)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.categoryPillColor(for: cat).opacity(0.2))
                                .foregroundColor(.portalCard)
                                .clipShape(RoundedRectangle(cornerRadius: .portalCategoryPillRadius))
                        }
                        // Drop-cap + serif italic title
                        spotTitleView
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                                .font(.system(size: neighborhoodFontSize))
                            Text(spot.neighborhood)
                                .font(.portalItalic(size: neighborhoodFontSize))
                        }
                        .foregroundColor(Color.portalCard.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(isExpanded ? 16 : 12)
                }
            }
            .aspectRatio(4/5, contentMode: .fill)
            .frame(width: effectiveWidth)
            .clipped()
        }
        .frame(width: effectiveWidth)
        .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))
        .overlay(
            RoundedRectangle(cornerRadius: .portalRadiusSm)
                .stroke(Color.portalBorder, lineWidth: 1)
        )
        .portalCardShadow()
    }

    /// First character = display (28pt); rest = serif italic (20pt / 22pt) — magazine feel.
    private var spotTitleView: some View {
        let name = spot.name
        let first = name.isEmpty ? "" : String(name.prefix(1))
        let rest = name.count <= 1 ? "" : String(name.dropFirst())
        return HStack(alignment: .firstTextBaseline, spacing: 0) {
            Text(first)
                .font(.portalDisplay28)
                .foregroundColor(.portalCard)
            Text(rest)
                .font(isExpanded ? .portalItalic(size: 22) : .portalItalic(size: 20))
                .foregroundColor(.portalCard)
                .lineLimit(2)
        }
    }
}

// MARK: - Spot Detail (editorial magazine layout — aligned with app design system)
struct SpotDetailView: View {
    let spot: PortalSpotItem
    var isSaved: Bool = false
    var saveCount: Int? = nil
    var onSaveToggle: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authManager: AuthManager

    @State private var showAddToCollection = false
    /// Optimistic UI after toggle when using built-in API save
    @State private var resolvedSaved: Bool?
    @State private var resolvedSaveCount: Int?

    private var displaySaved: Bool { resolvedSaved ?? isSaved }
    private var displaySaveCount: Int { resolvedSaveCount ?? saveCount ?? spot.saveCount }
    private let bodyVerticalSpacing: CGFloat = 20
    private let heroAspectRatio: CGFloat = 4/3

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                heroSection
                bodySection
            }
        }
        .background(Color.portalBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - Hero (4/3 image to top edge, gradient, nav buttons, category + title)
    private var heroSection: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = w / heroAspectRatio
            ZStack(alignment: .top) {
                spotHeroImage
                    .frame(width: w, height: h)
                    .clipped()

                spotHeroGradient(cardHeight: h)
                    .frame(width: w, height: h)
                    .allowsHitTesting(false)

                VStack {
                    spotHeroTopBar
                        .padding(.horizontal, .portalPagePadding)
                        .padding(.top, 16 + geo.safeAreaInsets.top)
                    Spacer(minLength: 0)
                    spotHeroTitleBlock
                        .padding(.horizontal, .portalPagePadding)
                        .padding(.bottom, 16)
                }
                .frame(width: w, height: h)
            }
        }
        .aspectRatio(heroAspectRatio, contentMode: .fit)
        .ignoresSafeArea(edges: .top)
    }

    private var spotHeroImage: some View {
        Group {
            if let urlString = spot.imageURL, !urlString.isEmpty, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Rectangle()
                            .fill(Color.portalMuted)
                            .overlay { ProgressView() }
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.portalMuted)
                    .overlay(
                        Image(systemName: "fork.knife")
                            .font(.title)
                            .foregroundColor(.portalMutedForeground)
                    )
            }
        }
    }

    /// Bottom-heavy gradient for text legibility — full 90% black overlay per design spec
    private func spotHeroGradient(cardHeight: CGFloat) -> some View {
        Color.portalGradientOverlay
    }

    private var spotHeroTopBar: some View {
        HStack {
            Button {
                onDismiss?()
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.portalForeground)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.portalBorder.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            PortalSaveButton(isSaved: displaySaved, count: displaySaveCount, surface: .dark, action: performSaveTap)
        }
    }

    private func performSaveTap() {
        if let onSaveToggle {
            onSaveToggle()
            return
        }
        guard let token = authManager.token else { return }
        Task {
            do {
                let response = try await APIService.shared.toggleSaveSpot(spotId: spot.id, token: token)
                await MainActor.run {
                    resolvedSaved = response.saved
                    resolvedSaveCount = response.saveCount
                }
            } catch {
                #if DEBUG
                print("SpotDetailView save error: \(error)")
                #endif
            }
        }
    }

    private var spotHeroTitleBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let cat = spot.categoryLabel {
                Text(spotCategoryDisplayLabel(cat))
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(0.12)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.categoryPillColor(for: cat).opacity(0.2))
                    .foregroundColor(.portalCard)
                    .clipShape(RoundedRectangle(cornerRadius: .portalCategoryPillRadius))
            }
            Text(spot.name)
                .font(.portalItalic(size: 24))
                .foregroundColor(.white)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Body (location, description, tags, curator, friends, CTA)
    private var bodySection: some View {
        VStack(alignment: .leading, spacing: bodyVerticalSpacing) {
            locationPriceRow
            if let desc = spot.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.portalForeground.opacity(0.85))
                    .lineSpacing(4)
            }
            if !spot.tags.isEmpty {
                tagPills
            }
            Divider().background(Color.portalBorder)
            curatorRow
            Divider().background(Color.portalBorder)
            if !spot.friendsWhoSaved.isEmpty {
                friendsWhoSavedSection
            }
            addToCollectionButton
        }
        .padding(.horizontal, .portalPagePadding)
        .padding(.top, 20)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showAddToCollection) {
            AddToCollectionSheet(itemType: "spot", itemId: spot.id) {
                showAddToCollection = false
            }
            .environmentObject(authManager)
        }
    }

    private var addToCollectionButton: some View {
        Button {
            showAddToCollection = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 16))
                Text("Add to collection")
                    .font(.portalLabel)
            }
            .foregroundColor(.portalPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.portalPrimary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .padding(.top, 8)
    }

    private var locationPriceRow: some View {
        HStack(spacing: 12) {
            Image(systemName: "mappin")
                .font(.system(size: 12))
                .foregroundColor(.portalMutedForeground)
            Text(spot.neighborhood)
                .font(.system(size: 12))
                .foregroundColor(.portalMutedForeground)
        }
    }

    private var tagPills: some View {
        FlowLayout(spacing: 6) {
            ForEach(spot.tags, id: \.self) { tag in
                Text(spotCategoryDisplayLabel(tag))
                    .font(.portalSectionLabel)
                    .tracking(0.5)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.categoryPillColor(for: tag).opacity(0.2))
                    .foregroundColor(.portalForeground)
                    .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))
            }
        }
    }

    private var curatorRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("OWNER")
                .font(.portalSectionLabel)
                .tracking(2)
                .foregroundColor(.portalMutedForeground)
            HStack(spacing: 10) {
                Circle()
                    .fill(Color.portalPrimary)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(spot.ownerInitial)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.portalPrimaryForeground)
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(spot.ownerHandle)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.portalForeground)
                    Text("@\(spot.ownerHandle)")
                        .font(.system(size: 10))
                        .foregroundColor(.portalMutedForeground)
                }
                Spacer(minLength: 0)
            }
        }
    }

    private var friendsWhoSavedSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("FRIENDS WHO SAVED THIS")
                .font(.portalSectionLabel)
                .tracking(2)
                .foregroundColor(.portalMutedForeground)
            HStack(spacing: 12) {
                avatarStack
                friendsNamesText
            }
        }
    }

    private var avatarStack: some View {
        let friends = Array(spot.friendsWhoSaved.prefix(3))
        return HStack(spacing: -8) {
            ForEach(Array(friends.enumerated()), id: \.offset) { _, friend in
                Circle()
                    .fill(Color.portalSecondary)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(friend.initials)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.portalForeground)
                    )
                    .overlay(Circle().stroke(Color.portalBackground, lineWidth: 2))
            }
        }
    }

    @ViewBuilder
    private var friendsNamesText: some View {
        let friends = spot.friendsWhoSaved
        if !friends.isEmpty {
            let names = friends.prefix(2).map(\.name).joined(separator: ", ")
            let moreCount = friends.count > 2 ? friends.count - 2 : 0
            let more = moreCount > 0 ? " + \(moreCount) more" : ""
            HStack(spacing: 0) {
                Text(names)
                    .font(.system(size: 12))
                    .fontWeight(.medium)
                    .foregroundColor(.portalForeground)
                Text(more)
                    .font(.system(size: 12))
                    .foregroundColor(.portalMutedForeground)
            }
        }
    }

}

// MARK: - Flow layout for tags
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (i, pos) in result.positions.enumerated() {
            subviews[i].place(at: CGPoint(x: bounds.minX + pos.x, y: bounds.minY + pos.y), proposal: .unspecified)
        }
    }
    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}

// MARK: - Mock data for Discover
extension PortalSpotItem {
    static let mock: [PortalSpotItem] = [
        PortalSpotItem(
            id: "1",
            name: "Lilia",
            neighborhood: "Williamsburg",
            imageURL: nil,
            categoryLabel: "Italian",
            ownerHandle: "mia_eats",
            ownerInitial: "M",
            saveCount: 1200,
            description: "Hand-rolled pasta and wood-fired everything. The whipped ricotta alone is worth the trip.",
            tags: ["PASTA", "WINE", "ROMANTIC", "DATE"],
            distanceText: "1.2 mi",
            friendsWhoSaved: [
                SpotFriendSaved(name: "Jess", initials: "J"),
                SpotFriendSaved(name: "Marcus", initials: "M"),
                SpotFriendSaved(name: "Alex", initials: "A")
            ]
        ),
        PortalSpotItem(id: "2", name: "Death & Co", neighborhood: "East Village", imageURL: nil, categoryLabel: "Cocktail Bar", ownerHandle: "fredrik", ownerInitial: "F", saveCount: 890),
    ]
}

#Preview {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: .portalCardGap) {
            ForEach(PortalSpotItem.mock) { spot in
                PortalSpotCard(spot: spot)
            }
        }
        .padding()
    }
    .background(Color.portalBackground)
}
