import SwiftUI
import CoreLocation
import MapKit
import Combine
import UIKit

struct DiscoverView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var discoverFilters: DiscoverFilters
    @StateObject private var viewModel = FeedViewModel()
    @State private var searchRadiusKm: Double = 5.0 // Location search radius in km
    @State private var sortOption: SortOption = .soonest // PRD Section 5.3: Sort option
    @State private var eventToShare: Event? = nil // Phase 3.5: Swipe "Share"
    // Removed Phase 3.6 pinch-to-zoom overview per PRD simplification
    @State private var userIdForProfile: String? = nil // Organizer tap from EventCard → UserProfileView
    @State private var showUserProfileSheet = false
    @State private var locationLabel: String = "Current location"
    @State private var showTimeFilterDropdown = false
    @State private var showCategoryFilterDropdown = false
    @State private var showLocationDropdown = false
    @State private var discoverNavPath = NavigationPath()
    @State private var showDateRangePicker = false

    /// Extracted to avoid "compiler is unable to type-check this expression in reasonable time".
    private var discoverRootContent: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                portalDiscoverHeader
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .clipped()
                    .contentShape(Rectangle())
            }
            .padding(.horizontal, .portalPagePadding)
            .padding(.top, 6)
            .padding(.bottom, 4)
            .background(Color.portalBackground)
            .frame(maxWidth: .infinity)
            .clipped()

            ZStack(alignment: .top) {
                mainContent
                if showTimeFilterDropdown || showCategoryFilterDropdown || showLocationDropdown {
                    Color.clear
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showTimeFilterDropdown = false
                            showCategoryFilterDropdown = false
                            showLocationDropdown = false
                        }
                        .allowsHitTesting(false)
                }
            }
        }
        .background(Color.portalBackground.ignoresSafeArea())
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    /// NavigationStack + destinations + sheets (no AnyView — keeps `navigationDestination` reliable).
    @ViewBuilder
    private var discoverWithSheets: some View {
        NavigationStack(path: $discoverNavPath) {
            discoverRootContent
                .navigationDestination(for: Event.self) { event in
                    EventDetailView(event: event, isSaved: viewModel.savedEventIds.contains(event.id))
                        .environmentObject(authManager)
                }
                .navigationDestination(for: PortalSpotItem.self) { spot in
                    SpotDetailView(
                        spot: spot,
                        isSaved: viewModel.savedSpotIds.contains(spot.id),
                        saveCount: max(spot.saveCount, viewModel.savedSpotIds.contains(spot.id) ? 1 : 0),
                        onSaveToggle: {
                            guard let token = authManager.token else { return }
                            Task { await viewModel.toggleSaveSpot(spotId: spot.id, token: token) }
                        }
                    )
                    .environmentObject(authManager)
                }
                .navigationDestination(for: CollectionRoute.self) { route in
                    CollectionDetailView(collectionId: route.id, name: route.name)
                        .environmentObject(authManager)
                }
                .navigationDestination(for: DiscoverListRoute.self) { route in
                    discoverListDestination(route)
                }
        }
        .sheet(item: $eventToShare) { event in
            ShareSheet(
                activityItems: [
                    "\(event.title)\n\(event.startTime.formatted(date: .abbreviated, time: .shortened)) at \(event.address)\nhttps://barrio.app/events/\(event.id)"
                ],
                onDismiss: { eventToShare = nil }
            )
        }
        .sheet(isPresented: $showUserProfileSheet, onDismiss: { userIdForProfile = nil }) {
            if let userId = userIdForProfile {
                NavigationStack {
                    UserProfileView(userId: userId)
                        .environmentObject(authManager)
                }
            }
        }
        .sheet(isPresented: $showDateRangePicker) {
            DateRangePickerSheet(
                discoverFilters: discoverFilters,
                onDismiss: { showDateRangePicker = false }
            )
        }
        .onChange(of: discoverFilters.time) { _, newValue in
            if newValue == .pickDate {
                showDateRangePicker = true
            }
        }
    }

    private func syncDetailPresented() {
        discoverFilters.isDetailPresented = discoverNavPath.count > 0
    }

    private var discoverWithDetailSync: some View {
        discoverWithSheets
            .onChange(of: discoverNavPath.count) { _, _ in syncDetailPresented() }
    }

    private var discoverWithLifecycleA: some View {
        discoverWithDetailSync
            .onAppear {
                locationManager.requestLocationIfNeeded()
                Task { await reloadEvents() }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EventCreated"))) { _ in
                Task { await reloadEvents() }
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowUserProfile"))) { notification in
                if let userId = notification.object as? String {
                    userIdForProfile = userId
                    showUserProfileSheet = true
                }
            }
    }

    /// Second half of lifecycle modifiers.
    private var discoverWithLifecycle: some View {
        discoverWithLifecycleA
            .onChange(of: discoverFilters.followingOnly) { _, _ in Task { await reloadEvents() } }
            .onChange(of: discoverFilters.searchLocation) { _, _ in
                Task { await reloadEvents() }
                Task { await updateLocationLabel() }
            }
            .onChange(of: locationManager.location) { _, _ in
                if discoverFilters.searchLocation == nil { Task { await updateLocationLabel() } }
            }
            .onChange(of: locationManager.authorizationStatus) { _, newStatus in
                if newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways {
                    Task { await reloadEvents() }
                    Task { await updateLocationLabel() }
                }
            }
            .onAppear { Task { await updateLocationLabel() } }
    }

    var body: some View {
        discoverWithLifecycle
    }

    private func updateLocationLabel() async {
        if ProcessInfo.processInfo.arguments.contains("--uitesting") { return }
        let coordinate = discoverFilters.searchLocation ?? locationManager.coordinate
        let label = await locationManager.reverseGeocodeDisplayName(coordinate)
        locationLabel = label
    }


    // portal· Discover header: wordmark, then filter row (Location, Time, Categories)
    private var portalDiscoverHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            PortalWordmark()
                .frame(maxWidth: .infinity, alignment: .leading)

            // Filter row: pills next to each other from the left; Time & Categories keep size, Location gets remainder and truncates "..." so row never spills.
            HStack(alignment: .center, spacing: 4) {
                // Location pill — gets remaining width after Time/Categories (layoutPriority 0), truncates with "..."
                Button {
                    showTimeFilterDropdown = false
                    showCategoryFilterDropdown = false
                    showLocationDropdown.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 12))
                            .foregroundColor(.portalPrimary)
                        Text(locationLabel)
                            .font(.portalMetadata)
                            .foregroundColor(.portalMutedForeground)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(.portalMutedForeground)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .background(Color.portalCard)
                    .overlay(
                        RoundedRectangle(cornerRadius: .portalCategoryPillRadius)
                            .stroke(Color.portalBorder, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: .portalCategoryPillRadius))
                }
                .contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Location filter")
                .buttonStyle(.plain)
                .frame(minWidth: 0, maxWidth: .infinity)
                .layoutPriority(0)

                // Time pill — fixed size so it sits right next to Location
                Button {
                    showLocationDropdown = false
                    showCategoryFilterDropdown = false
                    showTimeFilterDropdown.toggle()
                } label: {
                    HStack(spacing: 4) {
                        if discoverFilters.time == nil {
                            Text("Time")
                                .font(.portalLabelSemibold)
                                .foregroundColor(.portalForeground)
                            Image(systemName: "chevron.down")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.portalMutedForeground)
                        } else {
                            Text(discoverFilters.time!.label)
                                .font(.portalLabelSemibold)
                                .foregroundColor(.portalPrimaryForeground)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 44)
                    .background(timePillBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: .portalCategoryPillRadius)
                            .stroke(Color.portalBorder, lineWidth: discoverFilters.time != nil ? 0 : 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: .portalCategoryPillRadius))
                }
                .contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Time filter")
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)

                // Categories pill — fixed size, next to Time
                Button {
                    showLocationDropdown = false
                    showTimeFilterDropdown = false
                    showCategoryFilterDropdown.toggle()
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
                                .lineLimit(1)
                                .truncationMode(.tail)
                        } else {
                            Text("\(discoverFilters.categories.count)")
                                .font(.portalLabelSemibold)
                                .foregroundColor(.white)
                        }
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(hasActiveCategoryFilter ? .white.opacity(0.9) : .portalMutedForeground)
                    }
                    .padding(.horizontal, 10)
                    .frame(height: 44)
                    .background(categoryPillBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: .portalCategoryPillRadius)
                            .stroke(Color.portalBorder, lineWidth: hasActiveCategoryFilter ? 0 : 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: .portalCategoryPillRadius))
                }
                .contentShape(Rectangle())
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Categories filter")
                .buttonStyle(.plain)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(1)

                if hasActiveFilter {
                    Button {
                        discoverFilters.time = nil
                        discoverFilters.categories = []
                        showTimeFilterDropdown = false
                        showCategoryFilterDropdown = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(Color.portalMutedForeground.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity)
            .clipped()

            // Time dropdown: box with pill-style options
            if showTimeFilterDropdown {
                timeFilterDropdownContent
            }

            // Category dropdown: box with pill-style options (selected highlighted)
            if showCategoryFilterDropdown {
                categoryFilterDropdownContent
            }

            // Location dropdown: Use Current Location + search
            if showLocationDropdown {
                locationDropdownContent
            }
        }
    }

    private var hasActiveFilter: Bool {
        discoverFilters.time != nil || !discoverFilters.categories.isEmpty
    }

    private var hasActiveCategoryFilter: Bool {
        !discoverFilters.categories.isEmpty
    }

    @ViewBuilder
    private var timePillBackground: some View {
        if discoverFilters.time != nil {
            LinearGradient(
                colors: [Color(hex: "#2F7168"), Color(hex: "#3D8A80")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            Color.portalCard
        }
    }

    @ViewBuilder
    private var categoryPillBackground: some View {
            if hasActiveCategoryFilter {
            Color.categoryPillColor(for: discoverFilters.categories.first!.label)
        } else {
            Color.portalCard
        }
    }

    private var timeFilterDropdownContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .portalCardGap) {
                ForEach(DiscoverTimeIntent.allCases, id: \.self) { intent in
                    PortalFilterPill(
                        title: intent.label,
                        icon: icon(for: intent),
                        isActive: discoverFilters.time == intent
                    ) {
                        if discoverFilters.time == intent {
                            discoverFilters.time = nil
                        } else {
                            discoverFilters.time = intent
                        }
                        showTimeFilterDropdown = false
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
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.portalBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top, 2)
    }

    private var categoryFilterDropdownContent: some View {
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
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.portalBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top, 2)
    }

    private var locationDropdownContent: some View {
        LocationSearchField(
            biasCenter: locationManager.coordinate,
            onUseCurrentLocation: {
                discoverFilters.searchLocation = nil
                showLocationDropdown = false
                Task { await updateLocationLabel() }
            },
            onSelect: { resolved in
                discoverFilters.searchLocation = resolved.coordinate
                showLocationDropdown = false
                Task { await updateLocationLabel() }
            }
        )
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.portalCard)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.portalBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.top, 2)
    }

    /// True when there are no events, spots, users, or collections to show (show empty state).
    private var hasNoFeedContent: Bool {
        filteredEvents.isEmpty
            && filteredSpots.isEmpty
            && viewModel.suggestedUsers.isEmpty
            && viewModel.recommendedCollections.isEmpty
    }

    // Legacy filterRow removed; PRD filters are expressed via DiscoverFilters time + category pills.
    
    @ViewBuilder
    private var mainContent: some View {
        if viewModel.isLoading && viewModel.events.isEmpty {
            LoadingView(message: "Loading...")
        } else if let errorMessage = viewModel.errorMessage {
                ErrorView(
                error: NSError(domain: "DiscoverView", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMessage]),
                retry: {
                    Task {
                        await reloadEvents()
                    }
                }
            )
        } else if hasNoFeedContent && !viewModel.isLoading {
            EmptyStateView()
        } else {
            eventsList
        }
    }
    
    private var feedContentWidth: CGFloat {
        PortalScreenBounds.width - CGFloat.portalPagePadding * 2
    }

    @ViewBuilder
    private var eventsList: some View {
        List {
            // EVENTS — top 3 cards; "See more" pushes AllEventsView
            if !filteredEvents.isEmpty {
                Section(header: sectionHeaderNav(title: "EVENTS", count: filteredEvents.count, route: .events)) {
                    ForEach(topEvents, id: \.id) { event in
                        let eventSaved = viewModel.savedEventIds.contains(event.id)
                        ZStack(alignment: .topTrailing) {
                            Button {
                                discoverNavPath.append(event)
                            } label: {
                                PortalEventCard(
                                    event: event,
                                    isSaved: eventSaved,
                                    onSaveToggle: nil,
                                    reserveTrailingForExternalSave: Self.discoverEventSaveTrailingReserve
                                )
                                .environmentObject(authManager)
                            }
                            .buttonStyle(.plain)
                            .contentShape(Rectangle())
                            .zIndex(0)
                            PortalSaveButton(isSaved: eventSaved, count: event.saveCount, surface: .light) {
                                guard let token = authManager.token else { return }
                                Task { await viewModel.toggleSaveEvent(eventId: event.id, token: token) }
                            }
                            .padding(8)
                            .zIndex(1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .listRowInsets(EdgeInsets(top: 6, leading: .portalPagePadding, bottom: 6, trailing: .portalPagePadding))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.portalBackground)
                    }
                }
                .listSectionSeparator(.hidden)
            }

            // SPOTS — horizontal scroll; "See more" pushes AllSpotsView
            if !filteredSpots.isEmpty {
                Section(header: sectionHeaderNav(title: "SPOTS", count: filteredSpots.count, route: .spots)) {
                    spotHorizontalRow
                }
                .listSectionSeparator(.hidden)
            }

            // USERS — horizontal scroll; "See more" pushes AllUsersView
            if !viewModel.suggestedUsers.isEmpty {
                Section(header: sectionHeaderNav(title: "USERS", count: viewModel.suggestedUsers.count, route: .users)) {
                    usersHorizontalRow
                }
                .listSectionSeparator(.hidden)
            }

            // COLLECTIONS — horizontal scroll; "See more" pushes AllCollectionsView
            if !viewModel.recommendedCollections.isEmpty {
                Section(header: sectionHeaderNav(title: "COLLECTIONS", count: viewModel.recommendedCollections.count, route: .collections)) {
                    collectionsHorizontalRow
                }
                .listSectionSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.portalBackground.ignoresSafeArea(edges: .bottom))
        .ignoresSafeArea(edges: .bottom)
        .refreshable {
            // Run reload in an unstructured Task so it isn't cancelled when the refresh gesture ends (-999)
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                Task { @MainActor in
                    await reloadEvents()
                    continuation.resume()
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .padding(.bottom, 12)
    }

    /// Room for the top-trailing save control so the title wraps above the white card area, not under the button.
    private static let discoverEventSaveTrailingReserve: CGFloat = 52

    /// Sticky section header with a "See more (N)" button that pushes the list view.
    private func sectionHeaderNav(title: String, count: Int, route: DiscoverListRoute) -> some View {
        HStack {
            Text(title)
                .font(.portalSectionTitle)
                .tracking(1.2)
                .foregroundColor(.portalMutedForeground)
            Spacer(minLength: 0)
            Button {
                discoverNavPath.append(route)
            } label: {
                HStack(spacing: 4) {
                    Text("See more (\(count))")
                        .font(.portalMetadata)
                    Image(systemName: "chevron.right")
                        .font(.portalMinText)
                }
                .foregroundColor(.portalMutedForeground)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, .portalPagePadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.portalBackground)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private func discoverListDestination(_ route: DiscoverListRoute) -> some View {
        switch route.kind {
        case .events:
            AllEventsView(events: filteredEvents, savedIds: viewModel.savedEventIds)
                .environmentObject(authManager)
                .environmentObject(discoverFilters)
        case .spots:
            AllSpotsView(spots: filteredSpots, savedIds: viewModel.savedSpotIds)
                .environmentObject(authManager)
                .environmentObject(discoverFilters)
        case .collections:
            AllCollectionsView(collections: viewModel.recommendedCollections, savedIds: viewModel.savedCollectionIds)
                .environmentObject(authManager)
        case .users:
            AllUsersView(users: viewModel.suggestedUsers.map { SuggestedUserItem(from: $0) })
                .environmentObject(authManager)
        }
    }

    @ViewBuilder
    private var spotHorizontalRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .portalCardGap) {
                ForEach(filteredSpots.map { PortalSpotItem(from: $0) }, id: \.id) { spot in
                    let rowSpotSaved = viewModel.savedSpotIds.contains(spot.id)
                    ZStack(alignment: .topTrailing) {
                        Button {
                            discoverNavPath.append(spot)
                        } label: {
                            PortalSpotCard(
                                spot: spot,
                                isSaved: rowSpotSaved,
                                onSaveToggle: nil
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .zIndex(0)
                        PortalSaveButton(
                            isSaved: rowSpotSaved,
                            count: max(spot.saveCount, rowSpotSaved ? 1 : 0),
                            surface: .dark
                        ) {
                            guard let token = authManager.token else { return }
                            Task { await viewModel.toggleSaveSpot(spotId: spot.id, token: token) }
                        }
                        .padding(10)
                        .zIndex(1)
                    }
                    .accessibilityIdentifier("spot_card_\(spot.id)")
                }
            }
            .padding(.horizontal, .portalPagePadding)
            .padding(.vertical, 4)
        }
        .frame(height: 260)
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.portalBackground)
    }

    @ViewBuilder
    private var usersHorizontalRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .portalCardGap) {
                ForEach(viewModel.suggestedUsers.map { SuggestedUserItem(from: $0) }, id: \.id) { user in
                    Button {
                        userIdForProfile = user.id
                        showUserProfileSheet = true
                    } label: {
                        SuggestedUserCard(user: user)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("suggested_user_\(user.id)")
                }
            }
            .padding(.horizontal, .portalPagePadding)
            .padding(.vertical, 4)
        }
        .frame(height: 180)
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.portalBackground)
    }

    @ViewBuilder
    private var collectionsHorizontalRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .portalCardGap) {
                ForEach(viewModel.recommendedCollections.map { PortalCollectionItem(from: $0) }, id: \.id) { collection in
                    let rowCollSaved = viewModel.savedCollectionIds.contains(collection.id)
                    ZStack(alignment: .topTrailing) {
                        Button {
                            discoverNavPath.append(CollectionRoute(id: collection.id, name: collection.title))
                        } label: {
                            PortalCollectionCard(
                                collection: collection,
                                isSaved: rowCollSaved,
                                onSaveToggle: nil
                            )
                        }
                        .buttonStyle(.plain)
                        .contentShape(Rectangle())
                        .zIndex(0)
                        PortalSaveButton(isSaved: rowCollSaved, count: collection.saveCount ?? 0, surface: .dark) {
                            guard let token = authManager.token else { return }
                            Task { await viewModel.toggleSaveCollection(collectionId: collection.id, token: token) }
                        }
                        .padding(10)
                        .zIndex(1)
                    }
                }
            }
            .padding(.horizontal, .portalPagePadding)
            .padding(.vertical, 4)
        }
        .frame(height: 330)
        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.portalBackground)
    }

    private func portalSectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.portalSectionLabel)
            .tracking(1.2)
            .foregroundColor(.portalMutedForeground)
    }

    private var discoveryCardWidth: CGFloat {
        (PortalScreenBounds.width - CGFloat.portalPagePadding * 2 - CGFloat.portalCardGap) / 2
    }

    /// Events sorted by save count (highest first); used for top 3 and "See more" list.
    private var eventsSortedBySaves: [Event] {
        filteredEvents.sorted { $0.saveCount > $1.saveCount }
    }

    /// Top 3 events by save count for the main feed.
    private var topEvents: [Event] {
        Array(eventsSortedBySaves.prefix(3))
    }

    private func portalCategoryShortName(_ category: EventCategory) -> String {
        category.displayName
    }

    // PRD Section 5.2 & 5.3: Apply filters and sorting client-side
    private var filteredEvents: [Event] {
        var events = viewModel.events
        
        // Time intent filter (browse mode when nil)
        if let intent = discoverFilters.time {
            let now = Date()
            let calendar = Calendar.current
            
            switch intent {
            case .tonight:
                let start = now
                let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!
                events = events.filter { $0.startTime >= start && $0.startTime < end }
            case .tomorrow:
                let todayStart = calendar.startOfDay(for: now)
                let tomorrowStart = calendar.date(byAdding: .day, value: 1, to: todayStart)!
                let tomorrowEnd = calendar.date(byAdding: .day, value: 1, to: tomorrowStart)!
                events = events.filter { $0.startTime >= tomorrowStart && $0.startTime < tomorrowEnd }
            case .thisWeekend:
                let weekday = calendar.component(.weekday, from: now)
                let daysToSaturday = (7 - weekday + 7) % 7
                let saturday = calendar.date(byAdding: .day, value: daysToSaturday, to: calendar.startOfDay(for: now))!
                let sunday = calendar.date(byAdding: .day, value: 1, to: saturday)!
                let mondayAfter = calendar.date(byAdding: .day, value: 1, to: sunday)!
                events = events.filter { $0.startTime >= saturday && $0.startTime < mondayAfter }
            case .pickDate:
                if let range = discoverFilters.customDateRange {
                    let endOfLastDay = calendar.date(byAdding: .day, value: 1, to: range.end)!
                    events = events.filter { $0.startTime >= range.start && $0.startTime < endOfLastDay }
                }
                break
            }
        }
        
        // Category filter
        if !discoverFilters.categories.isEmpty {
            events = events.filter { event in
                categoryMatches(event: event)
            }
        }
        
        // PRD Section 5.3: Sort events
        switch sortOption {
        case .soonest:
            // Sort by startTime ASC (default)
            events.sort { $0.startTime < $1.startTime }
        case .distance:
            // Sort by distance ASC (closest first)
            events.sort { event1, event2 in
                let dist1 = event1.distance ?? Int.max
                let dist2 = event2.distance ?? Int.max
                return dist1 < dist2
            }
        case .popular:
            events.sort { $0.saveCount > $1.saveCount }
        }
        
        return events
    }
    
    private func icon(for intent: DiscoverTimeIntent) -> String? {
        switch intent {
        case .tonight: return "moon.stars"
        case .tomorrow: return "sun.max"
        case .thisWeekend: return "calendar"
        case .pickDate: return "calendar.badge.plus"
        }
    }
    
    private func categoryMatches(event: Event) -> Bool {
        for dc in discoverFilters.categories {
            if event.category.rawValue == dc.rawValue {
                return true
            }
        }
        return false
    }

    /// Spots filtered by selected categories. Empty categories = all spots.
    private var filteredSpots: [Spot] {
        var result = viewModel.spots
        if !discoverFilters.categories.isEmpty {
            result = result.filter { discoverFilters.categories.contains($0.category) }
        }
        return result
    }
    
    // Helper to reload events with current filters
    private func reloadEvents() async {
        if ProcessInfo.processInfo.arguments.contains("--uitesting") { return }

        let location = discoverFilters.searchLocation ?? locationManager.coordinate

        guard let token = authManager.token, !token.isEmpty else {
            #if DEBUG
            print("⚠️ DiscoverView: No auth token available")
            #endif
            return
        }

        // Guard against invalid coordinates
        guard location.latitude.isFinite && location.longitude.isFinite else {
            #if DEBUG
            print("⚠️ DiscoverView: Invalid location coordinates")
            #endif
            return
        }

        await viewModel.loadEvents(
            location: location,
            followingOnly: discoverFilters.followingOnly,
            token: token,
            radiusKm: discoverFilters.searchLocation != nil ? searchRadiusKm : nil
        )
        await viewModel.loadSpots(location: location, token: token)
        await viewModel.loadSavedSpotIds(token: token)
        await viewModel.loadSavedEventIds(token: token)
        await viewModel.loadRecommendedCollections(location: location, token: token)
        await viewModel.loadSuggestedUsers(token: token)
    }
}

// MARK: - Event Card

struct EventCard: View {
    @EnvironmentObject var authManager: AuthManager
    let event: Event
    @State private var isSaved = false
    @State private var saveCount: Int
    
    init(event: Event) {
        self.event = event
        _saveCount = State(initialValue: event.saveCount)
    }
    
    @ViewBuilder
    private var cardThumbnail: some View {
        if let first = event.media.first {
            if let url = URL(string: first.url) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .overlay { ProgressView() }
                }
            } else {
                categoryPlaceholder
            }
        } else {
            categoryPlaceholder
        }
    }
    
    private var categoryPlaceholder: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .overlay {
                Image(systemName: event.category.icon)
                    .font(.largeTitle)
                    .foregroundColor(.gray.opacity(0.5))
            }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ZStack(alignment: .topTrailing) {
                cardThumbnail
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                // Save button + count (top-right)
                PortalSaveButton(isSaved: isSaved, count: saveCount, surface: .dark, diameter: 40) {
                    Task { await toggleSave() }
                }
                .padding(8)
                .zIndex(1)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 8) {
                // Category and distance
                HStack {
                    CategoryChip(category: event.category)
                    
                    Spacer()
                    
                    if !event.distanceFormatted.isEmpty {
                        Label(event.distanceFormatted, systemImage: "location")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Title
                Text(event.title)
                    .font(.headline)
                    .lineLimit(2)
                    .accessibilityIdentifier("event_title")
                
                // Host info (tappable)
                Button {
                    NotificationCenter.default.post(
                        name: NSNotification.Name("ShowUserProfile"),
                        object: event.user.id
                    )
                } label: {
                    HStack(spacing: 4) {
                        Text("by")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(event.user.name)
                            .font(.caption.weight(.medium))
                            .foregroundColor(Color(hex: "#e94560"))
                    }
                }
                .buttonStyle(.plain)
                
                // Time
                HStack {
                    Image(systemName: "calendar")
                    Text(event.startTime, style: .date)
                    Text("at")
                    Text(event.startTime, style: .time)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                
                // Stats: save count
                HStack {
                    Label("\(saveCount)", systemImage: "bookmark")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
        .task {
            // Load initial save state (count only)
            await loadSaveState()
        }
    }
    
    private func loadSaveState() async {
        #if DEBUG
        print("📱 EventCard: Loaded save state - count: \(saveCount)")
        #endif
    }
    
    private func toggleSave() async {
        guard let token = authManager.token else {
            #if DEBUG
            print("⚠️ EventCard: Cannot toggle save - no auth token")
            #endif
            return
        }
        
        #if DEBUG
        print("📱 EventCard: Toggling save for event \(event.id)")
        print("📱 EventCard: Current state - isSaved: \(isSaved), count: \(saveCount)")
        #endif
        
        do {
            let result = try await SaveService.shared.toggleEventSave(eventId: event.id, token: token)
            await MainActor.run {
                isSaved = result.isSaved
                saveCount = result.saveCount
            }
            #if DEBUG
            print("✅ EventCard: Save toggled successfully - isSaved: \(result.isSaved), count: \(result.saveCount)")
            #endif
        } catch let error as APIError {
            #if DEBUG
            let errorMsg = "Failed to toggle save: \(error.errorDescription ?? "Unknown error")"
            print("❌ EventCard: APIError - \(errorMsg)")
            print("❌ EventCard: Error details - \(error)")
            if case .serverError(let detail) = error {
                print("❌ EventCard: Server error code: \(detail.code), message: \(detail.message)")
            }
            #endif
        } catch let err {
            #if DEBUG
            let errorMsg = "An unexpected error occurred: \(err.localizedDescription)"
            print("❌ EventCard: Unexpected error - \(errorMsg)")
            print("❌ EventCard: Error type: \(type(of: err))")
            if let nsError = err as NSError? {
                print("❌ EventCard: NSError - code: \(nsError.code), domain: \(nsError.domain)")
            }
            #endif
        }
    }
}

// MARK: - Category Chip

struct CategoryChip: View {
    let category: EventCategory
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: category.icon)
            Text(category.displayName)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(hex: category.color).opacity(0.15))
        .foregroundColor(Color(hex: category.color))
        .cornerRadius(20)
    }
}

// MARK: - Custom date range (Portal design system; shared by Discover and Map)
struct DateRangePickerSheet: View {
    @ObservedObject var discoverFilters: DiscoverFilters
    var onDismiss: () -> Void

    private static var defaultStart: Date { Calendar.current.startOfDay(for: Date()) }
    private static var defaultEnd: Date {
        Calendar.current.date(byAdding: .day, value: 7, to: DateRangePickerSheet.defaultStart) ?? Date()
    }

    @State private var startDate: Date = DateRangePickerSheet.defaultStart
    @State private var endDate: Date = DateRangePickerSheet.defaultEnd

    private var rangeLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "\(fmt.string(from: startDate)) – \(fmt.string(from: endDate))"
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Selected range label
                Text(rangeLabel)
                    .font(.portalLabelSemibold)
                    .foregroundColor(.portalPrimary)
                    .padding(.vertical, 12)

                Divider()

                RangeCalendarView(startDate: $startDate, endDate: $endDate)
                    .padding(.horizontal, .portalPagePadding)
                    .padding(.top, 8)

                Spacer(minLength: 0)
            }
            .background(Color.portalBackground)
            .navigationTitle("Select dates")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.portalBackground, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let cal = Calendar.current
                        let start = cal.startOfDay(for: startDate)
                        let end = cal.startOfDay(for: endDate)
                        discoverFilters.customDateRange = (start, end)
                        onDismiss()
                    }
                    .font(.portalLabelSemibold)
                    .foregroundColor(.portalPrimary)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        discoverFilters.time = nil
                        discoverFilters.customDateRange = nil
                        onDismiss()
                    }
                    .font(.portalMetadata)
                    .foregroundColor(.portalMutedForeground)
                }
            }
        }
        .onAppear {
            if let range = discoverFilters.customDateRange {
                startDate = range.start
                endDate = range.end
            }
        }
    }
}

// RangeCalendarView and RangeCalendarDayCell live in Views/Components/RangeCalendarView.swift

// MARK: - Empty State (Discover feed — simple, on-design)

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: .portalSectionSpacing) {
            Image(systemName: "map")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.portalMutedForeground)
            Text("Nothing here yet")
                .font(.portalDisplay22)
                .foregroundColor(.portalForeground)
            Text("Try a different time or location, or check back later for events and spots nearby.")
                .font(.portalMetadata)
                .foregroundColor(.portalMutedForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Feed View Model

@MainActor
class FeedViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var spots: [Spot] = []
    @Published var recommendedCollections: [CollectionData] = []
    @Published var savedCollectionIds: Set<String> = []
    @Published var savedSpotIds: Set<String> = []
    @Published var savedEventIds: Set<String> = []
    @Published var suggestedUsers: [SuggestedUserData] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let api = APIService.shared
    
    func loadSpots(location: CLLocationCoordinate2D, token: String) async {
        guard !token.isEmpty, location.latitude.isFinite, location.longitude.isFinite else { return }
        do {
            let radiusMeters = 5000.0
            let response = try await api.getSpots(lat: location.latitude, lng: location.longitude, radius: radiusMeters, limit: 20, token: token)
            spots = response.data.map { Spot(from: $0) }
        } catch {
            #if DEBUG
            print("❌ FeedViewModel: Failed to load spots: \(error.localizedDescription)")
            #endif
        }
    }

    func loadSavedSpotIds(token: String) async {
        guard !token.isEmpty else { return }
        do {
            let response = try await api.getSavedSpots(token: token)
            savedSpotIds = Set(response.data.map(\.id))
        } catch {
            #if DEBUG
            print("❌ FeedViewModel: Failed to load saved spot IDs: \(error.localizedDescription)")
            #endif
        }
    }

    func loadSavedEventIds(token: String) async {
        guard !token.isEmpty else { return }
        do {
            let response = try await api.getSavedEvents(token: token)
            savedEventIds = Set(response.data.map(\.event.id))
        } catch {
            #if DEBUG
            print("❌ FeedViewModel: Failed to load saved event IDs: \(error.localizedDescription)")
            #endif
        }
    }

    func toggleSaveEvent(eventId: String, token: String) async {
        do {
            let result = try await SaveService.shared.toggleEventSave(eventId: eventId, token: token)
            if result.isSaved {
                savedEventIds.insert(eventId)
            } else {
                savedEventIds.remove(eventId)
            }
            if let idx = events.firstIndex(where: { $0.id == eventId }) {
                var updated = events[idx]
                updated.saveCount = result.saveCount
                events[idx] = updated
            }
        } catch {
            #if DEBUG
            print("❌ FeedViewModel: Failed to toggle event save: \(error.localizedDescription)")
            #endif
        }
    }

    func toggleSaveSpot(spotId: String, token: String) async {
        do {
            let response = try await api.toggleSaveSpot(spotId: spotId, token: token)
            if response.saved {
                savedSpotIds.insert(spotId)
            } else {
                savedSpotIds.remove(spotId)
            }
            if let idx = spots.firstIndex(where: { $0.id == spotId }) {
                var updated = spots[idx]
                updated.saveCount = response.saveCount
                spots[idx] = updated
            }
        } catch {
            #if DEBUG
            print("❌ FeedViewModel: Failed to toggle spot save: \(error.localizedDescription)")
            #endif
        }
    }
    
    func loadRecommendedCollections(location: CLLocationCoordinate2D, token: String) async {
        guard !token.isEmpty else { return }
        guard location.latitude.isFinite, location.longitude.isFinite else { return }
        do {
            let (rec, mine) = try await (
                api.getRecommendedCollections(lat: location.latitude, lng: location.longitude, token: token),
                api.getCollections(token: token)
            )
            recommendedCollections = rec.data
            savedCollectionIds = Set(mine.data.filter { $0.owned == false }.map { $0.id })
        } catch {
            #if DEBUG
            print("❌ FeedViewModel: Failed to load recommended collections: \(error.localizedDescription)")
            #endif
        }
    }
    
    func toggleSaveCollection(collectionId: String, token: String) async {
        let isSaved = savedCollectionIds.contains(collectionId)
        do {
            if isSaved {
                _ = try await api.unsaveCollection(collectionId: collectionId, token: token)
                savedCollectionIds.remove(collectionId)
                if let idx = recommendedCollections.firstIndex(where: { $0.id == collectionId }) {
                    var updated = recommendedCollections[idx]
                    updated.saveCount = max(0, (updated.saveCount ?? 0) - 1)
                    recommendedCollections[idx] = updated
                }
            } else {
                _ = try await api.saveCollection(collectionId: collectionId, token: token)
                savedCollectionIds.insert(collectionId)
                if let idx = recommendedCollections.firstIndex(where: { $0.id == collectionId }) {
                    var updated = recommendedCollections[idx]
                    updated.saveCount = (updated.saveCount ?? 0) + 1
                    recommendedCollections[idx] = updated
                }
            }
        } catch {
            #if DEBUG
            print("❌ FeedViewModel: Failed to \(isSaved ? "unsave" : "save") collection: \(error.localizedDescription)")
            #endif
        }
    }
    
    func loadSuggestedUsers(city: String? = nil, token: String) async {
        guard !token.isEmpty else { return }
        do {
            let response = try await api.getSuggestedUsers(city: city, limit: 20, token: token)
            suggestedUsers = response.data
        } catch {
            #if DEBUG
            print("❌ FeedViewModel: Failed to load suggested users: \(error.localizedDescription)")
            #endif
        }
    }
    
    func loadEvents(location: CLLocationCoordinate2D, followingOnly: Bool = false, token: String, radiusKm: Double? = nil) async {
        #if DEBUG
        print("📱 FeedViewModel: loadEvents called")
        #endif
        
        guard !token.isEmpty else {
            let errorMsg = "Authentication required"
            #if DEBUG
            print("❌ FeedViewModel: \(errorMsg)")
            #endif
            await MainActor.run {
                errorMessage = errorMsg
                isLoading = false
            }
            return
        }
        
        guard location.latitude.isFinite && location.longitude.isFinite else {
            let errorMsg = "Invalid location"
            #if DEBUG
            print("❌ FeedViewModel: \(errorMsg)")
            #endif
            await MainActor.run {
                errorMessage = errorMsg
                isLoading = false
            }
            return
        }
        
        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }
        
        #if DEBUG
        print("📱 FeedViewModel: Loading events for location (\(location.latitude), \(location.longitude))")
        #endif
        
        do {
            let response = try await api.getNearbyEvents(
                lat: location.latitude,
                lng: location.longitude,
                followingOnly: followingOnly,
                token: token
            )
            await MainActor.run {
                events = response.data
                errorMessage = nil
                isLoading = false
            }
            #if DEBUG
            print("✅ FeedViewModel: Successfully loaded \(response.data.count) events")
            #endif
        } catch let err {
            let errorType = type(of: err)
            let errorDescription = err.localizedDescription
            #if DEBUG
            print("❌ FeedViewModel: Error loading events")
            print("   Error Type: \(errorType)")
            print("   Error Description: \(errorDescription)")
            if let nsError = err as NSError? {
                print("   Error Code: \(nsError.code)")
                print("   Error Domain: \(nsError.domain)")
                print("   User Info: \(nsError.userInfo)")
            }
            if let apiError = err as? APIError {
                print("   API Error: \(apiError)")
            }
            #endif
            await MainActor.run {
                errorMessage = "Failed to load events: \(errorDescription)"
                // Ensure events array is cleared on error to prevent showing stale data
                events = []
                isLoading = false
            }
        }
    }
}

// MARK: - Location Filter Sheet (Phase 3.1 – Feed location filter only)

struct LocationFilterSheetView: View {
    @Binding var searchLocation: CLLocationCoordinate2D?
    @Binding var searchRadiusKm: Double
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var locationManager: LocationManager
    @State private var searchText = ""
    @State private var isSearching = false
    
    let onApply: () -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Location") {
                    HStack {
                        TextField("Search location...", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                        Button("Search") {
                            performLocationSearch()
                        }
                        .disabled(searchText.isEmpty)
                    }
                    
                    if searchLocation != nil {
                        HStack {
                            Text("Using custom location")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("Clear") {
                                searchLocation = nil
                                searchText = ""
                            }
                            .font(.caption)
                        }
                    }
                    
                    Button("Use Current Location") {
                        searchLocation = nil
                        searchText = ""
                        Task {
                            if let addr = try? await locationManager.reverseGeocode(locationManager.coordinate) {
                                searchText = addr
                            }
                        }
                    }
                    .foregroundColor(.blue)
                    
                    if searchLocation != nil {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Search Radius: \(Int(searchRadiusKm)) km")
                                .font(.subheadline)
                            Slider(value: $searchRadiusKm, in: 1...50, step: 1)
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .navigationTitle("Location Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            if let loc = searchLocation {
                Task {
                    let addr = try? await locationManager.reverseGeocode(loc)
                    if let addr = addr { searchText = addr }
                }
            }
        }
    }
    
    private func performLocationSearch() {
        isSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = searchText
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            Task { @MainActor in
                isSearching = false
                if let err = error {
                    #if DEBUG
                    print("❌ LocationFilterSheet search error: \(err.localizedDescription)")
                    #endif
                    return
                }
                if let res = response, let first = res.mapItems.first,
                   let location = first.placemark.location {
                    searchLocation = location.coordinate
                }
            }
        }
    }
}

// MARK: - Filter Sheet View (legacy – time, categories, location; kept for compatibility)

// FeedOverviewView and OverviewEventCard removed per PRD (no overview grid or story-like browsing)

/// Wrapper so we can use spot id as sheet item (avoids wrong-spot opening).
struct SpotIdWrapper: Identifiable, Equatable, Hashable {
    let id: String
}

/// Used for programmatic navigation to collection detail (no disclosure chevron on cards).
struct CollectionRoute: Identifiable, Hashable {
    let id: String
    let name: String
}

// MARK: - Share Sheet (Phase 3.5)

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    var onDismiss: (() -> Void)?
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let vc = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        vc.completionWithItemsHandler = { _, _, _, _ in onDismiss?() }
        return vc
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    DiscoverView()
        .environmentObject(AuthManager())
        .environmentObject(LocationManager())
        .environmentObject(DiscoverFilters())
}

