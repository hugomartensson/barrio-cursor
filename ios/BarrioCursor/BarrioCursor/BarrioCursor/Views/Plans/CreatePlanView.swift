import SwiftUI

struct CreatePlanView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    var onCreated: ((PlanDetailData) -> Void)?

    /// Optional item pre-selected (e.g. from "Save to Plan" FAB flow)
    var preselectedItem: PlanItemBody?

    @State private var name: String = ""
    @FocusState private var nameFocused: Bool
    @State private var startDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var endDate: Date = {
        Calendar.current.date(byAdding: .day, value: 3, to: Calendar.current.startOfDay(for: Date())) ?? Date()
    }()
    @State private var showDatePicker = false

    // Library carousel
    @State private var carouselTab: CarouselTab = .spots
    @State private var savedSpots: [SavedSpotEntry] = []
    @State private var savedEvents: [SavedEventEntry] = []
    @State private var selectedItemBodies: [PlanItemBody] = []
    @State private var isLibraryLoading = false
    @State private var isSaving = false
    @State private var errorMessage: String?

    private enum CarouselTab: String, CaseIterable {
        case spots = "Spots"
        case events = "Events"
    }

    private static let planDateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private var isValid: Bool { !name.trimmingCharacters(in: .whitespaces).isEmpty }
    private var selectedCount: Int { selectedItemBodies.count }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    // Name input
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

                    // Dates
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

                    // Add from saves carousel
                    VStack(alignment: .leading, spacing: 12) {
                        Text("ADD FROM SAVES")
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

                    if let err = errorMessage {
                        Text(err)
                            .font(.portalMetadata)
                            .foregroundColor(.portalDestructive)
                            .padding(.horizontal, .portalPagePadding)
                    }
                }
                .padding(.bottom, 32)
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
                nameFocused = true
                if let pre = preselectedItem {
                    selectedItemBodies = [pre]
                }
                Task { await loadLibrary() }
            }
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
            if savedSpots.isEmpty {
                Text("No saved spots")
                    .font(.portalMetadata)
                    .foregroundColor(.portalMutedForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, .portalPagePadding)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(savedSpots, id: \.id) { entry in
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
            if savedEvents.isEmpty {
                Text("No saved events")
                    .font(.portalMetadata)
                    .foregroundColor(.portalMutedForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, .portalPagePadding)
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(savedEvents, id: \.event.id) { entry in
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

    // MARK: - Actions

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

