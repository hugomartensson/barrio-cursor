import SwiftUI

struct AddFromSavesSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    let planId: String
    let dayOffset: Int
    let planStartDate: String
    let planEndDate: String
    let existingItemIds: Set<String>
    /// Called with the selected PlanItemBody array when user taps Add.
    var onAdd: (([PlanItemBody]) -> Void)?

    private enum LibraryTab: String, CaseIterable {
        case spots = "Spots"
        case events = "Events"
    }

    @State private var selectedTab: LibraryTab = .spots
    @State private var savedSpots: [SavedSpotEntry] = []
    @State private var savedEvents: [SavedEventEntry] = []
    @State private var isLoading = false
    @State private var selectedBodies: [PlanItemBody] = []
    @State private var searchText: String = ""
    @State private var selectedCategory: EventCategory? = nil

    private var selectedCount: Int { selectedBodies.count }

    private static let planDateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private var planStartDate_: Date? { Self.planDateFmt.date(from: planStartDate) }
    private var planEndDate_: Date? { Self.planDateFmt.date(from: planEndDate) }

    private var filteredSpots: [SavedSpotEntry] {
        savedSpots.filter { entry in
            let matchesSearch: Bool
            if searchText.isEmpty {
                matchesSearch = true
            } else {
                let q = searchText.lowercased()
                matchesSearch = entry.name.lowercased().contains(q)
                    || (entry.neighborhood?.lowercased().contains(q) ?? false)
                    || (entry.address?.lowercased().contains(q) ?? false)
            }
            let matchesCategory: Bool
            if let cat = selectedCategory {
                matchesCategory = entry.category?.lowercased() == cat.rawValue.lowercased()
            } else {
                matchesCategory = true
            }
            return matchesSearch && matchesCategory
        }
    }

    private var filteredEvents: [SavedEventEntry] {
        savedEvents.filter { entry in
            let event = entry.event
            // Date overlap filter
            if let planStart = planStartDate_, let planEnd = planEndDate_ {
                let cal = Calendar.current
                let planStartDay = cal.startOfDay(for: planStart)
                let planEndDay = cal.startOfDay(for: planEnd)
                let eventStartDay = cal.startOfDay(for: event.startTime)
                let eventEndDay = cal.startOfDay(for: event.endTime ?? event.startTime)
                if eventEndDay < planStartDay || eventStartDay > planEndDay {
                    return false
                }
            }
            let matchesSearch: Bool
            if searchText.isEmpty {
                matchesSearch = true
            } else {
                let q = searchText.lowercased()
                matchesSearch = event.title.lowercased().contains(q)
                    || (event.neighborhood?.lowercased().contains(q) ?? false)
            }
            let matchesCategory: Bool
            if let cat = selectedCategory {
                matchesCategory = event.category == cat
            } else {
                matchesCategory = true
            }
            return matchesSearch && matchesCategory
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                searchBar
                    .padding(.horizontal, .portalPagePadding)
                    .padding(.top, 12)
                    .padding(.bottom, 8)

                // Category pills (Discover-style)
                categoryPills
                    .padding(.bottom, 8)

                // Segmented picker
                Picker("Library", selection: $selectedTab) {
                    ForEach(LibraryTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, .portalPagePadding)
                .padding(.vertical, 8)

                Divider()

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if selectedTab == .spots {
                    spotsList
                } else {
                    eventsList
                }
            }
            .background(Color.portalBackground)
            .navigationTitle("Add from Saves")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.portalMutedForeground)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        guard selectedCount > 0 else { return }
                        let itemsWithDay = selectedBodies.map {
                            PlanItemBody(itemType: $0.itemType, itemId: $0.itemId, dayOffset: dayOffset)
                        }
                        onAdd?(itemsWithDay)
                        dismiss()
                    }
                    .font(.portalLabelSemibold)
                    .foregroundColor(selectedCount > 0 ? .portalPrimary : .portalMutedForeground)
                }
            }
            .task { await loadLibrary() }
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.portalMutedForeground)
                .font(.system(size: 14))
            TextField("Search saves...", text: $searchText)
                .font(.portalLabel)
                .foregroundColor(.portalForeground)
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.portalMutedForeground)
                        .font(.system(size: 14))
                }
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color.portalMuted.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Category pills (Discover-style)

    private var categoryPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: .portalCardGap) {
                ForEach(EventCategory.allCases, id: \.self) { category in
                    PortalFilterPill(
                        title: category.label,
                        isActive: selectedCategory == category,
                        categoryColor: Color.categoryPillColor(for: category.label)
                    ) {
                        selectedCategory = (selectedCategory == category ? nil : category)
                    }
                }
            }
            .padding(.horizontal, .portalPagePadding)
        }
        .frame(height: 44)
        .scrollBounceBehavior(.basedOnSize)
    }

    // MARK: - Lists

    @ViewBuilder
    private var spotsList: some View {
        if filteredSpots.isEmpty {
            emptyState(icon: "mappin.circle", label: savedSpots.isEmpty ? "No saved spots" : "No results")
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(filteredSpots, id: \.id) { entry in
                        let body = PlanItemBody(itemType: "spot", itemId: entry.id, dayOffset: dayOffset)
                        let isSelected = selectedBodies.contains(where: { $0.itemId == entry.id })
                        let alreadyAdded = existingItemIds.contains(entry.id)

                        ZStack(alignment: .trailing) {
                            PlanItemSmallRow(
                                imageURL: entry.imageUrl,
                                title: entry.name,
                                subtitle: entry.neighborhood ?? entry.address,
                                category: entry.category.flatMap { EventCategory(rawValue: $0)?.displayName } ?? entry.category?.capitalized,
                                categoryColor: entry.category != nil ? .portalPrimary : nil,
                                mode: .selectable(
                                    isSelected: isSelected && !alreadyAdded,
                                    onTap: { if !alreadyAdded { toggleSelection(body) } }
                                )
                            )
                            .opacity(alreadyAdded ? 0.5 : 1.0)

                            if alreadyAdded {
                                Text("Already in plan")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.portalMutedForeground)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.portalMuted)
                                    .clipShape(Capsule())
                                    .padding(.trailing, 12)
                            }
                        }
                    }
                }
                .padding(.horizontal, .portalPagePadding)
                .padding(.vertical, 12)
            }
        }
    }

    @ViewBuilder
    private var eventsList: some View {
        if filteredEvents.isEmpty {
            emptyState(icon: "calendar.circle", label: savedEvents.isEmpty ? "No saved events" : "No events match these dates")
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(filteredEvents, id: \.event.id) { entry in
                        let body = PlanItemBody(itemType: "event", itemId: entry.event.id, dayOffset: dayOffset)
                        let isSelected = selectedBodies.contains(where: { $0.itemId == entry.event.id })
                        let alreadyAdded = existingItemIds.contains(entry.event.id)

                        ZStack(alignment: .trailing) {
                            PlanItemSmallRow(
                                imageURL: entry.event.media.first?.thumbnailUrl ?? entry.event.media.first?.url,
                                title: entry.event.title,
                                subtitle: entry.event.startTime.formatted(.dateTime.month(.abbreviated).day()),
                                category: entry.event.category.displayName,
                                categoryColor: Color(hex: entry.event.category.color),
                                mode: .selectable(
                                    isSelected: isSelected && !alreadyAdded,
                                    onTap: { if !alreadyAdded { toggleSelection(body) } }
                                )
                            )
                            .opacity(alreadyAdded ? 0.5 : 1.0)

                            if alreadyAdded {
                                Text("Already in plan")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(.portalMutedForeground)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.portalMuted)
                                    .clipShape(Capsule())
                                    .padding(.trailing, 12)
                            }
                        }
                    }
                }
                .padding(.horizontal, .portalPagePadding)
                .padding(.vertical, 12)
            }
        }
    }

    private func emptyState(icon: String, label: String) -> some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 36, weight: .light))
                .foregroundColor(.portalMutedForeground)
            Text(label)
                .font(.portalMetadata)
                .foregroundColor(.portalMutedForeground)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func toggleSelection(_ body: PlanItemBody) {
        if let idx = selectedBodies.firstIndex(where: { $0.itemId == body.itemId }) {
            selectedBodies.remove(at: idx)
        } else {
            selectedBodies.append(body)
        }
    }

    private func loadLibrary() async {
        guard let token = authManager.token, !token.isEmpty else { return }
        await MainActor.run { isLoading = true }
        do {
            async let spotsTask = APIService.shared.getSavedSpots(token: token)
            async let eventsTask = APIService.shared.getSavedEvents(token: token)
            let (spotsRes, eventsRes) = try await (spotsTask, eventsTask)
            await MainActor.run {
                savedSpots = spotsRes.data
                savedEvents = eventsRes.data
                isLoading = false
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }
}
