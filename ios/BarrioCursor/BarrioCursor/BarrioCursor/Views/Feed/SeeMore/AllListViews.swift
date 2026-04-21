import SwiftUI

// MARK: - AllSpotsView

struct AllSpotsView: View {
    let spots: [Spot]
    let savedIds: Set<String>
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var discoverFilters: DiscoverFilters

    private let columns = [GridItem(.flexible(), spacing: .portalCardGap), GridItem(.flexible(), spacing: .portalCardGap)]

    private var filtered: [Spot] {
        guard !discoverFilters.categories.isEmpty else { return spots }
        return spots.filter { spot in
            discoverFilters.categories.contains { cat in
                spot.category.rawValue.lowercased() == cat.rawValue.lowercased()
            }
        }
    }

    private var cardWidth: CGFloat {
        (PortalScreenBounds.width - CGFloat.portalPagePadding * 2 - CGFloat.portalCardGap) / 2
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
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
        .background(Color.portalBackground)
        .navigationTitle("All Spots")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: PortalSpotItem.self) { spot in
            SpotDetailView(spot: spot, isSaved: savedIds.contains(spot.id))
                .environmentObject(authManager)
        }
    }
}

// MARK: - AllEventsView

struct AllEventsView: View {
    let events: [Event]
    let savedIds: Set<String>
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var discoverFilters: DiscoverFilters

    private var filtered: [Event] {
        guard !discoverFilters.categories.isEmpty else { return events }
        return events.filter { event in
            discoverFilters.categories.contains { cat in
                event.category.rawValue.lowercased() == cat.rawValue.lowercased()
            }
        }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
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
        .background(Color.portalBackground)
        .navigationTitle("All Events")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: Event.self) { event in
            EventDetailView(event: event, isSaved: savedIds.contains(event.id))
                .environmentObject(authManager)
        }
    }
}

// MARK: - AllCollectionsView

struct AllCollectionsView: View {
    let collections: [CollectionData]
    let savedIds: Set<String>
    @EnvironmentObject var authManager: AuthManager

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: .portalCardGap) {
                ForEach(collections.map { PortalCollectionItem(from: $0) }) { item in
                    let saved = savedIds.contains(item.id)
                    NavigationLink(value: ProfileCollectionRoute(id: item.id, name: item.title)) {
                        PortalCollectionCard(
                            collection: item,
                            isSaved: saved,
                            onSaveToggle: nil,
                            cardWidth: PortalScreenBounds.width - CGFloat.portalPagePadding * 2,
                            isExpanded: true
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, .portalPagePadding)
            .padding(.vertical, 12)
        }
        .background(Color.portalBackground)
        .navigationTitle("All Collections")
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(for: ProfileCollectionRoute.self) { route in
            CollectionDetailView(collectionId: route.id, name: route.name)
                .environmentObject(authManager)
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
