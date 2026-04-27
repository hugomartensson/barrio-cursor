import SwiftUI

// MARK: - Plans Tab

struct PlansTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var planNotificationManager: PlanNotificationManager

    @State private var plans: [PlanData] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showCreatePlan = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    plansSection
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
            .refreshable { await loadPlans() }
            .task { await loadPlans() }
            .onAppear {
                planNotificationManager.clearBadge()
            }
            .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PlanLeft"))) { _ in
                Task { await loadPlans() }
            }
            .navigationDestination(for: PlanData.self) { plan in
                PlanDetailView(plan: plan)
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showCreatePlan, onDismiss: { Task { await loadPlans() } }) {
                CreatePlanView { _ in
                    showCreatePlan = false
                    Task { await loadPlans() }
                }
                .environmentObject(authManager)
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
                        if plan.isPendingInvitation {
                            PortalPlanCard(
                                plan: plan,
                                onAccept: { Task { await acceptInvitation(plan) } },
                                onDecline: { Task { await declineInvitation(plan) } }
                            )
                            .padding(.horizontal, .portalPagePadding)
                        } else {
                            NavigationLink(value: plan) {
                                PortalPlanCard(plan: plan)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, .portalPagePadding)
                            .swipeActions(edge: .trailing) {
                                if plan.isOwner {
                                    Button(role: .destructive) {
                                        Task { await deletePlan(plan) }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
            }

            if let err = errorMessage {
                Text(err)
                    .font(.portalMetadata)
                    .foregroundColor(.portalDestructive)
                    .padding(.horizontal, .portalPagePadding)
            }
        }
    }

    // MARK: - Data loading

    private func loadPlans() async {
        guard let token = authManager.token, !token.isEmpty else {
            await MainActor.run { isLoading = false }
            return
        }
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let result = try await PlanService.shared.getPlans(token: token)
            await MainActor.run { plans = result; isLoading = false }
        } catch {
            await MainActor.run {
                errorMessage = (error as? APIError)?.errorDescription ?? error.localizedDescription
                isLoading = false
            }
        }
    }

    private func deletePlan(_ plan: PlanData) async {
        guard let token = authManager.token else { return }
        do {
            try await PlanService.shared.deletePlan(id: plan.id, token: token)
            await MainActor.run { plans.removeAll { $0.id == plan.id } }
        } catch { }
    }

    private func acceptInvitation(_ plan: PlanData) async {
        guard let token = authManager.token else { return }
        do {
            try await PlanService.shared.acceptInvitation(planId: plan.id, token: token)
            await loadPlans()
        } catch { }
    }

    private func declineInvitation(_ plan: PlanData) async {
        guard let token = authManager.token else { return }
        do {
            try await PlanService.shared.declineInvitation(planId: plan.id, token: token)
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
