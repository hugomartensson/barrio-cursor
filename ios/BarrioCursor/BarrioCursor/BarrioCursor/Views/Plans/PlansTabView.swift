import SwiftUI

// MARK: - Library tab toggle
private enum LibraryTab: String, CaseIterable {
    case spots = "Spots"
    case events = "Events"
}

// MARK: - Plans Tab

struct PlansTabView: View {
    @EnvironmentObject var authManager: AuthManager

    @State private var plans: [PlanData] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCreatePlan = false
    @State private var selectedPlan: PlanData?

    // Library
    @State private var libraryTab: LibraryTab = .spots
    @State private var savedSpots: [SavedSpotEntry] = []
    @State private var savedEvents: [SavedEventEntry] = []
    @State private var isLibraryLoading = false
    @State private var selectedSpotIdWrapper: SpotIdWrapper?

    private let api = APIService.shared

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    plansSection
                    librarySection
                }
                .padding(.bottom, 80)
            }
            .background(Color.portalBackground)
            .navigationTitle("Your Plans")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreatePlan = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .semibold))
                            Text("New Plan")
                                .font(.portalLabelSemibold)
                        }
                        .foregroundColor(.portalPrimary)
                    }
                }
            }
            .refreshable { await loadAll() }
            .task { await loadAll() }
            .navigationDestination(for: PlanData.self) { plan in
                PlanDetailView(plan: plan)
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showCreatePlan, onDismiss: { Task { await loadAll() } }) {
                CreatePlanView { newPlan in
                    showCreatePlan = false
                    Task { await loadAll() }
                }
                .environmentObject(authManager)
            }
            .sheet(item: $selectedSpotIdWrapper) { wrapper in
                if let entry = savedSpots.first(where: { $0.id == wrapper.id }) {
                    let spot = PortalSpotItem(from: entry)
                    SpotDetailView(spot: spot, isSaved: true)
                        .environmentObject(authManager)
                        .presentationDragIndicator(.visible)
                }
            }
        }
    }

    // MARK: - Plans section

    @ViewBuilder
    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "UPCOMING PLANS")
                .padding(.horizontal, .portalPagePadding)
                .padding(.top, 20)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if plans.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.portalMutedForeground)
                    Text("No plans yet")
                        .font(.portalLabelSemibold)
                        .foregroundColor(.portalForeground)
                    Text("Create your first plan to organise spots and events.")
                        .font(.portalMetadata)
                        .foregroundColor(.portalMutedForeground)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .padding(.horizontal, .portalPagePadding)
            } else {
                VStack(spacing: 10) {
                    ForEach(plans) { plan in
                        NavigationLink(value: plan) {
                            PortalPlanCard(plan: plan)
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await deletePlan(plan) }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
                .padding(.horizontal, .portalPagePadding)
            }

            if let err = errorMessage {
                Text(err)
                    .font(.portalMetadata)
                    .foregroundColor(.portalDestructive)
                    .padding(.horizontal, .portalPagePadding)
            }
        }
    }

    // MARK: - Library section

    private var librarySection: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(title: "YOUR LIBRARY")
                .padding(.horizontal, .portalPagePadding)
                .padding(.top, 28)
                .padding(.bottom, 12)

            // Segmented control
            Picker("Library", selection: $libraryTab) {
                ForEach(LibraryTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, .portalPagePadding)
            .padding(.bottom, 16)

            if isLibraryLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
            } else if libraryTab == .spots {
                spotsLibrary
            } else {
                eventsLibrary
            }
        }
    }

    @ViewBuilder
    private var spotsLibrary: some View {
        if savedSpots.isEmpty {
            libraryEmptyState(icon: "mappin.circle", label: "No saved spots")
        } else {
            LazyVStack(spacing: 10) {
                ForEach(savedSpots, id: \.id) { entry in
                    let spot = PortalSpotItem(from: entry)
                    Button {
                        selectedSpotIdWrapper = SpotIdWrapper(id: entry.id)
                    } label: {
                        LibrarySpotRow(spot: spot)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, .portalPagePadding)
                }
            }
        }
    }

    @ViewBuilder
    private var eventsLibrary: some View {
        if savedEvents.isEmpty {
            libraryEmptyState(icon: "calendar.circle", label: "No saved events")
        } else {
            LazyVStack(spacing: 10) {
                ForEach(savedEvents, id: \.event.id) { entry in
                    LibraryEventRow(event: entry.event)
                        .padding(.horizontal, .portalPagePadding)
                }
            }
        }
    }

    private func libraryEmptyState(icon: String, label: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .light))
                .foregroundColor(.portalMutedForeground)
            Text(label)
                .font(.portalMetadata)
                .foregroundColor(.portalMutedForeground)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    // MARK: - Data loading

    private func loadAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await loadPlans() }
            group.addTask { await loadLibrary() }
        }
    }

    private func loadPlans() async {
        guard let token = authManager.token, !token.isEmpty else {
            isLoading = false
            return
        }
        isLoading = true
        errorMessage = nil
        do {
            let result = try await PlanService.shared.getPlans(token: token)
            await MainActor.run { plans = result }
        } catch {
            await MainActor.run { errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription }
        }
        await MainActor.run { isLoading = false }
    }

    private func loadLibrary() async {
        guard let token = authManager.token, !token.isEmpty else { return }
        await MainActor.run { isLibraryLoading = true }
        do {
            async let spotsTask = api.getSavedSpots(token: token)
            async let eventsTask = api.getSavedEvents(token: token)
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

    private func deletePlan(_ plan: PlanData) async {
        guard let token = authManager.token else { return }
        do {
            try await PlanService.shared.deletePlan(id: plan.id, token: token)
            await MainActor.run { plans.removeAll { $0.id == plan.id } }
        } catch { }
    }
}

// MARK: - Section header

private struct SectionHeader: View {
    let title: String
    var body: some View {
        Text(title)
            .font(.portalSectionTitle)
            .tracking(1.0)
            .foregroundColor(.portalMutedForeground)
    }
}

// MARK: - Library row views

struct LibrarySpotRow: View {
    let spot: PortalSpotItem
    var body: some View {
        HStack(spacing: 12) {
            thumbnail(urlString: spot.imageURL)
            VStack(alignment: .leading, spacing: 2) {
                if let cat = spot.categoryLabel {
                    Text(cat)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.portalPrimary)
                }
                Text(spot.name)
                    .font(.portalLabelSemibold)
                    .foregroundColor(.portalForeground)
                    .lineLimit(1)
                let subtitle = spot.neighborhood.isEmpty ? spot.addressLine : spot.neighborhood
                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.portalMetadata)
                        .foregroundColor(.portalMutedForeground)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.portalCard)
        .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))
    }

    @ViewBuilder
    private func thumbnail(urlString: String?) -> some View {
        Group {
            if let u = urlString, let url = URL(string: u) {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase { img.resizable().aspectRatio(contentMode: .fill) }
                    else { Color.portalMuted }
                }
            } else {
                Color.portalMuted
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct LibraryEventRow: View {
    let event: Event
    private static let monthFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "MMM"; return f }()
    private static let dayFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "d"; return f }()

    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 2) {
                Text(event.category.displayName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(Color(hex: event.category.color))
                Text(event.title)
                    .font(.portalLabelSemibold)
                    .foregroundColor(.portalForeground)
                    .lineLimit(1)
                Text("\(Self.monthFmt.string(from: event.startTime)) \(Self.dayFmt.string(from: event.startTime)) · \(event.startTime.formatted(date: .omitted, time: .shortened))")
                    .font(.portalMetadata)
                    .foregroundColor(.portalMutedForeground)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(Color.portalCard)
        .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))
    }

    @ViewBuilder
    private var thumbnail: some View {
        Group {
            if let urlString = event.media.first?.thumbnailUrl ?? event.media.first?.url,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase { img.resizable().aspectRatio(contentMode: .fill) }
                    else { Color.portalMuted }
                }
            } else {
                Color.portalMuted
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
