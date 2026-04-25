import SwiftUI

/// Sticky frosted-glass action bar pinned to the bottom of Spot/Event detail views.
/// Three equal actions: Save, Add to Plan, Add to Collection.
struct PortalFloatingActionBar: View {
    // MARK: - Configuration

    /// "event" or "spot" — used for accessibility labels.
    let itemType: String
    let isSaved: Bool
    let saveCount: Int
    let onSaveToggle: () -> Void
    let onAddToPlan: () -> Void
    let onAddToCollection: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            fabButton(
                icon: isSaved ? "bookmark.fill" : "bookmark",
                label: isSaved ? "Saved" : "Save",
                count: saveCount,
                foreground: isSaved ? Color.portalPrimary : Color.portalForeground,
                action: onSaveToggle
            )

            Divider()
                .frame(height: 32)
                .background(Color.portalBorder)

            fabButton(
                icon: "calendar.badge.plus",
                label: "Add to Plan",
                count: nil,
                foreground: .portalForeground,
                action: onAddToPlan
            )

            Divider()
                .frame(height: 32)
                .background(Color.portalBorder)

            fabButton(
                icon: "folder.badge.plus",
                label: "Add to Collection",
                count: nil,
                foreground: .portalForeground,
                action: onAddToCollection
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    @ViewBuilder
    private func fabButton(
        icon: String,
        label: String,
        count: Int?,
        foreground: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 20, weight: .regular))
                        .foregroundColor(foreground)
                        .frame(width: 28, height: 28)

                    if let count = count, count > 0 {
                        Text(count < 1000 ? "\(count)" : "\(count / 1000)k")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(foreground)
                            .clipShape(Capsule())
                            .offset(x: 10, y: -4)
                    }
                }
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(foreground)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

// MARK: - SaveToPlanSheet

struct SaveToPlanSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    let itemType: String   // "spot" | "event"
    let itemId: String
    let itemTitle: String
    let itemCategory: String
    let itemImageURL: String?
    /// For events, used to filter compatible plans and auto-assign dayOffset
    var eventStartTime: Date? = nil
    var eventEndTime: Date? = nil

    /// Called after the item is successfully routed to a plan, passing AddedToPlanInfo for the banner.
    var onSaved: ((AddedToPlanInfo) -> Void)?

    @State private var plans: [PlanData] = []
    @State private var isLoading = true
    @State private var isSaving: String? = nil    // planId being saved to
    @State private var showCreatePlan = false

    /// Plans filtered by date compatibility (for events)
    private var eligiblePlans: [PlanData] {
        guard itemType == "event", let eventStart = eventStartTime else { return plans }
        return plans.filter { plan in
            guard let planStart = PlanData.planDateFormatter.date(from: plan.startDate),
                  let planEnd = PlanData.planDateFormatter.date(from: plan.endDate) else { return true }
            let cal = Calendar.current
            let planStartDay = cal.startOfDay(for: planStart)
            let planEndDay = cal.startOfDay(for: planEnd)
            let eventStartDay = cal.startOfDay(for: eventStart)
            let eventEndDay = cal.startOfDay(for: eventEndTime ?? eventStart)
            return !(eventEndDay < planStartDay || eventStartDay > planEndDay)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Context header
                contextHeader
                    .padding(.horizontal, .portalPagePadding)
                    .padding(.vertical, 16)

                Divider()

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    planList
                }
            }
            .background(Color.portalBackground)
            .navigationTitle("Save to Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.portalMutedForeground)
                }
            }
            .task { await loadPlans() }
            .fullScreenCover(isPresented: $showCreatePlan, onDismiss: { Task { await loadPlans() } }) {
                let week = eventStartTime.map { weekInterval(for: $0) }
                CreatePlanView(
                    onCreated: { newPlan in
                        Task { await routeItem(to: PlanData(
                            id: newPlan.id, userId: newPlan.userId, name: newPlan.name,
                            startDate: newPlan.startDate, endDate: newPlan.endDate,
                            itemCount: newPlan.itemCount, previewImageURLs: newPlan.previewImageURLs,
                            createdAt: newPlan.createdAt, updatedAt: newPlan.updatedAt,
                            role: "owner", members: nil, memberStatus: nil, itemIds: nil)) }
                        showCreatePlan = false
                    },
                    preselectedItem: PlanItemBody(itemType: itemType, itemId: itemId, dayOffset: -1),
                    initialStartDate: week?.start,
                    initialEndDate: week?.end
                )
                .environmentObject(authManager)
            }
        }
    }

    // MARK: - Context header

    private var contextHeader: some View {
        HStack(spacing: 12) {
            Group {
                if let u = itemImageURL, let url = URL(string: u) {
                    AsyncImage(url: url) { phase in
                        if case .success(let img) = phase {
                            img.resizable().aspectRatio(contentMode: .fill)
                        } else {
                            Color.portalMuted
                        }
                    }
                } else {
                    Color.portalMuted
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(itemCategory)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.portalPrimary)
                Text(itemTitle)
                    .font(.portalLabelSemibold)
                    .foregroundColor(.portalForeground)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Plan list

    private var planList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 10) {
                if eligiblePlans.isEmpty && !plans.isEmpty {
                    Text("No plans match this event's dates.")
                        .font(.portalMetadata)
                        .foregroundColor(.portalMutedForeground)
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                }
                ForEach(eligiblePlans) { plan in
                    let alreadyAdded = plan.itemIds?.contains(itemId) ?? false
                    Button { if !alreadyAdded { Task { await routeItem(to: plan) } } } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(plan.name)
                                    .font(.portalLabelSemibold)
                                    .foregroundColor(alreadyAdded ? .portalMutedForeground : .portalForeground)
                                Text(plan.dateRangeLabel)
                                    .font(.portalMetadata)
                                    .foregroundColor(.portalMutedForeground)
                            }
                            Spacer(minLength: 0)
                            if alreadyAdded {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 14))
                                        .foregroundColor(.portalPrimary)
                                    Text("Already added")
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(.portalMutedForeground)
                                }
                            } else if isSaving == plan.id {
                                ProgressView().scaleEffect(0.8)
                            } else {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12))
                                    .foregroundColor(.portalMutedForeground)
                            }
                        }
                        .padding(14)
                        .background(Color.portalCard)
                        .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))
                        .opacity(alreadyAdded ? 0.6 : 1.0)
                    }
                    .buttonStyle(.plain)
                    .disabled(isSaving != nil || alreadyAdded)
                }

                // Create new plan CTA
                Button { showCreatePlan = true } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                        Text("Create New Plan")
                            .font(.portalLabelSemibold)
                    }
                    .foregroundColor(.portalPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))
                    .overlay(
                        RoundedRectangle(cornerRadius: .portalRadiusSm)
                            .stroke(Color.portalPrimary.opacity(0.5),
                                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, .portalPagePadding)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Helpers

    private func weekInterval(for date: Date) -> (start: Date, end: Date) {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let monday = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date))
            ?? cal.startOfDay(for: date)
        let sunday = cal.date(byAdding: .day, value: 6, to: monday) ?? monday
        return (monday, sunday)
    }

    // MARK: - Actions

    private func loadPlans() async {
        guard let token = authManager.token, !token.isEmpty else {
            await MainActor.run { isLoading = false }
            return
        }
        do {
            let result = try await PlanService.shared.getPlans(token: token)
            await MainActor.run { plans = result; isLoading = false }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    private func routeItem(to plan: PlanData) async {
        guard let token = authManager.token else { return }
        await MainActor.run { isSaving = plan.id }

        // Auto-assign dayOffset for events that fall on exactly one plan day
        let assignedDayOffset: Int
        if itemType == "event", let eventStart = eventStartTime {
            let validOffsets = plan.validDayOffsets(forEventStartTime: eventStart, endTime: eventEndTime)
            assignedDayOffset = validOffsets.count == 1 ? validOffsets[0] : -1
        } else {
            assignedDayOffset = -1
        }

        do {
            let body = PlanItemBody(itemType: itemType, itemId: itemId, dayOffset: assignedDayOffset)
            let newItems = try await PlanService.shared.addItems(planId: plan.id, items: [body], token: token)
            let planItemId = newItems.first?.id ?? ""
            await MainActor.run {
                isSaving = nil
                let info = AddedToPlanInfo(planId: plan.id, planName: plan.name, planItemId: planItemId)
                onSaved?(info)
                dismiss()
            }
        } catch {
            await MainActor.run { isSaving = nil }
        }
    }
}
