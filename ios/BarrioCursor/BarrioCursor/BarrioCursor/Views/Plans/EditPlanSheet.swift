import SwiftUI

/// Edit-plan sheet — mirrors the Create Plan UX (large name field, range calendar, items selector for adding more).
/// Removing existing items still happens via swipe-to-remove inside `PlanDetailView`.
struct EditPlanSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    let plan: PlanData
    /// Item ids already in the plan — passed in by PlanDetailView so the items selector can hide them.
    var existingItemIds: Set<String> = []
    var onSaved: ((PlanData) -> Void)?

    @State private var name: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var selectedItemBodies: [PlanItemBody] = []
    @State private var isSaving = false
    @State private var errorMessage: String?

    private static let planDateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    init(plan: PlanData, existingItemIds: Set<String> = [], onSaved: ((PlanData) -> Void)? = nil) {
        self.plan = plan
        self.existingItemIds = existingItemIds
        self.onSaved = onSaved
        _name = State(initialValue: plan.name)
        let start = Self.planDateFmt.date(from: plan.startDate) ?? Date()
        let end = Self.planDateFmt.date(from: plan.endDate) ?? Date()
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: end)
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && endDate >= startDate
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                PlanFormContent(
                    mode: .edit(existingItemIds: existingItemIds),
                    name: $name,
                    startDate: $startDate,
                    endDate: $endDate,
                    selectedItemBodies: $selectedItemBodies,
                    autofocusName: false
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
            .navigationTitle("Edit Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(.portalMutedForeground)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView().scaleEffect(0.8)
                    } else {
                        Button("Save") { Task { await save() } }
                            .font(.portalLabelSemibold)
                            .foregroundColor(isValid ? .portalPrimary : .portalMutedForeground)
                            .disabled(!isValid)
                    }
                }
            }
        }
    }

    private func save() async {
        guard let token = authManager.token, isValid else { return }
        await MainActor.run { isSaving = true; errorMessage = nil }
        do {
            let startStr = Self.planDateFmt.string(from: startDate)
            let endStr = Self.planDateFmt.string(from: endDate)
            let updated = try await PlanService.shared.updatePlan(
                id: plan.id,
                name: name.trimmingCharacters(in: .whitespaces),
                startDate: startStr,
                endDate: endStr,
                token: token
            )
            // Add any newly selected items (additive only — removal happens via swipe in PlanDetailView)
            if !selectedItemBodies.isEmpty {
                _ = try? await PlanService.shared.addItems(planId: plan.id, items: selectedItemBodies, token: token)
            }
            await MainActor.run {
                isSaving = false
                onSaved?(updated)
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
