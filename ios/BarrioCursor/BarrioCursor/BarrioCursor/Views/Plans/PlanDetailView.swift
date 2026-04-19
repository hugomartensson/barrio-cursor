import SwiftUI
import UniformTypeIdentifiers

// MARK: - PortalSpotItem from PlanItemSpot

extension PortalSpotItem {
    init(from planSpot: PlanItemSpot) {
        self.init(
            id: planSpot.id,
            name: planSpot.name,
            neighborhood: planSpot.neighborhood ?? "",
            addressLine: planSpot.address,
            imageURL: planSpot.imageUrl,
            categoryLabel: EventCategory(rawValue: planSpot.category)?.displayName ?? planSpot.category.capitalized,
            ownerHandle: planSpot.ownerHandle ?? "",
            ownerInitial: String(planSpot.ownerHandle?.prefix(1) ?? "?").uppercased(),
            saveCount: planSpot.saveCount,
            description: planSpot.description
        )
    }
}

// MARK: - Drag payload

extension UTType {
    static let planItem = UTType(exportedAs: "app.barrio.planItem")
}

struct PlanItemDragPayload: Codable, Transferable {
    let itemId: String

    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .planItem)
    }
}

struct PlanDetailView: View {
    let plan: PlanData
    @EnvironmentObject var authManager: AuthManager

    @State private var detail: PlanDetailData?
    @State private var localItems: [PlanItemEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var addFromSavesWrapper: DayOffsetWrapper?
    @State private var selectedSpotId: String?
    @State private var dropTargetDay: Int? = nil

    private static let dayHeaderFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                } else if let det = detail {
                    planContent(det)
                } else if let err = errorMessage {
                    Text(err)
                        .font(.portalMetadata)
                        .foregroundColor(.portalDestructive)
                        .padding(.portalPagePadding)
                }
            }
            .padding(.bottom, 80)
        }
        .background(Color.portalBackground)
        .navigationTitle(plan.name)
        .navigationBarTitleDisplayMode(.large)
        .task { await loadDetail() }
        .sheet(item: $addFromSavesWrapper, onDismiss: { Task { await loadDetail() } }) { wrapper in
            AddFromSavesSheet(planId: plan.id, dayOffset: wrapper.offset) { items in
                Task {
                    await addItems(items, dayOffset: wrapper.offset)
                    await MainActor.run { addFromSavesWrapper = nil }
                }
            }
            .environmentObject(authManager)
        }
        .sheet(item: Binding<SpotIdWrapper?>(
            get: { selectedSpotId.map { SpotIdWrapper(id: $0) } },
            set: { selectedSpotId = $0?.id }
        )) { wrapper in
            if let entry = localItems.first(where: { $0.itemType == "spot" && $0.spot?.id == wrapper.id }),
               let spotData = entry.spot {
                SpotDetailView(spot: PortalSpotItem(from: spotData))
                    .environmentObject(authManager)
                    .presentationDragIndicator(.visible)
            }
        }
        .navigationDestination(for: Event.self) { event in
            EventDetailView(event: event)
                .environmentObject(authManager)
        }
    }

    // MARK: - Content

    @ViewBuilder
    private func planContent(_ det: PlanDetailData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 16) {
                Label(det.dateRangeLabel, systemImage: "calendar")
                    .font(.portalMetadata)
                    .foregroundColor(.portalMutedForeground)
                Label("\(det.itemCount) items", systemImage: "mappin")
                    .font(.portalMetadata)
                    .foregroundColor(.portalMutedForeground)
            }
            .padding(.horizontal, .portalPagePadding)
            .padding(.top, 8)
            .padding(.bottom, 20)

            ForEach(0..<det.numberOfDays, id: \.self) { offset in
                daySectionView(det: det, dayOffset: offset)
            }
        }
    }

    @ViewBuilder
    private func daySectionView(det: PlanDetailData, dayOffset: Int) -> some View {
        let dayItems = localItems.filter { $0.dayOffset == dayOffset }
        let isTarget = dropTargetDay == dayOffset

        VStack(alignment: .leading, spacing: 10) {
            if let date = det.date(for: dayOffset) {
                Text(Self.dayHeaderFmt.string(from: date).uppercased())
                    .font(.portalSectionTitle)
                    .tracking(1.0)
                    .foregroundColor(.portalMutedForeground)
                    .padding(.horizontal, .portalPagePadding)
            }

            if dayItems.isEmpty {
                Text("Nothing added yet — drop items here")
                    .font(.portalMetadata)
                    .foregroundColor(isTarget ? .portalPrimary : .portalMutedForeground.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, .portalPagePadding)
                    .background(
                        RoundedRectangle(cornerRadius: .portalRadiusSm)
                            .stroke(isTarget ? Color.portalPrimary : Color.clear,
                                    style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                            .padding(.horizontal, .portalPagePadding)
                    )
            } else {
                ForEach(dayItems) { item in
                    planItemRow(item: item)
                        .padding(.horizontal, .portalPagePadding)
                        .padding(.vertical, 4)
                        .draggable(PlanItemDragPayload(itemId: item.id))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                Task { await removeItem(item) }
                            } label: {
                                Label("Remove", systemImage: "trash")
                            }
                        }
                }
            }

            Button {
                addFromSavesWrapper = DayOffsetWrapper(offset: dayOffset)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Add from saves")
                        .font(.portalLabel)
                }
                .foregroundColor(.portalPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))
                .overlay(
                    RoundedRectangle(cornerRadius: .portalRadiusSm)
                        .stroke(Color.portalPrimary.opacity(0.5), style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                )
            }
            .buttonStyle(.plain)
            .padding(.horizontal, .portalPagePadding)
        }
        .padding(.bottom, 28)
        .background(isTarget ? Color.portalPrimary.opacity(0.04) : Color.clear)
        .dropDestination(for: PlanItemDragPayload.self) { payloads, _ in
            guard let payload = payloads.first else { return false }
            Task { await moveItem(itemId: payload.itemId, to: dayOffset) }
            return true
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.15)) {
                dropTargetDay = targeted ? dayOffset : nil
            }
        }
    }

    @ViewBuilder
    private func planItemRow(item: PlanItemEntry) -> some View {
        if item.itemType == "spot", let spot = item.spot {
            PlanItemSmallRow(
                imageURL: spot.imageUrl,
                title: spot.name,
                subtitle: spot.neighborhood ?? spot.address,
                category: EventCategory(rawValue: spot.category)?.displayName ?? spot.category.capitalized,
                categoryColor: .portalPrimary,
                mode: .plain(onTap: { selectedSpotId = spot.id })
            )
        } else if item.itemType == "event", let event = item.event {
            NavigationLink(value: event) {
                PlanItemSmallRow(
                    imageURL: event.media.first?.thumbnailUrl ?? event.media.first?.url,
                    title: event.title,
                    subtitle: event.startTime.formatted(.dateTime.month(.abbreviated).day()),
                    category: event.category.displayName,
                    categoryColor: Color(hex: event.category.color),
                    mode: .plain(onTap: nil)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Data

    private func loadDetail() async {
        guard let token = authManager.token else { return }
        await MainActor.run { isLoading = true }
        do {
            let result = try await PlanService.shared.getPlan(id: plan.id, token: token)
            await MainActor.run {
                detail = result
                localItems = result.items
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
                isLoading = false
            }
        }
    }

    private func removeItem(_ item: PlanItemEntry) async {
        guard let token = authManager.token else { return }
        // Optimistic remove
        await MainActor.run { localItems.removeAll { $0.id == item.id } }
        do {
            try await PlanService.shared.removeItem(planId: plan.id, itemId: item.id, token: token)
            await loadDetail()
        } catch {
            // Revert on failure
            await loadDetail()
        }
    }

    private func addItems(_ bodies: [PlanItemBody], dayOffset: Int) async {
        guard let token = authManager.token else { return }
        do {
            _ = try await PlanService.shared.addItems(planId: plan.id, items: bodies, token: token)
            await loadDetail()
        } catch { }
    }

    private func moveItem(itemId: String, to newDayOffset: Int) async {
        guard let token = authManager.token else { return }
        // Optimistic update
        await MainActor.run {
            if let idx = localItems.firstIndex(where: { $0.id == itemId }) {
                let old = localItems[idx]
                localItems[idx] = PlanItemEntry(
                    id: old.id,
                    itemType: old.itemType,
                    dayOffset: newDayOffset,
                    order: old.order,
                    addedAt: old.addedAt,
                    spot: old.spot,
                    event: old.event
                )
            }
        }
        do {
            try await PlanService.shared.updateItemDay(planId: plan.id, itemId: itemId, dayOffset: newDayOffset, token: token)
            await loadDetail()
        } catch {
            await loadDetail()
        }
    }
}

// MARK: - Sheet item wrapper

private struct DayOffsetWrapper: Identifiable {
    let offset: Int
    var id: Int { offset }
}
