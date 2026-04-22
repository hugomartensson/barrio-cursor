import SwiftUI
import CoreLocation

private func spotCardMediaURL(_ string: String?) -> URL? {
    guard let raw = string?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else { return nil }
    guard let url = URL(string: raw), url.scheme == "http" || url.scheme == "https" else { return nil }
    return url
}

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
    /// Full address line from API when available — used for city-style labels on cards.
    let addressLine: String
    let imageURL: String?
    let categoryLabel: String?
    let ownerHandle: String
    let ownerInitial: String
    var saveCount: Int
    let description: String?
    let distanceText: String?
    let friendsWhoSaved: [SpotFriendSaved]
    /// Geographic coordinate — available when constructed from a `Spot` with location data.
    let coordinate: CLLocationCoordinate2D?

    init(
        id: String,
        name: String,
        neighborhood: String,
        addressLine: String = "",
        imageURL: String?,
        categoryLabel: String?,
        ownerHandle: String,
        ownerInitial: String,
        saveCount: Int,
        description: String? = nil,
        distanceText: String? = nil,
        friendsWhoSaved: [SpotFriendSaved] = [],
        coordinate: CLLocationCoordinate2D? = nil
    ) {
        self.id = id
        self.name = name
        self.neighborhood = neighborhood
        self.addressLine = addressLine
        self.imageURL = imageURL
        self.categoryLabel = categoryLabel
        self.ownerHandle = ownerHandle
        self.ownerInitial = ownerInitial
        self.saveCount = saveCount
        self.description = description
        self.distanceText = distanceText
        self.friendsWhoSaved = friendsWhoSaved
        self.coordinate = coordinate
    }

    static func == (lhs: PortalSpotItem, rhs: PortalSpotItem) -> Bool {
        lhs.id == rhs.id && lhs.saveCount == rhs.saveCount
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    /// City-only label for cards (matches event `displayCity`).
    var displayCity: String {
        let addr = addressLine.trimmingCharacters(in: .whitespacesAndNewlines)
        if !addr.isEmpty {
            return AddressFormatting.cityName(neighborhood: nil, address: addr)
        }
        return AddressFormatting.cityName(neighborhood: neighborhood, address: "")
    }
}

extension PortalSpotItem {
    /// Build from domain Spot (PRD-aligned model) — preserves coordinate for map use.
    init(from spot: Spot) {
        let primaryOwner = spot.owners.first
        self.init(
            id: spot.id,
            name: spot.name,
            neighborhood: spot.neighborhood,
            addressLine: spot.address,
            imageURL: spot.imageUrl,
            categoryLabel: spot.category.displayName,
            ownerHandle: primaryOwner?.handle ?? "?",
            ownerInitial: primaryOwner?.initials ?? "?",
            saveCount: spot.saveCount,
            description: spot.description,
            coordinate: spot.location
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
                    CachedRemoteImage(
                        url: spotCardMediaURL(spot.imageURL),
                        placeholder: {
                            Rectangle()
                                .fill(Color.portalMuted)
                                .overlay { ProgressView() }
                        },
                        failure: {
                            Rectangle()
                                .fill(Color.portalMuted)
                                .overlay(
                                    Image(systemName: "fork.knife")
                                        .font(.title2)
                                        .foregroundColor(.portalMutedForeground)
                                )
                        }
                    )
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
                            Text(spot.neighborhood.isEmpty ? spot.displayCity : spot.neighborhood)
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
    @State private var showSaveToPlan = false
    @State private var addedInfo: AddedToCollectionInfo? = nil
    @State private var collectionToShow: AddedToCollectionInfo? = nil
    @State private var addedToPlanInfo: AddedToPlanInfo? = nil
    @State private var showSpotMap = false
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
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                if let info = addedInfo {
                    AddedToCollectionBanner(
                        info: info,
                        onDismiss: { addedInfo = nil },
                        onGoToCollection: {
                            collectionToShow = info
                            addedInfo = nil
                        }
                    )
                    .environmentObject(authManager)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                if let planInfo = addedToPlanInfo {
                    AddedToPlanBanner(
                        info: planInfo,
                        onDismiss: { addedToPlanInfo = nil },
                        onViewPlan: { addedToPlanInfo = nil }
                    )
                    .environmentObject(authManager)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: addedInfo)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: addedToPlanInfo)
        .fullScreenCover(item: $collectionToShow) { info in
            NavigationStack {
                CollectionDetailView(collectionId: info.collectionId, name: info.collectionName)
                    .environmentObject(authManager)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button { collectionToShow = nil } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 16, weight: .medium))
                            }
                        }
                    }
            }
        }
        .fullScreenCover(isPresented: $showSpotMap) {
            FocusedMapView(
                title: spot.name,
                spots: [spot],
                events: [],
                focusCoordinate: spot.coordinate
            )
            .environmentObject(authManager)
        }
        .sheet(isPresented: $showSaveToPlan) {
            SaveToPlanSheet(
                itemType: "spot",
                itemId: spot.id,
                itemTitle: spot.name,
                itemCategory: spot.categoryLabel ?? "",
                itemImageURL: spot.imageURL,
                onSaved: { info in
                    addedToPlanInfo = info
                }
            )
            .environmentObject(authManager)
        }
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
                    HStack(alignment: .bottom) {
                        spotHeroTitleBlock
                        Spacer(minLength: 8)
                        if spot.coordinate != nil {
                            Button { showSpotMap = true } label: {
                                Image(systemName: "map.fill")
                                    .font(.system(size: 15))
                                    .foregroundColor(.white)
                                    .frame(width: 38, height: 38)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
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
            if let url = spotCardMediaURL(spot.imageURL) {
                CachedRemoteImage(
                    url: url,
                    placeholder: {
                        Rectangle()
                            .fill(Color.portalMuted)
                            .overlay { ProgressView() }
                    },
                    failure: {
                        Rectangle()
                            .fill(Color.portalMuted)
                            .overlay(
                                Image(systemName: "fork.knife")
                                    .font(.title)
                                    .foregroundColor(.portalMutedForeground)
                            )
                    }
                )
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

    // MARK: - Body (location, description, action bar, collections, saved by)
    private var bodySection: some View {
        VStack(alignment: .leading, spacing: bodyVerticalSpacing) {
            locationPriceRow
            if let desc = spot.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.portalForeground.opacity(0.85))
                    .lineSpacing(4)
            }
            DetailActionBar(
                itemType: "spot",
                isSaved: displaySaved,
                saveCount: displaySaveCount,
                onSave: performSaveTap,
                onAddToPlan: { showSaveToPlan = true },
                onAddToCollection: {
                    addedInfo = nil
                    showAddToCollection = true
                }
            )
            Divider().background(Color.portalBorder)
            CollectionsContainingSection(itemType: "spot", itemId: spot.id)
                .environmentObject(authManager)
            Divider().background(Color.portalBorder)
            SavedByRow(itemType: "spot", itemId: spot.id)
                .environmentObject(authManager)
        }
        .padding(.horizontal, .portalPagePadding)
        .padding(.top, 20)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showAddToCollection) {
            AddToCollectionSheet(itemType: "spot", itemId: spot.id, onAdded: { colId, colName in
                addedInfo = AddedToCollectionInfo(
                    collectionId: colId,
                    collectionName: colName,
                    itemId: spot.id,
                    itemType: "spot"
                )
                showAddToCollection = false
            })
            .environmentObject(authManager)
        }
    }

    private var locationPriceRow: some View {
        let locationLine = AddressFormatting.detailLocationLine(
            neighborhood: spot.neighborhood.isEmpty ? nil : spot.neighborhood,
            address: spot.addressLine
        )
        return HStack(spacing: 8) {
            Image(systemName: "mappin")
                .font(.system(size: 12))
                .foregroundColor(.portalMutedForeground)
            Text(locationLine.isEmpty ? spot.displayCity : locationLine)
                .font(.system(size: 12))
                .foregroundColor(.portalMutedForeground)
                .lineLimit(2)
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
            categoryLabel: "Food",
            ownerHandle: "mia_eats",
            ownerInitial: "M",
            saveCount: 1200,
            description: "Hand-rolled pasta and wood-fired everything. The whipped ricotta alone is worth the trip.",
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
