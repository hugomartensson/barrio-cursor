import SwiftUI
import Combine

@MainActor
final class PlanNotificationManager: ObservableObject {
    @Published var pendingInvitationCount: Int = 0

    func refresh(token: String) async {
        do {
            let count = try await PlanService.shared.getInvitationCount(token: token)
            pendingInvitationCount = count
        } catch {
            // Silently fail — badge is non-critical
        }
    }

    func clearBadge() {
        pendingInvitationCount = 0
    }
}
