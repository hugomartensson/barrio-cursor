import SwiftUI

struct EditPlanSheet: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    let plan: PlanData
    var onSaved: ((PlanData) -> Void)?

    @State private var name: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var isSaving = false
    @State private var errorMessage: String?

    private static let planDateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()

    private static let displayFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    init(plan: PlanData, onSaved: ((PlanData) -> Void)? = nil) {
        self.plan = plan
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
            Form {
                Section("Plan Name") {
                    TextField("Name", text: $name)
                }

                Section("Dates") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)
                        .onChange(of: startDate) { _, newStart in
                            if endDate < newStart { endDate = newStart }
                        }
                    DatePicker("End Date", selection: $endDate, in: startDate..., displayedComponents: .date)
                }

                if let err = errorMessage {
                    Section {
                        Text(err)
                            .foregroundColor(.portalDestructive)
                            .font(.portalMetadata)
                    }
                }
            }
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
