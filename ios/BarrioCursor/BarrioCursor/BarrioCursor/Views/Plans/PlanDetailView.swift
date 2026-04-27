import SwiftUI
import MapKit
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
            description: planSpot.description,
            coordinate: CLLocationCoordinate2D(latitude: planSpot.latitude, longitude: planSpot.longitude)
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

// MARK: - PlanDetailView

struct PlanDetailView: View {
    let plan: PlanData
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var detail: PlanDetailData?
    @State private var localItems: [PlanItemEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var addFromSavesWrapper: DayOffsetWrapper?
    @State private var selectedSpotId: String?
    @State private var dropTargetDay: Int? = nil
    @State private var showPlanMap = false
    @State private var showEditPlan = false
    @State private var showDeleteConfirm = false
    @State private var showLeavePlanConfirm = false
    @State private var showInviteFriends = false
    @State private var errorToast: String? = nil
    @State private var undoToast: RemovedItemInfo? = nil
    @State private var currentPlan: PlanData

    init(plan: PlanData) {
        self.plan = plan
        _currentPlan = State(initialValue: plan)
    }

    private var planSpots: [PortalSpotItem] {
        localItems.compactMap { item -> PortalSpotItem? in
            guard item.itemType == "spot", let s = item.spot else { return nil }
            return PortalSpotItem(from: s)
        }
    }

    private var planEvents: [Event] {
        localItems.compactMap { item -> Event? in
            guard item.itemType == "event", let e = item.event else { return nil }
            return e
        }
    }

    private var unscheduledItems: [PlanItemEntry] {
        localItems.filter { $0.dayOffset == -1 }
    }

    private static let dayHeaderFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    private static let shortDayFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    var body: some View {
        ZStack(alignment: .bottom) {
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

            // Error toast
            if let msg = errorToast {
                errorPill(msg)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 16)
            }

            // Undo toast
            if let removedInfo = undoToast {
                undoPill(removedInfo)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 16)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: errorToast)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: undoToast?.id)
        .navigationTitle(currentPlan.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar { toolbarContent }
        .task { await loadDetail() }
        .sheet(isPresented: $showEditPlan) {
            EditPlanSheet(
                plan: currentPlan,
                existingItemIds: Set(localItems.map { $0.itemId })
            ) { updated in
                // Update header fields in place — no refetch, so the scroll position
                // and rendered items don't flash/reload while the user is editing.
                currentPlan = updated
            }
            .environmentObject(authManager)
        }
        .sheet(item: $addFromSavesWrapper, onDismiss: { Task { await loadDetail() } }) { wrapper in
            AddFromSavesSheet(
                planId: currentPlan.id,
                dayOffset: wrapper.offset,
                planStartDate: currentPlan.startDate,
                planEndDate: currentPlan.endDate,
                existingItemIds: Set(localItems.map { $0.itemId })
            ) { items in
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
        .sheet(isPresented: $showInviteFriends) {
            InviteFriendsSheet(
                planId: currentPlan.id,
                existingMemberIds: Set((currentPlan.members ?? []).map { $0.userId })
            ) {
                Task { await loadDetail() }
            }
            .environmentObject(authManager)
        }
        .navigationDestination(for: Event.self) { event in
            EventDetailView(event: event)
                .environmentObject(authManager)
        }
        .fullScreenCover(isPresented: $showPlanMap) {
            FocusedMapView(
                title: currentPlan.name,
                spots: planSpots,
                events: planEvents
            )
            .environmentObject(authManager)
        }
        .confirmationDialog(
            "Delete this plan? This can't be undone.",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete Plan", role: .destructive) { Task { await deletePlan() } }
            Button("Cancel", role: .cancel) { }
        }
        .confirmationDialog(
            "Leave this plan? You'll lose access unless re-invited.",
            isPresented: $showLeavePlanConfirm,
            titleVisibility: .visible
        ) {
            Button("Leave Plan", role: .destructive) { Task { await leavePlan() } }
            Button("Cancel", role: .cancel) { }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            Menu {
                if currentPlan.isOwner {
                    Button { showEditPlan = true } label: {
                        Label("Edit Plan", systemImage: "pencil")
                    }
                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Delete Plan", systemImage: "trash")
                    }
                } else {
                    Button(role: .destructive) { showLeavePlanConfirm = true } label: {
                        Label("Leave Plan", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.portalForeground)
            }
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
            .padding(.bottom, 16)

            // Mini map
            if !planSpots.isEmpty || !planEvents.isEmpty {
                PlanMiniMap(spots: planSpots, events: planEvents)
                    .padding(.horizontal, .portalPagePadding)
                    .padding(.bottom, 20)
                    .onTapGesture { showPlanMap = true }
            }

            // Friends in Plan
            friendsSection

            // To be scheduled
            if !unscheduledItems.isEmpty {
                toBeScheduledSection(det: det)
            }

            // Day sections
            ForEach(0..<det.numberOfDays, id: \.self) { offset in
                daySectionView(det: det, dayOffset: offset)
            }
        }
    }

    // MARK: - Friends in Plan

    @ViewBuilder
    private var friendsSection: some View {
        let viewerId = authManager.currentUser?.id
        let rawMembers = currentPlan.members ?? []
        // Hide the viewer themself; they don't count as a "friend in this plan".
        let allMembers = rawMembers.filter { $0.userId != viewerId }
        let accepted = allMembers.filter { $0.status == "accepted" }
        let invited = allMembers.filter { $0.status == "invited" }
        // Always include the creator (so invited users see who they're joining).
        // The owner isn't in `members` (members is non-owners only), so synthesize an entry.
        let ownerEntry: PlanMember? = {
            guard currentPlan.userId != viewerId else { return nil }
            guard !allMembers.contains(where: { $0.userId == currentPlan.userId }) else { return nil }
            return PlanMember(
                id: "owner-\(currentPlan.userId)",
                userId: currentPlan.userId,
                name: currentPlan.ownerName ?? "Creator",
                profilePictureUrl: currentPlan.ownerProfilePictureUrl,
                status: "accepted"
            )
        }()
        let visible = (ownerEntry.map { [$0] } ?? []) + accepted + invited   // creator, accepted, then pending
        VStack(alignment: .leading, spacing: 10) {
            Text("FRIENDS IN PLAN")
                .font(.portalSectionTitle)
                .tracking(1.0)
                .foregroundColor(.portalMutedForeground)
                .padding(.horizontal, .portalPagePadding)

            HStack(spacing: 12) {
                // Overlapping avatars
                if visible.isEmpty {
                    Text("No friends invited yet")
                        .font(.portalMetadata)
                        .foregroundColor(.portalMutedForeground)
                } else {
                    let shown = Array(visible.prefix(3))
                    let extra = visible.count - 3
                    HStack(spacing: -8) {
                        ForEach(shown) { member in
                            memberAvatarSmall(member)
                                .saturation(member.status == "accepted" ? 1.0 : 0.0)
                                .opacity(member.status == "accepted" ? 1.0 : 0.55)
                        }
                        if extra > 0 {
                            ZStack {
                                Circle().fill(Color.portalMuted).frame(width: 32, height: 32)
                                    .overlay(Circle().stroke(Color.portalBackground, lineWidth: 2))
                                Text("+\(extra)")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.portalMutedForeground)
                            }
                        }
                    }
                }

                Spacer()

                Button {
                    showInviteFriends = true
                } label: {
                    Text("Invite")
                        .font(.portalLabelSemibold)
                        .foregroundColor(.portalPrimary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color.portalPrimary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, .portalPagePadding)
        }
        .padding(.bottom, 20)
    }

    @ViewBuilder
    private func memberAvatarSmall(_ member: PlanMember) -> some View {
        Group {
            if let u = member.profilePictureUrl, let url = URL(string: u) {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase { img.resizable().aspectRatio(contentMode: .fill) }
                    else { initialsCircleSmall(member.name) }
                }
            } else {
                initialsCircleSmall(member.name)
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.portalBackground, lineWidth: 2))
    }

    private func initialsCircleSmall(_ name: String) -> some View {
        ZStack {
            Circle().fill(Color.portalMuted)
            Text(String(name.prefix(1)).uppercased())
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.portalMutedForeground)
        }
    }

    // MARK: - To Be Scheduled

    @ViewBuilder
    private func toBeScheduledSection(det: PlanDetailData) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TO BE SCHEDULED")
                .font(.portalSectionTitle)
                .tracking(1.0)
                .foregroundColor(.portalMutedForeground)
                .padding(.horizontal, .portalPagePadding)

            ForEach(unscheduledItems) { item in
                unscheduledItemRow(item: item, det: det)
                    .padding(.horizontal, .portalPagePadding)
            }
        }
        .padding(.bottom, 28)
        .dropDestination(for: PlanItemDragPayload.self) { payloads, _ in
            guard let payload = payloads.first else { return false }
            Task { await moveItem(itemId: payload.itemId, to: -1) }
            return true
        } isTargeted: { targeted in
            withAnimation(.easeOut(duration: 0.12)) {
                dropTargetDay = targeted ? -1 : nil
            }
        }
    }

    @ViewBuilder
    private func unscheduledItemRow(item: PlanItemEntry, det: PlanDetailData) -> some View {
        HStack(spacing: 8) {
            // Item info
            Group {
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
                    PlanItemSmallRow(
                        imageURL: event.media.first?.thumbnailUrl ?? event.media.first?.url,
                        title: event.title,
                        subtitle: event.startTime.formatted(.dateTime.month(.abbreviated).day()),
                        category: event.category.displayName,
                        categoryColor: Color(hex: event.category.color),
                        mode: .plain(onTap: nil)
                    )
                }
            }

            // Plan button (day picker) — events restricted to valid dates within the plan range
            let validOffsets: [Int] = {
                if item.itemType == "event", let event = item.event {
                    return det.validDayOffsets(forEventStartTime: event.startTime, endTime: event.endTime)
                }
                return Array(0..<det.numberOfDays)
            }()

            if validOffsets.isEmpty {
                Text("Outside plan dates")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.portalMutedForeground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.portalMuted)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Menu {
                    ForEach(validOffsets, id: \.self) { offset in
                        if let date = det.date(for: offset) {
                            Button(Self.shortDayFmt.string(from: date)) {
                                Task { await moveItem(itemId: item.id, to: offset) }
                            }
                        }
                    }
                } label: {
                    Text("Plan")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.portalPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.portalPrimary.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }

            // Delete button
            Button {
                Task { await removeItem(item) }
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.portalDestructive)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Day Sections

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
                        .draggable(PlanItemDragPayload(itemId: item.id)) {
                            planItemDragPreview(item: item)
                        }
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
        .overlay(
            RoundedRectangle(cornerRadius: .portalRadiusSm)
                .strokeBorder(
                    isTarget ? Color.portalPrimary.opacity(0.7) : Color.clear,
                    style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                )
                .padding(.horizontal, .portalPagePadding - 4)
                .allowsHitTesting(false)
        )
        .dropDestination(for: PlanItemDragPayload.self) { payloads, _ in
            guard let payload = payloads.first else { return false }
            Task { await moveItem(itemId: payload.itemId, to: dayOffset) }
            return true
        } isTargeted: { targeted in
            withAnimation(.easeOut(duration: 0.12)) {
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

    // Drag preview at actual size
    @ViewBuilder
    private func planItemDragPreview(item: PlanItemEntry) -> some View {
        planItemRow(item: item)
            .frame(width: UIScreen.main.bounds.width - 2 * CGFloat.portalPagePadding)
            .background(Color.portalCard)
            .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))
    }

    // MARK: - Toast overlays

    private func errorPill(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color.black.opacity(0.8))
            .clipShape(Capsule())
    }

    private func undoPill(_ info: RemovedItemInfo) -> some View {
        HStack(spacing: 12) {
            Text("Item removed")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
            Button("Undo") {
                Task { await undoRemove(info) }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.portalPrimary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.85))
        .clipShape(Capsule())
    }

    // MARK: - Data

    private func loadDetail() async {
        guard let token = authManager.token else { return }
        await MainActor.run { isLoading = true }
        do {
            let result = try await PlanService.shared.getPlan(id: currentPlan.id, token: token)
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
        let snapshot = item
        await MainActor.run { localItems.removeAll { $0.id == item.id } }
        do {
            try await PlanService.shared.removeItem(planId: currentPlan.id, itemId: item.id, token: token)
            await MainActor.run {
                undoToast = RemovedItemInfo(entry: snapshot)
            }
            // Auto-dismiss undo toast
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await MainActor.run {
                    if undoToast?.entry.id == snapshot.id { undoToast = nil }
                }
            }
        } catch {
            await loadDetail()
        }
    }

    private func undoRemove(_ info: RemovedItemInfo) async {
        guard let token = authManager.token else { return }
        await MainActor.run { undoToast = nil }
        let body = PlanItemBody(itemType: info.entry.itemType, itemId: info.entry.itemId, dayOffset: info.entry.dayOffset)
        do {
            let newItems = try await PlanService.shared.addItems(planId: currentPlan.id, items: [body], token: token)
            await MainActor.run { localItems.append(contentsOf: newItems) }
        } catch {
            await loadDetail()
        }
    }

    private func addItems(_ bodies: [PlanItemBody], dayOffset: Int) async {
        guard let token = authManager.token else { return }
        do {
            let newItems = try await PlanService.shared.addItems(planId: currentPlan.id, items: bodies, token: token)
            await MainActor.run { localItems.append(contentsOf: newItems) }
        } catch { }
    }

    private func moveItem(itemId: String, to newDayOffset: Int) async {
        guard let token = authManager.token else { return }

        // Event date validation (client-side guard before API call)
        if newDayOffset >= 0,
           let item = localItems.first(where: { $0.id == itemId }),
           item.itemType == "event",
           let event = item.event,
           let det = detail {
            let validOffsets = det.validDayOffsets(forEventStartTime: event.startTime, endTime: event.endTime)
            if !validOffsets.isEmpty && !validOffsets.contains(newDayOffset) {
                let dateFmt = DateFormatter()
                dateFmt.dateFormat = "MMM d"
                let startStr = dateFmt.string(from: event.startTime)
                let msg: String
                if let endTime = event.endTime, !Calendar.current.isDate(event.startTime, inSameDayAs: endTime) {
                    msg = "This event is on \(startStr)–\(dateFmt.string(from: endTime)) only"
                } else {
                    msg = "This event is on \(startStr) only"
                }
                await showErrorToast(msg)
                return
            }
        }

        // Optimistic update — animate so rows slide instead of popping
        await MainActor.run {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
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
        }
        do {
            try await PlanService.shared.updateItemDay(planId: currentPlan.id, itemId: itemId, dayOffset: newDayOffset, token: token)
        } catch {
            await loadDetail()
        }
    }

    private func showErrorToast(_ message: String) async {
        await MainActor.run { errorToast = message }
        Task {
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await MainActor.run { if errorToast == message { errorToast = nil } }
        }
    }

    private func deletePlan() async {
        guard let token = authManager.token else { return }
        do {
            try await PlanService.shared.deletePlan(id: currentPlan.id, token: token)
        } catch { }
    }

    private func leavePlan() async {
        guard let token = authManager.token else { return }
        do {
            try await PlanService.shared.leavePlan(planId: currentPlan.id, token: token)
            // Notify the plans list to refresh, then pop back to the plans overview.
            NotificationCenter.default.post(name: NSNotification.Name("PlanLeft"), object: currentPlan.id)
            await MainActor.run { dismiss() }
        } catch { }
    }
}

// MARK: - Mini Map

private struct PlanMiniMap: View {
    let spots: [PortalSpotItem]
    let events: [Event]

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        Map(position: $cameraPosition, interactionModes: []) {
            ForEach(spots) { spot in
                if let coord = spot.coordinate {
                    Annotation("", coordinate: coord) {
                        Circle()
                            .fill(Color.portalPrimary)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                            .shadow(radius: 2)
                    }
                }
            }
            ForEach(events) { event in
                Annotation("", coordinate: event.coordinate) {
                    Circle()
                        .fill(Color.teal)
                        .frame(width: 10, height: 10)
                        .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
                        .shadow(radius: 2)
                }
            }
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.portalBorder, lineWidth: 1)
        )
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .padding(8)
                .background(.ultraThinMaterial, in: Circle())
                .padding(10)
        }
        .onAppear { fitCamera() }
    }

    private func fitCamera() {
        let coords: [CLLocationCoordinate2D] = spots.compactMap(\.coordinate) + events.map(\.coordinate)
        guard !coords.isEmpty else { return }
        if coords.count == 1 {
            cameraPosition = .region(MKCoordinateRegion(
                center: coords[0],
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            ))
            return
        }
        let lats = coords.map(\.latitude)
        let lngs = coords.map(\.longitude)
        let center = CLLocationCoordinate2D(
            latitude: ((lats.min()! + lats.max()!) / 2),
            longitude: ((lngs.min()! + lngs.max()!) / 2)
        )
        let span = MKCoordinateSpan(
            latitudeDelta: max((lats.max()! - lats.min()!) * 1.5, 0.01),
            longitudeDelta: max((lngs.max()! - lngs.min()!) * 1.5, 0.01)
        )
        cameraPosition = .region(MKCoordinateRegion(center: center, span: span))
    }
}

// MARK: - Helper types

private struct DayOffsetWrapper: Identifiable {
    let offset: Int
    var id: Int { offset }
}

private struct RemovedItemInfo: Identifiable {
    let entry: PlanItemEntry
    var id: String { entry.id }
}
