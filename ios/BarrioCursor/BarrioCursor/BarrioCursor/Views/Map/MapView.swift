import SwiftUI
import MapKit
import Combine

struct MapView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: LocationManager
    @EnvironmentObject var discoverFilters: DiscoverFilters
    @StateObject private var viewModel = MapViewModel()
    @State private var previewEvent: Event?
    @State private var previewSpot: Spot?
    @State private var detailEvent: Event?
    @State private var detailSpot: Spot?
    @State private var initialMapCenter: CLLocationCoordinate2D? // Store initial map center for recenter button
    @State private var mapContentFilter: MapContentFilter = .all // portal· All / Spots / Events
    @State private var savedEventIds: Set<String> = []
    @State private var savedSpotIds: Set<String> = []
    /// When user toggles save on the preview card, we show this count until preview is dismissed.
    @State private var previewEventSaveCount: Int? = nil
    /// When user toggles save on the spot detail sheet, we show this count.
    @State private var detailSpotSaveCount: Int? = nil
    /// When user toggles save on the spot preview card, we show this count until preview is dismissed.
    @State private var previewSpotSaveCount: Int? = nil

    // Discover-mirror filter header state (same as DiscoverView)
    @State private var locationLabel: String = "Current location"
    @State private var showTimeFilterDropdown = false
    @State private var showCategoryFilterDropdown = false
    @State private var showLocationDropdown = false
    @State private var locationSearchText = ""
    @State private var locationSearchResults: [MKMapItem] = []
    @State private var isLocationSearching = false
    @State private var showDateRangePicker = false

    enum MapContentFilter: String, CaseIterable {
        case all, spots, events
    }

    var body: some View {
        ZStack {
            mapView
            filterControlsOverlay
            eventPreviewOverlay
            loadingOverlay
            errorOverlay
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(item: $detailEvent) { event in
            EventDetailView(event: event, isSaved: savedEventIds.contains(event.id))
                .environmentObject(authManager)
        }
        .sheet(item: $detailSpot) { spot in
            SpotDetailView(
                spot: PortalSpotItem(from: spot),
                isSaved: savedSpotIds.contains(spot.id),
                saveCount: detailSpotSaveCount ?? spot.saveCount,
                onSaveToggle: {
                    guard let token = authManager.token else { return }
                    Task {
                        do {
                            let response = try await APIService.shared.toggleSaveSpot(spotId: spot.id, token: token)
                            await MainActor.run {
                                if response.saved { savedSpotIds.insert(spot.id) } else { savedSpotIds.remove(spot.id) }
                                detailSpotSaveCount = response.saveCount
                                if let idx = viewModel.spots.firstIndex(where: { $0.id == spot.id }) {
                                    let old = viewModel.spots[idx]
                                    var newSpots = viewModel.spots
                                    newSpots[idx] = Spot(id: old.id, name: old.name, address: old.address, neighborhood: old.neighborhood, description: old.description, imageUrl: old.imageUrl, location: old.location, category: old.category, owners: old.owners, saveCount: response.saveCount)
                                    viewModel.spots = newSpots
                                }
                            }
                        } catch { }
                    }
                },
                onDismiss: { detailSpot = nil; detailSpotSaveCount = nil }
            )
            .environmentObject(authManager)
        }
        .onChange(of: detailSpot) { _, newSpot in
            if let s = newSpot {
                detailSpotSaveCount = previewSpotSaveCount ?? s.saveCount
            } else {
                detailSpotSaveCount = nil
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
        .task {
            if let searchLoc = discoverFilters.searchLocation {
                viewModel.cameraPosition = .region(MKCoordinateRegion(
                    center: searchLoc,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ))
            }
            await reloadEvents()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("NavigateToEventOnMap"))) { notification in
            if let event = notification.object as? Event {
                // Center map on event and zoom in
                viewModel.cameraPosition = .region(MKCoordinateRegion(
                    center: event.coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
                // Load events around this location
                Task {
                    await viewModel.loadEvents(
                        location: event.coordinate,
                        followingOnly: discoverFilters.followingOnly,
                        token: authManager.token ?? ""
                    )
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("EventCreated"))) { _ in
            #if DEBUG
            print("📢 MapView: Received EventCreated notification, refreshing events...")
            #endif
            Task {
                await reloadEvents()
                #if DEBUG
                print("✅ MapView: Events refreshed, now showing \(viewModel.events.count) events")
                #endif
            }
        }
        .onChange(of: locationManager.location) { _, newLocation in
            if discoverFilters.searchLocation == nil, let location = newLocation {
                if initialMapCenter == nil {
                    initialMapCenter = location.coordinate
                }
                viewModel.debouncedLoadEvents(
                    location: location.coordinate,
                    followingOnly: discoverFilters.followingOnly,
                    token: authManager.token ?? ""
                )
            }
        }
        .onChange(of: viewModel.cameraPosition) { _, newPosition in
            if let region = newPosition.region, let token = authManager.token, !token.isEmpty {
                Task {
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    await viewModel.loadEvents(
                        location: region.center,
                        followingOnly: discoverFilters.followingOnly,
                        token: token
                    )
                    await viewModel.loadSpots(location: region.center, token: token)
                }
            }
        }
        .onChange(of: discoverFilters.followingOnly) { _, _ in
            Task { await reloadEvents() }
        }
        .onChange(of: discoverFilters.searchLocation) { _, newLoc in
            if let loc = newLoc {
                viewModel.cameraPosition = .region(MKCoordinateRegion(
                    center: loc,
                    span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                ))
            }
            Task { await reloadEvents() }
            Task { await updateLocationLabel() }
        }
        .onChange(of: locationManager.location) { _, _ in
            if discoverFilters.searchLocation == nil { Task { await updateLocationLabel() } }
        }
        .onAppear {
            Task { await updateLocationLabel() }
        }
    }
    
    // MARK: - Helpers

    private func updateLocationLabel() async {
        if ProcessInfo.processInfo.arguments.contains("--uitesting") { return }
        let coordinate = discoverFilters.searchLocation ?? locationManager.coordinate
        let label = await locationManager.reverseGeocodeDisplayName(coordinate)
        locationLabel = label
    }

    private func performLocationSearch() {
        let query = locationSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        isLocationSearching = true
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            Task { @MainActor in
                isLocationSearching = false
                if let err = error {
                    #if DEBUG
                    print("❌ MapView location search error: \(err.localizedDescription)")
                    #endif
                    return
                }
                locationSearchResults = response?.mapItems ?? []
            }
        }
    }

    @ViewBuilder
    private var mapView: some View {
        Map(position: $viewModel.cameraPosition) {
            // User location
            UserAnnotation()
            
            // Event pins (when filter is .all or .events)
            ForEach(filteredEvents) { event in
                Annotation("", coordinate: event.coordinate) {
                    EventPin(event: event)
                        .accessibilityIdentifier("event_pin_\(event.id)")
                        .onTapGesture {
                            previewEvent = event
                            previewSpot = nil
                            previewEventSaveCount = nil
                        }
                }
            }
            
            // Spot pins (when filter is .all or .spots)
            ForEach(filteredSpots) { spot in
                Annotation("", coordinate: spot.location) {
                    SpotPin(spot: spot)
                        .onTapGesture {
                            previewSpot = spot
                            previewEvent = nil
                        }
                }
            }
        }
        .accessibilityIdentifier("map")
        .mapStyle(.standard(elevation: .flat)) // Ensure flat (no 3D) view
        .mapControls {
            MapCompass()
        }
        .onMapCameraChange { context in
            // Update search location when map moves (for search following map)
            // This is debounced in onChange(of: cameraPosition)
        }
    }
    
    // MARK: - Discover-mirror filter overlay: floating card so map uses full height; categories hang freely with spacing from actions
    @ViewBuilder
    private var filterControlsOverlay: some View {
        ZStack(alignment: .top) {
            if showTimeFilterDropdown || showCategoryFilterDropdown || showLocationDropdown {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showTimeFilterDropdown = false
                        showCategoryFilterDropdown = false
                        showLocationDropdown = false
                    }
                    .allowsHitTesting(true)
            }

            VStack(alignment: .leading, spacing: 0) {
                // Floating filter row: Location | Time | Categories with clear gap before action buttons
                HStack(alignment: .center, spacing: 12) {
                    mapFilterHeaderRow
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .clipped()

                    Button {
                        let center = initialMapCenter ?? locationManager.coordinate
                        viewModel.cameraPosition = .region(MKCoordinateRegion(
                            center: center,
                            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
                        ))
                        discoverFilters.searchLocation = nil
                        Task { await reloadEvents(); await updateLocationLabel() }
                    } label: {
                        Image(systemName: "location")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.portalForeground)
                            .frame(width: 44, height: 44)
                            .background(Color.portalCard.opacity(0.95))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Recenter")
                }
                .padding(.horizontal, CGFloat.portalPagePadding)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: CGFloat.portalRadius))
                .padding(.horizontal, CGFloat.portalPagePadding)
                .padding(.top, 12)

                if showTimeFilterDropdown {
                    mapTimeFilterDropdownContent
                }
                if showCategoryFilterDropdown {
                    mapCategoryFilterDropdownContent
                }
                if showLocationDropdown {
                    mapLocationDropdownContent
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var mapFilterHeaderRow: some View {
        HStack(alignment: .center, spacing: 4) {
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
                .background(mapTimePillBackground)
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
                        .foregroundColor(mapHasActiveCategoryFilter ? .white.opacity(0.9) : .portalMutedForeground)
                }
                .padding(.horizontal, 10)
                .frame(height: 44)
                .background(mapCategoryPillBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: .portalCategoryPillRadius)
                        .stroke(Color.portalBorder, lineWidth: mapHasActiveCategoryFilter ? 0 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: .portalCategoryPillRadius))
            }
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Categories filter")
            .buttonStyle(.plain)
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)

            if mapHasActiveFilter {
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
    }

    private var mapHasActiveFilter: Bool {
        discoverFilters.time != nil || !discoverFilters.categories.isEmpty
    }

    private var mapHasActiveCategoryFilter: Bool {
        !discoverFilters.categories.isEmpty
    }

    @ViewBuilder
    private var mapTimePillBackground: some View {
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
    private var mapCategoryPillBackground: some View {
        if mapHasActiveCategoryFilter {
            Color.categoryPillColor(for: discoverFilters.categories.first!.label)
        } else {
            Color.portalCard
        }
    }

    private var mapTimeFilterDropdownContent: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .portalCardGap) {
                ForEach(DiscoverTimeIntent.allCases, id: \.self) { intent in
                    PortalFilterPill(
                        title: intent.label,
                        icon: mapIcon(for: intent),
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
        .padding(.horizontal, .portalPagePadding)
        .padding(.top, 2)
    }

    private var mapCategoryFilterDropdownContent: some View {
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
        .padding(.horizontal, .portalPagePadding)
        .padding(.top, 2)
    }

    private var mapLocationDropdownContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                discoverFilters.searchLocation = nil
                showLocationDropdown = false
                Task { await updateLocationLabel() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.portalPrimary)
                    Text("Use Current Location")
                        .font(.portalLabelSemibold)
                        .foregroundColor(.portalForeground)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.portalBackground.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundColor(.portalMutedForeground)
                TextField("Search location...", text: $locationSearchText)
                    .font(.portalMetadata)
                    .submitLabel(.search)
                    .onSubmit { performLocationSearch() }
                if !locationSearchText.isEmpty {
                    Button {
                        locationSearchText = ""
                        locationSearchResults = []
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.portalMutedForeground)
                    }
                }
                Button("Search") { performLocationSearch() }
                    .font(.portalLabelSemibold)
                    .foregroundColor(.portalPrimary)
                    .disabled(locationSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.portalBackground.opacity(0.6))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if isLocationSearching {
                HStack(spacing: 8) {
                    ProgressView().scaleEffect(0.8)
                    Text("Searching...")
                        .font(.portalMetadata)
                        .foregroundColor(.portalMutedForeground)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }

            if !locationSearchResults.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(locationSearchResults.enumerated()), id: \.offset) { _, item in
                            Button {
                                if let coord = item.placemark.location?.coordinate {
                                    discoverFilters.searchLocation = coord
                                    viewModel.cameraPosition = .region(MKCoordinateRegion(
                                        center: coord,
                                        span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
                                    ))
                                    showLocationDropdown = false
                                    locationSearchText = ""
                                    locationSearchResults = []
                                    Task {
                                        await reloadEvents()
                                        await updateLocationLabel()
                                    }
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "mappin.circle")
                                        .font(.system(size: 14))
                                        .foregroundColor(.portalMutedForeground)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(item.name ?? "Unknown")
                                            .font(.portalLabelSemibold)
                                            .foregroundColor(.portalForeground)
                                            .lineLimit(1)
                                        if let locality = item.placemark.locality {
                                            Text(locality)
                                                .font(.portalMetadata)
                                                .foregroundColor(.portalMutedForeground)
                                                .lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color.portalBackground.opacity(0.5))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.portalCard)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.portalBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, .portalPagePadding)
        .padding(.top, 2)
    }

    private func mapIcon(for intent: DiscoverTimeIntent) -> String? {
        switch intent {
        case .tonight: return "moon.stars"
        case .tomorrow: return "sun.max"
        case .thisWeekend: return "calendar"
        case .pickDate: return "calendar.badge.plus"
        }
    }
    
    @ViewBuilder
    private var loadingOverlay: some View {
        if viewModel.isLoading {
            VStack {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(8)
                .background(Color(.systemBackground).opacity(0.9))
                .cornerRadius(8)
                .padding(.horizontal)
                .padding(.top, 8)
                Spacer()
            }
        }
    }
    
    @ViewBuilder
    private var errorOverlay: some View {
        if let error = viewModel.error {
            VStack {
                ErrorView(
                    error: error,
                    retry: {
                        Task {
                            await reloadEvents()
                        }
                    },
                    dismiss: {
                        viewModel.error = nil
                    }
                )
                .padding()
                Spacer()
            }
        }
    }
    
    // Portal: Spots to show on map (when filter is .all or .spots); category-filtered to mirror Discover
    private var filteredSpots: [Spot] {
        if mapContentFilter == .events { return [] }
        var result = viewModel.spots
        if !discoverFilters.categories.isEmpty {
            result = result.filter { discoverFilters.categories.contains($0.category) }
        }
        return result
    }
    
    // PRD Section 5.2: Apply filters client-side; portal· map content filter (All/Spots/Events)
    private var filteredEvents: [Event] {
        if mapContentFilter == .spots { return [] }
        var events = viewModel.events
        
        // Apply shared Discover time intent filters
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
        
        // Apply shared Discover category filters
        if !discoverFilters.categories.isEmpty {
            events = events.filter { event in
                categoryMatches(event: event)
            }
        }
        
        return events
    }
    
    private func reloadEvents() async {
        if ProcessInfo.processInfo.arguments.contains("--uitesting") { return }
        let location = discoverFilters.searchLocation ?? locationManager.coordinate
        guard let token = authManager.token, !token.isEmpty else { return }
        await viewModel.loadEvents(
            location: location,
            followingOnly: discoverFilters.followingOnly,
            token: token
        )
        await viewModel.loadSpots(location: location, token: token)
        // Load saved event/spot IDs so map preview shows correct bookmark state
        do {
            let eventsResponse = try await APIService.shared.getSavedEvents(token: token)
            await MainActor.run {
                savedEventIds = Set(eventsResponse.data.map(\.event.id))
            }
        } catch {
            #if DEBUG
            print("❌ MapView: Failed to load saved event IDs: \(error)")
            #endif
        }
        do {
            let spotsResponse = try await APIService.shared.getSavedSpots(token: token)
            await MainActor.run {
                savedSpotIds = Set(spotsResponse.data.map(\.id))
            }
        } catch {
            #if DEBUG
            print("❌ MapView: Failed to load saved spot IDs: \(error)")
            #endif
        }
    }

    // PRD: Pin tap shows a compact preview at the bottom with photo miniature; tapping opens full detail.
    @ViewBuilder
    private var eventPreviewOverlay: some View {
        if let event = previewEvent {
            bottomPreviewCard(
                thumbnailURL: event.media.first?.thumbnailUrl ?? event.media.first?.url,
                title: event.title,
                subtitle: eventPreviewSubtitle(event),
                description: truncateDescription(event.description, maxLength: 80),
                headerContent: { eventPreviewHeader(event: event) },
                trailingContent: { eventPreviewTrailing(event: event) },
                onClose: { previewEvent = nil; previewEventSaveCount = nil },
                onTap: { detailEvent = event }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if let spot = previewSpot {
            bottomPreviewCard(
                thumbnailURL: spot.imageUrl,
                title: spot.name,
                subtitle: spot.neighborhood,
                description: spot.description.flatMap { truncateDescription($0, maxLength: 80) },
                headerContent: { EmptyView() },
                trailingContent: { spotPreviewTrailing(spot: spot) },
                onClose: { previewSpot = nil; previewSpotSaveCount = nil },
                onTap: { detailSpot = spot }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func eventStartTimeOnly(_ event: Event) -> String {
        event.startTime.formatted(date: .omitted, time: .shortened)
    }

    private func eventPreviewSubtitle(_ event: Event) -> String {
        let datePart = event.startTime.formatted(.dateTime.month(.abbreviated).day())
        let timePart = event.startTime.formatted(date: .omitted, time: .shortened)
        return "\(datePart) · \(timePart)"
    }

    @ViewBuilder
    private func eventPreviewHeader(event: Event) -> some View {
        Text(event.category.displayName)
            .font(.system(size: 11, weight: .semibold))
            .tracking(0.12)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color(hex: event.category.color).opacity(0.15))
            .foregroundColor(Color(hex: event.category.color))
            .clipShape(RoundedRectangle(cornerRadius: .portalCategoryPillRadius))
    }

    private func truncateDescription(_ text: String, maxLength: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count <= maxLength { return trimmed }
        return String(trimmed.prefix(maxLength)).trimmingCharacters(in: .whitespaces) + "…"
    }

    @ViewBuilder
    private func eventPreviewTrailing(event: Event) -> some View {
        let isSaved = savedEventIds.contains(event.id)
        let displayCount = previewEventSaveCount ?? event.saveCount
        PortalSaveButton(isSaved: isSaved, count: displayCount, surface: .light) {
            Task {
                guard let token = authManager.token, !token.isEmpty else { return }
                do {
                    let result = try await SaveService.shared.toggleEventSave(eventId: event.id, token: token)
                    await MainActor.run {
                        if result.isSaved { savedEventIds.insert(event.id) }
                        else { savedEventIds.remove(event.id) }
                        previewEventSaveCount = result.saveCount
                    }
                } catch {
                    #if DEBUG
                    print("❌ MapView: Failed to toggle save for event \(event.id): \(error)")
                    #endif
                }
            }
        }
    }

    @ViewBuilder
    private func spotPreviewTrailing(spot: Spot) -> some View {
        let isSaved = savedSpotIds.contains(spot.id)
        let displayCount = previewSpotSaveCount ?? spot.saveCount
        PortalSaveButton(isSaved: isSaved, count: displayCount, surface: .light) {
            Task {
                guard let token = authManager.token, !token.isEmpty else { return }
                do {
                    let response = try await APIService.shared.toggleSaveSpot(spotId: spot.id, token: token)
                    await MainActor.run {
                        if response.saved { savedSpotIds.insert(spot.id) }
                        else { savedSpotIds.remove(spot.id) }
                        previewSpotSaveCount = response.saveCount
                    }
                } catch {
                    #if DEBUG
                    print("❌ MapView: Failed to toggle save for spot \(spot.id): \(error)")
                    #endif
                }
            }
        }
    }

    private func bottomPreviewCard<Trailing: View, Header: View>(
        thumbnailURL: String?,
        title: String,
        subtitle: String,
        description: String? = nil,
        @ViewBuilder headerContent: () -> Header,
        @ViewBuilder trailingContent: () -> Trailing,
        onClose: @escaping () -> Void,
        onTap: @escaping () -> Void
    ) -> some View {
        VStack {
            Spacer(minLength: 0)
            Button(action: onTap) {
                HStack(alignment: .top, spacing: 14) {
                    // Photo miniature (larger)
                    Group {
                        if let urlString = thumbnailURL, !urlString.isEmpty, let url = URL(string: urlString) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .success(let image):
                                    image.resizable().aspectRatio(contentMode: .fill)
                                default:
                                    Rectangle().fill(Color.portalMuted)
                                }
                            }
                        } else {
                            Rectangle()
                                .fill(Color.portalMuted)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 24))
                                        .foregroundColor(.portalMutedForeground)
                                )
                        }
                    }
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))

                    VStack(alignment: .leading, spacing: 4) {
                        headerContent()
                        Text(title)
                            .font(.portalLabelSemibold)
                            .foregroundColor(.portalForeground)
                            .lineLimit(1)
                        Text(subtitle)
                            .font(.portalMetadata)
                            .foregroundColor(.portalMutedForeground)
                            .lineLimit(1)
                        if let desc = description, !desc.isEmpty {
                            Text(desc)
                                .font(.portalMetadata)
                                .foregroundColor(.portalForeground.opacity(0.8))
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    trailingContent()
                }
                .padding(16)
                .background(Color.portalCard.opacity(0.96))
                .clipShape(RoundedRectangle(cornerRadius: .portalRadius))
                .shadow(color: Color.portalForeground.opacity(0.08), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .overlay(alignment: .topLeading) {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.portalMutedForeground)
                        .frame(width: 28, height: 28)
                        .background(Color.portalCard.opacity(0.95))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(10)
            }
            .padding(.horizontal, .portalPagePadding)
            .padding(.trailing, 56)
            .padding(.bottom, 24)
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
}

// MARK: - Event Pin

// portal· Map pin: teal pill; events use ticket icon; LIVE badge when ongoing
struct EventPin: View {
    let event: Event
    @State private var isPulsating = false

    private var truncatedTitle: String {
        let max = 20
        if event.title.count <= max { return event.title }
        return String(event.title.prefix(max - 3)) + "..."
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            HStack(spacing: 6) {
                Image(systemName: "ticket.fill")
                    .font(.system(size: 12, weight: .semibold))
                Text(truncatedTitle)
                    .font(.portalLabelSemibold)
                    .lineLimit(1)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.portalPrimary)
            .clipShape(Capsule())
            .shadow(color: Color.portalForeground.opacity(0.15), radius: 2, x: 0, y: 1)
            .shadow(color: Color.portalForeground.opacity(0.1), radius: 6, x: 0, y: 3)
            .scaleEffect(event.isLive && isPulsating ? 1.02 : 1.0)
            .animation(
                event.isLive ? .easeInOut(duration: 2).repeatForever(autoreverses: true) : .default,
                value: isPulsating
            )
            .onAppear {
                if event.isLive { isPulsating = true }
            }

            if event.isLive {
                Text("LIVE")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.portalPrimaryForeground)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.portalLive)
                    .clipShape(Capsule())
                    .offset(x: 4, y: -4)
            }
        }
    }
}

// MARK: - Spot Pin (portal· map pins for spots)

struct SpotPin: View {
    let spot: Spot
    
    private var truncatedName: String {
        let max = 16
        if spot.name.count <= max { return spot.name }
        return String(spot.name.prefix(max - 3)) + "..."
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "mappin")
                .font(.system(size: 12, weight: .semibold))
            Text(truncatedName)
                .font(.portalLabelSemibold)
                .lineLimit(1)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.portalPrimary)
        .clipShape(Capsule())
        .shadow(color: Color.portalForeground.opacity(0.15), radius: 2, x: 0, y: 1)
    }
}

// MARK: - Map View Model

@MainActor
class MapViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var spots: [Spot] = []
    @Published var isLoading = false
    @Published var error: Error? // PRD Section 9.1: Store Error instead of String for better handling
    @Published var cameraPosition: MapCameraPosition = .userLocation(fallback: .automatic)
    
    private let api = APIService.shared
    private var loadEventsTask: Task<Void, Never>?
    private var lastLoadedLocation: CLLocationCoordinate2D?
    private var lastLoadTime: Date?
    // Simple cache: store events by location key (rounded to ~100m grid)
    private var eventCache: [String: (events: [Event], timestamp: Date)] = [:]
    private let cacheValiditySeconds: TimeInterval = 30.0 // Cache valid for 30 seconds
    
    // Location updates happen every 15m for map tracking (smooth user location movement)
    // But API calls are debounced/throttled to prevent excessive requests
    // PRD Section 5.1: Distance throttling set to 15m minimum movement
    private let minimumDistanceMeters: Double = 15.0 // Only refetch events if moved 15+ meters (PRD requirement)
    private let debounceDelaySeconds: Double = 2.0 // Reduced from 3.0 to 2.0 seconds for faster response
    private let minimumTimeBetweenLoads: TimeInterval = 5.0 // Reduced from 8.0 to 5.0 seconds for faster response
    
    func loadEvents(location: CLLocationCoordinate2D, followingOnly: Bool = false, token: String) async {
        // Check if we've loaded recently
        if let lastLoad = lastLoadTime, Date().timeIntervalSince(lastLoad) < minimumTimeBetweenLoads {
            #if DEBUG
            print("📍 MapViewModel: Skipping load - too soon since last load (only \(Date().timeIntervalSince(lastLoad))s ago)")
            #endif
            return
        }
        
        let cacheKey = "\(Int(location.latitude * 1000))_\(Int(location.longitude * 1000))_\(followingOnly)"
        if let cached = eventCache[cacheKey],
           Date().timeIntervalSince(cached.timestamp) < cacheValiditySeconds {
            #if DEBUG
            print("📍 MapViewModel: Using cached events (age: \(Int(Date().timeIntervalSince(cached.timestamp)))s)")
            #endif
            events = cached.events
            lastLoadedLocation = location
            return
        }
        
        isLoading = true
        error = nil
        lastLoadTime = Date()
        
        #if DEBUG
        print("📍 MapViewModel: Loading events for location (\(location.latitude), \(location.longitude))")
        #endif
        
        do {
            let response = try await api.getNearbyEvents(
                lat: location.latitude,
                lng: location.longitude,
                followingOnly: followingOnly,
                token: token
            )
            events = response.data
            lastLoadedLocation = location
            
            // Cache the results
            eventCache[cacheKey] = (events: response.data, timestamp: Date())
            // Clean old cache entries (keep only last 10)
            if eventCache.count > 10 {
                let sorted = eventCache.sorted { $0.value.timestamp < $1.value.timestamp }
                for (key, _) in sorted.prefix(eventCache.count - 10) {
                    eventCache.removeValue(forKey: key)
                }
            }
            
            #if DEBUG
            print("✅ MapViewModel: Successfully loaded \(response.data.count) events")
            #endif
        } catch let error as APIError {
            var errorCode: String?
            var errorMsg: String?
            switch error {
            case .serverError(let detail):
                errorCode = detail.code
                errorMsg = detail.message
            case .unauthorized:
                errorCode = "UNAUTHORIZED"
                errorMsg = "Please log in again"
            case .notFound:
                errorCode = "NOT_FOUND"
                errorMsg = "Not found"
            case .unknown(let code):
                errorCode = "UNKNOWN"
                errorMsg = "Unknown error (code: \(code))"
            default:
                errorCode = nil
                errorMsg = error.errorDescription
            }
            #if DEBUG
            print("📡 MapViewModel: API Error Code: \(errorCode ?? "N/A") Message: \(errorMsg ?? "N/A")")
            #endif
            self.error = error
        } catch let err {
            #if DEBUG
            print("📡 MapViewModel: Network Error \(type(of: err)): \(err.localizedDescription)")
            #endif
            self.error = err
        }
        isLoading = false
    }
    
    func loadSpots(location: CLLocationCoordinate2D, token: String) async {
        guard !token.isEmpty else { return }
        do {
            let response = try await api.getSpots(lat: location.latitude, lng: location.longitude, radius: 5000, limit: 50, token: token)
            spots = response.data.map { Spot(from: $0) }
        } catch {
            #if DEBUG
            print("❌ MapViewModel: Failed to load spots: \(error.localizedDescription)")
            #endif
        }
    }
    
    func debouncedLoadEvents(location: CLLocationCoordinate2D, followingOnly: Bool = false, token: String) {
        // Cancel previous pending task
        loadEventsTask?.cancel()
        
        // Check if location changed significantly
        if let lastLocation = lastLoadedLocation {
            let distance = CLLocation(
                latitude: lastLocation.latitude,
                longitude: lastLocation.longitude
            ).distance(from: CLLocation(
                latitude: location.latitude,
                longitude: location.longitude
            ))
            
            // If moved less than minimum distance, skip
            if distance < minimumDistanceMeters {
                #if DEBUG
                print("📍 MapViewModel: Location changed by only \(Int(distance))m - skipping load (minimum: \(Int(minimumDistanceMeters))m)")
                #endif
                return
            }
            
            #if DEBUG
            print("📍 MapViewModel: Location changed by \(Int(distance))m - will load after debounce")
            #endif
        } else {
            #if DEBUG
            print("📍 MapViewModel: First location update - will load after debounce")
            #endif
        }
        
        // Debounce task: only the wait is cancellable. Once we start loading, don't cancel it.
        let loc = location
        let fol = followingOnly
        let tok = token
        loadEventsTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(debounceDelaySeconds * 1_000_000_000))
            } catch {
                #if DEBUG
                print("📍 MapViewModel: Debounce task cancelled (new location update)")
                #endif
                return
            }
            guard !Task.isCancelled else { return }
            loadEventsTask = nil
            // Run load in a separate task so cancelling the debounce never cancels the API call (-999)
            Task { @MainActor in
                await loadEvents(location: loc, followingOnly: fol, token: tok)
            }
        }
    }
}

// MARK: - Custom Time Range Picker

struct CustomTimeRangePickerView: View {
    @Binding var timeRange: (start: Date, end: Date)
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Start Date") {
                    DatePicker("Start", selection: Binding(
                        get: { timeRange.start },
                        set: { newDate in
                            // Set to start of day (no time)
                            let calendar = Calendar.current
                            timeRange.start = calendar.startOfDay(for: newDate)
                        }
                    ), displayedComponents: .date)
                }
                
                Section("End Date") {
                    DatePicker("End", selection: Binding(
                        get: { timeRange.end },
                        set: { newDate in
                            // Set to end of day (no time)
                            let calendar = Calendar.current
                            timeRange.end = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: newDate) ?? newDate
                        }
                    ), in: timeRange.start..., displayedComponents: .date)
                }
            }
            .navigationTitle("Custom Time Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        onApply()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    MapView()
        .environmentObject(AuthManager())
        .environmentObject(LocationManager())
}

