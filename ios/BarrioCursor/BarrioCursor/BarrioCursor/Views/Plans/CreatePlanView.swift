import SwiftUI

// MARK: - Shared form content (used by both Create and Edit plan flows)

enum PlanFormMode {
    case create
    /// In edit mode, items already in the plan are hidden from the selector so the user only sees additions.
    case edit(existingItemIds: Set<String>)
}

struct PlanFormContent: View {
    @EnvironmentObject var authManager: AuthManager
    let mode: PlanFormMode
    @Binding var name: String
    @Binding var startDate: Date
    @Binding var endDate: Date
    @Binding var selectedItemBodies: [PlanItemBody]
    /// True when the parent wants the name field to take focus on appear (e.g., create flow).
    var autofocusName: Bool = true

    @FocusState private var nameFocused: Bool
    @State private var showDatePicker = false
    @State private var carouselTab: CarouselTab = .spots
    @State private var savedSpots: [SavedSpotEntry] = []
    @State private var savedEvents: [SavedEventEntry] = []
    @State private var isLibraryLoading = false

    private enum CarouselTab: String, CaseIterable {
        case spots = "Spots"
        case events = "Events"
    }

    private var existingItemIds: Set<String> {
        if case .edit(let ids) = mode { return ids }
        return []
    }

    private var visibleSpots: [SavedSpotEntry] {
        savedSpots.filter { !existingItemIds.contains($0.id) }
    }

    private var filteredEvents: [SavedEventEntry] {
        savedEvents
            .filter { !existingItemIds.contains($0.event.id) }
            .filter { entry in
                let cal = Calendar.current
                let planStart = cal.startOfDay(for: startDate)
                let planEnd   = cal.startOfDay(for: endDate)
                let evStart   = cal.startOfDay(for: entry.event.startTime)
                let evEnd     = cal.startOfDay(for: entry.event.endTime ?? entry.event.startTime)
                return !(evEnd < planStart || evStart > planEnd)
            }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                nameSection
                datesSection
                librarySection
            }
            .padding(.bottom, 32)
        }
        .background(Color.portalBackground)
        .onAppear {
            if autofocusName { nameFocused = true }
            Task { await loadLibrary() }
        }
    }

    // MARK: - Sections

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Plan name", text: $name)
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundColor(.portalForeground)
                .focused($nameFocused)
                .submitLabel(.done)

            Divider().background(nameFocused ? Color.portalPrimary : Color.portalBorder)
        }
        .padding(.top, 8)
        .padding(.horizontal, .portalPagePadding)
    }

    private var datesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("DATES")
                .font(.portalSectionTitle)
                .tracking(1.0)
                .foregroundColor(.portalMutedForeground)

            HStack(spacing: 12) {
                dateButton(label: "Start", date: startDate)
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.portalMutedForeground)
                dateButton(label: "End", date: endDate)
            }

            if showDatePicker {
                RangeCalendarView(startDate: $startDate, endDate: $endDate)
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, .portalPagePadding)
    }

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(librarySectionTitle)
                .font(.portalSectionTitle)
                .tracking(1.0)
                .foregroundColor(.portalMutedForeground)
                .padding(.horizontal, .portalPagePadding)

            Picker("", selection: $carouselTab) {
                ForEach(CarouselTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, .portalPagePadding)

            if isLibraryLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if carouselTab == .spots {
                spotsCarousel
            } else {
                eventsCarousel
            }
        }
    }

    private var librarySectionTitle: String {
        switch mode {
        case .create: return "ADD FROM SAVES"
        case .edit:   return "ADD MORE FROM SAVES"
        }
    }

    // MARK: - Date button

    private func dateButton(label: String, date: Date) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                showDatePicker.toggle()
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.portalMutedForeground)
                Text(date.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.portalLabelSemibold)
                    .foregroundColor(.portalForeground)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.portalCard)
            .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))
            .overlay(
                RoundedRectangle(cornerRadius: .portalRadiusSm)
                    .stroke(Color.portalBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Item lists

    @ViewBuilder private var spotsCarousel: some View {
        Group {
            if visibleSpots.isEmpty {
                Text(savedSpots.isEmpty ? "No saved spots" : "All saved spots are already in this plan")
                    .font(.portalMetadata)
                    .foregroundColor(.portalMutedForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, .portalPagePadding)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(visibleSpots, id: \.id) { entry in
                        let body = PlanItemBody(itemType: "spot", itemId: entry.id, dayOffset: -1)
                        let isSelected = selectedItemBodies.contains(where: { $0.itemId == entry.id })
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
            }
        }
    }

    @ViewBuilder private var eventsCarousel: some View {
        Group {
            if filteredEvents.isEmpty {
                Text(savedEvents.isEmpty ? "No saved events" : "No events match these dates")
                    .font(.portalMetadata)
                    .foregroundColor(.portalMutedForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, .portalPagePadding)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(filteredEvents, id: \.event.id) { entry in
                        let body = PlanItemBody(itemType: "event", itemId: entry.event.id, dayOffset: -1)
                        let isSelected = selectedItemBodies.contains(where: { $0.itemId == entry.event.id })
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
            }
        }
    }

    private func toggleSelection(_ body: PlanItemBody) {
        if let idx = selectedItemBodies.firstIndex(where: { $0.itemId == body.itemId }) {
            selectedItemBodies.remove(at: idx)
        } else {
            selectedItemBodies.append(body)
        }
    }

    private func loadLibrary() async {
        guard let token = authManager.token, !token.isEmpty else { return }
        await MainActor.run { isLibraryLoading = true }
        do {
            async let spotsTask = APIService.shared.getSavedSpots(token: token)
            async let eventsTask = APIService.shared.getSavedEvents(token: token)
            let (spotsRes, eventsRes) = try await (spotsTask, eventsTask)
            await MainActor.run {
                savedSpots = spotsRes.data
                savedEvents = eventsRes.data
                isLibraryLoading = false
            }
        } catch {
            await MainActor.run { isLibraryLoading = false }
        }
    }
}

// MARK: - Create Plan (thin wrapper around PlanFormContent)

struct CreatePlanView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    var onCreated: ((PlanDetailData) -> Void)?

    /// Optional item pre-selected (e.g. from "Save to Plan" FAB flow)
    var preselectedItem: PlanItemBody?

    /// Optional initial date range (e.g. pre-filled from an event's week)
    var initialStartDate: Date? = nil
    var initialEndDate: Date? = nil

    @State private var name: String = ""
    @State private var startDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var endDate: Date = {
        Calendar.current.date(byAdding: .day, value: 3, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }()
    @State private var selectedItemBodies: [PlanItemBody] = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    private static let planDateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PlanFormContent(
                    mode: .create,
                    name: $name,
                    startDate: $startDate,
                    endDate: $endDate,
                    selectedItemBodies: $selectedItemBodies
                )
                .environmentObject(authManager)

                if let err = errorMessage {
                    Text(err)
                        .font(.portalMetadata)
                        .foregroundColor(.portalDestructive)
                        .padding(.horizontal, .portalPagePadding)
                        .padding(.bottom, 8)
                }
            }
            .background(Color.portalBackground)
            .navigationTitle("New Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.portalMutedForeground)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        Task { await createPlan() }
                    } label: {
                        Group {
                            if isSaving {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Text("Create")
                                    .font(.portalLabelSemibold)
                            }
                        }
                    }
                    .foregroundColor(isValid ? .portalPrimary : .portalMutedForeground)
                    .disabled(!isValid || isSaving)
                }
            }
            .onAppear {
                if let pre = preselectedItem {
                    selectedItemBodies = [pre]
                }
                if let s = initialStartDate { startDate = s }
                if let e = initialEndDate   { endDate   = e }
            }
        }
    }

    private func createPlan() async {
        guard let token = authManager.token, isValid else { return }
        isSaving = true
        errorMessage = nil
        do {
            let plan = try await PlanService.shared.createPlan(
                name: name.trimmingCharacters(in: .whitespaces),
                startDate: Self.planDateFmt.string(from: startDate),
                endDate: Self.planDateFmt.string(from: endDate),
                initialItems: selectedItemBodies.isEmpty ? nil : selectedItemBodies,
                token: token
            )
            await MainActor.run {
                isSaving = false
                onCreated?(plan)
                dismiss()
            }
        } catch {
            await MainActor.run {
                isSaving = false
                errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
            }
        }
    }
}
