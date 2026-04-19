import SwiftUI

struct AddFromSavesSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    let planId: String
    let dayOffset: Int
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

    private var selectedCount: Int { selectedBodies.count }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Library", selection: $selectedTab) {
                    ForEach(LibraryTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, .portalPagePadding)
                .padding(.vertical, 12)

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

    // MARK: - Lists

    @ViewBuilder
    private var spotsList: some View {
        if savedSpots.isEmpty {
            emptyState(icon: "mappin.circle", label: "No saved spots")
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(savedSpots, id: \.id) { entry in
                        let body = PlanItemBody(itemType: "spot", itemId: entry.id, dayOffset: dayOffset)
                        let isSelected = selectedBodies.contains(where: { $0.itemId == entry.id })
                        PlanItemSmallRow(
                            imageURL: entry.imageUrl,
                            title: entry.name,
                            subtitle: entry.neighborhood ?? entry.address,
                            category: entry.category.flatMap { EventCategory(rawValue: $0)?.displayName } ?? entry.category?.capitalized,
                            categoryColor: entry.category != nil ? .portalPrimary : nil,
                            mode: .selectable(isSelected: isSelected, onTap: { toggleSelection(body) })
                        )
                    }
                }
                .padding(.horizontal, .portalPagePadding)
                .padding(.vertical, 12)
            }
        }
    }

    @ViewBuilder
    private var eventsList: some View {
        if savedEvents.isEmpty {
            emptyState(icon: "calendar.circle", label: "No saved events")
        } else {
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 8) {
                    ForEach(savedEvents, id: \.event.id) { entry in
                        let body = PlanItemBody(itemType: "event", itemId: entry.event.id, dayOffset: dayOffset)
                        let isSelected = selectedBodies.contains(where: { $0.itemId == entry.event.id })
                        PlanItemSmallRow(
                            imageURL: entry.event.media.first?.thumbnailUrl ?? entry.event.media.first?.url,
                            title: entry.event.title,
                            subtitle: entry.event.startTime.formatted(.dateTime.month(.abbreviated).day()),
                            category: entry.event.category.displayName,
                            categoryColor: Color(hex: entry.event.category.color),
                            mode: .selectable(isSelected: isSelected, onTap: { toggleSelection(body) })
                        )
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

