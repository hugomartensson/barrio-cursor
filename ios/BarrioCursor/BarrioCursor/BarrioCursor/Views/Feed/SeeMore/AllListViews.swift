import SwiftUI

// MARK: - AllSpotsView

struct AllSpotsView: View {
    let spots: [Spot]
    let savedIds: Set<String>
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var discoverFilters: DiscoverFilters

    @State private var showCategoryDropdown = false

    private let columns = [GridItem(.flexible(), spacing: .portalCardGap), GridItem(.flexible(), spacing: .portalCardGap)]

    private var filtered: [Spot] {
        var result = spots
        if !discoverFilters.categories.isEmpty {
            result = result.filter { spot in
                discoverFilters.categories.contains { cat in
                    spot.category.rawValue.lowercased() == cat.rawValue.lowercased()
                }
            }
        }
        if let n = discoverFilters.searchNeighborhood, !n.isEmpty {
            result = result.filter { $0.neighborhood.localizedCaseInsensitiveContains(n) }
        }
        return result
    }

    private var cardWidth: CGFloat {
        (PortalScreenBounds.width - CGFloat.portalPagePadding * 2 - CGFloat.portalCardGap) / 2
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Filter strip
                seeMoreFilterStrip(showTime: false, showCategoryDropdown: $showCategoryDropdown)
                    .padding(.horizontal, .portalPagePadding)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                if showCategoryDropdown {
                    categoryDropdown
                        .padding(.horizontal, .portalPagePadding)
                        .padding(.bottom, 4)
                }

                if filtered.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "mappin.slash")
                            .font(.system(size: 40, weight: .light))
                            .foregroundColor(.portalMutedForeground)
                        Text("No spots match the filter")
                            .foregroundColor(.portalMutedForeground)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    LazyVGrid(columns: columns, spacing: .portalCardGap) {
                        ForEach(filtered.map { PortalSpotItem(from: $0) }) { spot in
                            let saved = savedIds.contains(spot.id)
                            NavigationLink(value: spot) {
                                PortalSpotCard(spot: spot, cardWidth: cardWidth, isSaved: saved, onSaveToggle: nil)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, .portalPagePadding)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color.portalBackground)
        .navigationTitle("All Spots")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: PortalSpotItem.self) { spot in
            SpotDetailView(spot: spot, isSaved: savedIds.contains(spot.id))
                .environmentObject(authManager)
        }
    }

    private var categoryDropdown: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .portalCardGap) {
                ForEach(DiscoverCategory.allCases, id: \.self) { category in
                    PortalFilterPill(
                        title: category.label,
                        isActive: discoverFilters.categories.contains(category),
                        categoryColor: Color.categoryPillColor(for: category.label)
                    ) {
                        if discoverFilters.categories.contains(category) {
                            discoverFilters.categories.remove(category)
                        } else {
                            discoverFilters.categories.insert(category)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 44)
        .scrollBounceBehavior(.basedOnSize)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.portalCard)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.portalBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - AllEventsView

struct AllEventsView: View {
    let events: [Event]
    let savedIds: Set<String>
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var discoverFilters: DiscoverFilters

    @State private var showTimeDialog = false
    @State private var showCategoryDropdown = false

    private var filtered: [Event] {
        var result = events

        // Time filter (client-side)
        if let intent = discoverFilters.time {
            let now = Date()
            let calendar = Calendar.current
            switch intent {
            case .tonight:
                let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
                result = result.filter { $0.startTime >= now && $0.startTime < end }
            case .tomorrow:
                let todayStart = calendar.startOfDay(for: now)
                let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart)!
                let tomorrowEnd = calendar.date(byAdding: .day, value: 1, to: tomorrowStart)!
                result = result.filter { $0.startTime >= tomorrowStart && $0.startTime < tomorrowEnd }
            case .thisWeekend:
                let weekday = calendar.component(.weekday, from: now)
                let daysToSaturday = (7 - weekday + 7) % 7
                let saturday = calendar.date(byAdding: .day, value: daysToSaturday, to: calendar.startOfDay(for: now))!
                let monday = calendar.date(byAdding: .day, value: 2, to: saturday)!
                result = result.filter { $0.startTime >= saturday && $0.startTime < monday }
            case .pickDate:
                if let range = discoverFilters.customDateRange {
                    let endOfLastDay = calendar.date(byAdding: .day, value: 1, to: range.end)!
                    result = result.filter { $0.startTime >= range.start && $0.startTime < endOfLastDay }
                }
            }
        }

        // Category filter
        if !discoverFilters.categories.isEmpty {
            result = result.filter { event in
                discoverFilters.categories.contains { cat in
                    event.category.rawValue.lowercased() == cat.rawValue.lowercased()
                }
            }
        }

        // Neighborhood filter
        if let n = discoverFilters.searchNeighborhood, !n.isEmpty {
            result = result.filter { ($0.neighborhood ?? "").localizedCaseInsensitiveContains(n) }
        }

        return result
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Filter strip
                seeMoreFilterStrip(showTime: true, showCategoryDropdown: $showCategoryDropdown)
                    .padding(.horizontal, .portalPagePadding)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                if showCategoryDropdown {
                    categoryDropdown
                        .padding(.horizontal, .portalPagePadding)
                        .padding(.bottom, 4)
                }

                LazyVStack(spacing: .portalCardGap) {
                    if filtered.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "calendar.badge.exclamationmark")
                                .font(.system(size: 40, weight: .light))
                                .foregroundColor(.portalMutedForeground)
                            Text("No events match the filter")
                                .foregroundColor(.portalMutedForeground)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        ForEach(filtered) { event in
                            NavigationLink(value: event) {
                                PortalEventCard(
                                    event: event,
                                    isSaved: savedIds.contains(event.id),
                                    onSaveToggle: nil,
                                    reserveTrailingForExternalSave: 0
                                )
                                .environmentObject(authManager)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, .portalPagePadding)
                .padding(.vertical, 12)
            }
        }
        .background(Color.portalBackground)
        .navigationTitle("All Events")
        .navigationBarTitleDisplayMode(.large)
        .confirmationDialog("Filter by time", isPresented: $showTimeDialog, titleVisibility: .visible) {
            ForEach(DiscoverTimeIntent.allCases, id: \.self) { intent in
                Button(intent.label) { discoverFilters.time = intent }
            }
            if discoverFilters.time != nil {
                Button("Clear time filter", role: .destructive) { discoverFilters.time = nil }
            }
            Button("Cancel", role: .cancel) {}
        }
        .navigationDestination(for: Event.self) { event in
            EventDetailView(event: event, isSaved: savedIds.contains(event.id))
                .environmentObject(authManager)
        }
    }

    private var categoryDropdown: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .portalCardGap) {
                ForEach(DiscoverCategory.allCases, id: \.self) { category in
                    PortalFilterPill(
                        title: category.label,
                        isActive: discoverFilters.categories.contains(category),
                        categoryColor: Color.categoryPillColor(for: category.label)
                    ) {
                        if discoverFilters.categories.contains(category) {
                            discoverFilters.categories.remove(category)
                        } else {
                            discoverFilters.categories.insert(category)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 44)
        .scrollBounceBehavior(.basedOnSize)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.portalCard)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.portalBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - AllCollectionsView

struct AllCollectionsView: View {
    let collections: [CollectionData]
    let savedIds: Set<String>
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var discoverFilters: DiscoverFilters

    @State private var showCategoryDropdown = false

    private let columns = [GridItem(.flexible(), spacing: .portalCardGap), GridItem(.flexible(), spacing: .portalCardGap)]

    private var cardWidth: CGFloat {
        (PortalScreenBounds.width - CGFloat.portalPagePadding * 2 - CGFloat.portalCardGap) / 2
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                // Filter strip
                seeMoreFilterStrip(showTime: false, showCategoryDropdown: $showCategoryDropdown)
                    .padding(.horizontal, .portalPagePadding)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                if showCategoryDropdown {
                    categoryDropdown
                        .padding(.horizontal, .portalPagePadding)
                        .padding(.bottom, 4)
                }

                LazyVGrid(columns: columns, spacing: .portalCardGap) {
                    ForEach(collections.map { PortalCollectionItem(from: $0) }) { item in
                        let saved = savedIds.contains(item.id)
                        NavigationLink(value: ProfileCollectionRoute(id: item.id, name: item.title)) {
                            PortalCollectionCard(
                                collection: item,
                                isSaved: saved,
                                onSaveToggle: nil,
                                cardWidth: cardWidth,
                                isExpanded: false
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, .portalPagePadding)
                .padding(.vertical, 12)
            }
        }
        .background(Color.portalBackground)
        .navigationTitle("All Collections")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: ProfileCollectionRoute.self) { route in
            CollectionDetailView(collectionId: route.id, name: route.name)
                .environmentObject(authManager)
        }
    }

    private var categoryDropdown: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .portalCardGap) {
                ForEach(DiscoverCategory.allCases, id: \.self) { category in
                    PortalFilterPill(
                        title: category.label,
                        isActive: discoverFilters.categories.contains(category),
                        categoryColor: Color.categoryPillColor(for: category.label)
                    ) {
                        if discoverFilters.categories.contains(category) {
                            discoverFilters.categories.remove(category)
                        } else {
                            discoverFilters.categories.insert(category)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: 44)
        .scrollBounceBehavior(.basedOnSize)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.portalCard)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.portalBorder, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Shared filter strip for See More views

/// Compact filter row used in AllEventsView, AllSpotsView, AllCollectionsView.
/// Shows location pill (display only — reflects current discoverFilters state),
/// optional time pill (events only), and categories pill with inline dropdown.
private func seeMoreFilterStrip(showTime: Bool, showCategoryDropdown: Binding<Bool>) -> some View {
    _SeeMoreFilterStrip(showTime: showTime, showCategoryDropdown: showCategoryDropdown)
}

private struct _SeeMoreFilterStrip: View {
    let showTime: Bool
    @Binding var showCategoryDropdown: Bool
    @EnvironmentObject var discoverFilters: DiscoverFilters
    @EnvironmentObject var locationManager: LocationManager
    @State private var showTimeDialog = false
    @State private var showLocationDropdown = false

    private var locationLabel: String {
        if let n = discoverFilters.searchNeighborhood, !n.isEmpty { return n }
        return discoverFilters.searchLocation != nil ? "Searched area" : "Current location"
    }

    private var hasActiveFilter: Bool {
        discoverFilters.time != nil || !discoverFilters.categories.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            filterRow
            if showLocationDropdown {
                LocationSearchField(
                    biasCenter: locationManager.coordinate,
                    onUseCurrentLocation: {
                        discoverFilters.searchLocation = nil
                        discoverFilters.searchNeighborhood = nil
                        showLocationDropdown = false
                    },
                    onSelect: { resolved in
                        discoverFilters.searchLocation = resolved.coordinate
                        discoverFilters.searchNeighborhood = resolved.neighborhood
                        showLocationDropdown = false
                    }
                )
                .padding(12)
                .background(Color.portalCard)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.portalBorder, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private var filterRow: some View {
        HStack(spacing: 4) {
            // Location — tappable, opens live LocationSearchField dropdown
            Button {
                showCategoryDropdown = false
                showLocationDropdown.toggle()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.system(size: 11))
                        .foregroundColor(.portalPrimary)
                    Text(locationLabel)
                        .font(.portalMetadata)
                        .foregroundColor(.portalMutedForeground)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Image(systemName: showLocationDropdown ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.portalMutedForeground)
                }
                .padding(.horizontal, 10)
                .frame(height: 36)
                .frame(maxWidth: .infinity)
                .background(Color.portalCard)
                .overlay(RoundedRectangle(cornerRadius: .portalCategoryPillRadius).stroke(Color.portalBorder, lineWidth: 1))
                .clipShape(RoundedRectangle(cornerRadius: .portalCategoryPillRadius))
            }
            .buttonStyle(.plain)
            .layoutPriority(0)

            // Time pill (events only)
            if showTime {
                Button { showTimeDialog = true } label: {
                    HStack(spacing: 4) {
                        if let time = discoverFilters.time {
                            Text(time.label)
                                .font(.portalLabelSemibold)
                                .foregroundColor(.portalPrimaryForeground)
                                .lineLimit(1)
                        } else {
                            Text("Time")
                                .font(.portalLabelSemibold)
                                .foregroundColor(.portalForeground)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.portalMutedForeground)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 36)
                    .background(discoverFilters.time != nil ? AnyShapeStyle(LinearGradient(colors: [Color(hex: "#2F7168"), Color(hex: "#3D8A80")], startPoint: .topLeading, endPoint: .bottomTrailing)) : AnyShapeStyle(Color.portalCard))
                    .overlay(RoundedRectangle(cornerRadius: .portalCategoryPillRadius).stroke(Color.portalBorder, lineWidth: discoverFilters.time != nil ? 0 : 1))
                    .clipShape(RoundedRectangle(cornerRadius: .portalCategoryPillRadius))
                }
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)
                .confirmationDialog("Filter by time", isPresented: $showTimeDialog, titleVisibility: .visible) {
                    ForEach(DiscoverTimeIntent.allCases, id: \.self) { intent in
                        Button(intent.label) { discoverFilters.time = intent }
                    }
                    if discoverFilters.time != nil {
                        Button("Clear", role: .destructive) { discoverFilters.time = nil }
                    }
                    Button("Cancel", role: .cancel) {}
                }
            }

            // Categories pill
            Button {
                showCategoryDropdown.toggle()
            } label: {
                HStack(spacing: 4) {
                    if discoverFilters.categories.isEmpty {
                        Text("Categories")
                            .font(.portalLabelSemibold)
                            .foregroundColor(.portalForeground)
                    } else if discoverFilters.categories.count == 1 {
                        Text(discoverFilters.categories.first!.label)
                            .font(.portalLabelSemibold)
                            .foregroundColor(.white)
                    } else {
                        Text("\(discoverFilters.categories.count)")
                            .font(.portalLabelSemibold)
                            .foregroundColor(.white)
                    }
                    Image(systemName: showCategoryDropdown ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(!discoverFilters.categories.isEmpty ? .white.opacity(0.9) : .portalMutedForeground)
                }
                .padding(.horizontal, 10)
                .frame(height: 36)
                .background(!discoverFilters.categories.isEmpty
                    ? AnyShapeStyle(Color.categoryPillColor(for: discoverFilters.categories.first!.label))
                    : AnyShapeStyle(Color.portalCard))
                .overlay(RoundedRectangle(cornerRadius: .portalCategoryPillRadius).stroke(Color.portalBorder, lineWidth: !discoverFilters.categories.isEmpty ? 0 : 1))
                .clipShape(RoundedRectangle(cornerRadius: .portalCategoryPillRadius))
            }
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)

            // Clear button (time or category active)
            if hasActiveFilter {
                Button {
                    discoverFilters.time = nil
                    discoverFilters.categories = []
                    showCategoryDropdown = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.portalMutedForeground.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Route sentinel for navigation

struct DiscoverListRoute: Hashable {
    enum Kind: Hashable { case spots, events, collections, users }
    let kind: Kind
    static var spots: DiscoverListRoute { .init(kind: .spots) }
    static var events: DiscoverListRoute { .init(kind: .events) }
    static var collections: DiscoverListRoute { .init(kind: .collections) }
    static var users: DiscoverListRoute { .init(kind: .users) }
}
