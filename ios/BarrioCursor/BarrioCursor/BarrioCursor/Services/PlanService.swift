import Foundation

// MARK: - Plan domain models

nonisolated struct PlanMember: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let name: String
    let profilePictureUrl: String?
    let status: String  // "invited" | "accepted" | "declined"

    static func == (lhs: PlanMember, rhs: PlanMember) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

nonisolated struct PlanData: Codable, Identifiable, Hashable {
    let id: String
    let userId: String
    let name: String
    let startDate: String   // "YYYY-MM-DD"
    let endDate: String     // "YYYY-MM-DD"
    let itemCount: Int
    let previewImageURLs: [String]
    let createdAt: String
    let updatedAt: String
    let role: String?           // "owner" | "member"
    let members: [PlanMember]?
    let memberStatus: String?   // "invited" | "accepted" | "declined" (only when role == "member")
    let itemIds: [String]?      // IDs of all items in the plan (for duplicate detection)
    /// Plan creator's display name (only present on plan-detail responses).
    let ownerName: String?
    /// Plan creator's profile picture URL.
    let ownerProfilePictureUrl: String?

    static func == (lhs: PlanData, rhs: PlanData) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var isOwner: Bool { role == "owner" || role == nil }
    var isPendingInvitation: Bool { memberStatus == "invited" }

    /// Number of days in the plan (inclusive)
    var numberOfDays: Int {
        let cal = Calendar.current
        guard let s = Self.planDateFormatter.date(from: startDate),
              let e = Self.planDateFormatter.date(from: endDate) else { return 1 }
        return max(1, cal.dateComponents([.day], from: s, to: e).day.map { $0 + 1 } ?? 1)
    }

    /// Human-readable date range, e.g. "Apr 18 – Apr 21"
    var dateRangeLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        guard let s = Self.planDateFormatter.date(from: startDate),
              let e = Self.planDateFormatter.date(from: endDate) else { return "\(startDate) – \(endDate)" }
        return "\(fmt.string(from: s)) – \(fmt.string(from: e))"
    }

    /// Returns the calendar Date for a given dayOffset.
    func date(for dayOffset: Int) -> Date? {
        guard let s = Self.planDateFormatter.date(from: startDate) else { return nil }
        return Calendar.current.date(byAdding: .day, value: dayOffset, to: s)
    }

    /// Returns valid dayOffsets for an event given its start and optional end time.
    func validDayOffsets(forEventStartTime startTime: Date, endTime: Date?) -> [Int] {
        guard let planStart = Self.planDateFormatter.date(from: startDate),
              let planEnd = Self.planDateFormatter.date(from: endDate) else { return [] }

        var valid: [Int] = []
        let cal = Calendar.current
        let eventStartDay = cal.startOfDay(for: startTime)
        let eventEndDay = cal.startOfDay(for: endTime ?? startTime)

        for offset in 0..<numberOfDays {
            guard let day = self.date(for: offset) else { continue }
            let dayStart = cal.startOfDay(for: day)
            // Day overlaps if eventStart <= dayStart <= eventEnd
            if eventStartDay <= dayStart && dayStart <= eventEndDay {
                valid.append(offset)
            }
        }
        _ = planStart; _ = planEnd
        return valid
    }

    static let planDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "UTC")
        return f
    }()
}

nonisolated struct PlanDetailData: Codable, Identifiable {
    let id: String
    let userId: String
    let name: String
    let startDate: String
    let endDate: String
    let itemCount: Int
    let previewImageURLs: [String]
    let createdAt: String
    let updatedAt: String
    let role: String?
    let members: [PlanMember]?
    let memberStatus: String?
    let itemIds: [String]?
    let items: [PlanItemEntry]
    let ownerName: String?
    let ownerProfilePictureUrl: String?

    var isOwner: Bool { role == "owner" || role == nil }

    var asPlanData: PlanData {
        PlanData(id: id, userId: userId, name: name, startDate: startDate, endDate: endDate,
                 itemCount: itemCount, previewImageURLs: previewImageURLs, createdAt: createdAt,
                 updatedAt: updatedAt, role: role, members: members, memberStatus: memberStatus,
                 itemIds: itemIds, ownerName: ownerName, ownerProfilePictureUrl: ownerProfilePictureUrl)
    }

    var numberOfDays: Int { asPlanData.numberOfDays }
    func date(for dayOffset: Int) -> Date? { asPlanData.date(for: dayOffset) }
    func validDayOffsets(forEventStartTime startTime: Date, endTime: Date?) -> [Int] {
        asPlanData.validDayOffsets(forEventStartTime: startTime, endTime: endTime)
    }
    func items(for dayOffset: Int) -> [PlanItemEntry] { items.filter { $0.dayOffset == dayOffset } }
    var dateRangeLabel: String { asPlanData.dateRangeLabel }
}

nonisolated struct PlanItemEntry: Codable, Identifiable {
    let id: String
    let itemType: String   // "spot" | "event"
    let dayOffset: Int     // -1 = "To be scheduled"
    let order: Int
    let addedAt: String
    let spot: PlanItemSpot?
    let event: Event?

    var itemId: String {
        spot?.id ?? event?.id ?? ""
    }
}

nonisolated struct PlanItemSpot: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let address: String
    let latitude: Double
    let longitude: Double
    let neighborhood: String?
    let category: String
    let imageUrl: String?
    let saveCount: Int
    let distance: Double
    let ownerId: String
    let ownerHandle: String?
}

// MARK: - Request bodies

nonisolated struct CreatePlanBody: Encodable {
    let name: String
    let startDate: String
    let endDate: String
    let initialItems: [PlanItemBody]?
}

nonisolated struct UpdatePlanBody: Encodable {
    let name: String?
    let startDate: String?
    let endDate: String?
}

nonisolated struct AddPlanItemsBody: Encodable {
    let items: [PlanItemBody]
}

nonisolated struct PlanItemBody: Encodable {
    let itemType: String
    let itemId: String
    let dayOffset: Int  // -1 = "To be scheduled"
}

nonisolated struct InviteMembersBody: Encodable {
    let userIds: [String]
}

// MARK: - Response wrappers

nonisolated struct PlansListResponse: Codable {
    let data: [PlanData]
}

nonisolated struct PlanDetailResponse: Codable {
    let data: PlanDetailData
}

nonisolated struct PlanItemsResponse: Codable {
    let data: [PlanItemEntry]
}

nonisolated struct PlanMembersResponse: Codable {
    let data: [PlanMember]
}

nonisolated struct InvitationCountResponse: Codable {
    let data: InvitationCount
}

nonisolated struct InvitationCount: Codable {
    let count: Int
}

// MARK: - PlanService

actor PlanService {
    static let shared = PlanService()

    func getPlans(token: String) async throws -> [PlanData] {
        let response: PlansListResponse = try await APIService.shared.get("/plans", token: token)
        return response.data
    }

    func getPlan(id: String, token: String) async throws -> PlanDetailData {
        let response: PlanDetailResponse = try await APIService.shared.get("/plans/\(id)", token: token)
        return response.data
    }

    func createPlan(name: String, startDate: String, endDate: String,
                    initialItems: [PlanItemBody]?, token: String) async throws -> PlanDetailData {
        let body = CreatePlanBody(name: name, startDate: startDate, endDate: endDate,
                                  initialItems: initialItems)
        let response: PlanDetailResponse = try await APIService.shared.post("/plans", body: body, token: token)
        return response.data
    }

    func updatePlan(id: String, name: String?, startDate: String?, endDate: String?, token: String) async throws -> PlanData {
        let body = UpdatePlanBody(name: name, startDate: startDate, endDate: endDate)
        struct Wrapper: Codable { let data: PlanData }
        let response: Wrapper = try await APIService.shared.patch("/plans/\(id)", body: body, token: token)
        return response.data
    }

    func deletePlan(id: String, token: String) async throws {
        struct Empty: Codable {}
        struct Wrapper: Codable { let data: Empty }
        let _: Wrapper = try await APIService.shared.delete("/plans/\(id)", token: token)
    }

    func addItems(planId: String, items: [PlanItemBody], token: String) async throws -> [PlanItemEntry] {
        let body = AddPlanItemsBody(items: items)
        let response: PlanItemsResponse = try await APIService.shared.post("/plans/\(planId)/items", body: body, token: token)
        return response.data
    }

    func removeItem(planId: String, itemId: String, token: String) async throws {
        struct Empty: Codable {}
        struct Wrapper: Codable { let data: Empty }
        let _: Wrapper = try await APIService.shared.delete("/plans/\(planId)/items/\(itemId)", token: token)
    }

    func updateItemDay(planId: String, itemId: String, dayOffset: Int, token: String) async throws {
        struct Body: Encodable { let dayOffset: Int }
        struct ItemWrapper: Codable { let data: PlanItemEntry }
        let body = Body(dayOffset: dayOffset)
        let _: ItemWrapper = try await APIService.shared.patch("/plans/\(planId)/items/\(itemId)", body: body, token: token)
    }

    // MARK: - Collaborative plan methods

    func getMembers(planId: String, token: String) async throws -> [PlanMember] {
        let response: PlanMembersResponse = try await APIService.shared.get("/plans/\(planId)/members", token: token)
        return response.data
    }

    func inviteMembers(planId: String, userIds: [String], token: String) async throws {
        let body = InviteMembersBody(userIds: userIds)
        struct Wrapper: Codable { let data: InviteResult }
        struct InviteResult: Codable { let invited: Int }
        let _: Wrapper = try await APIService.shared.post("/plans/\(planId)/members", body: body, token: token)
    }

    func acceptInvitation(planId: String, token: String) async throws {
        struct EmptyBody: Encodable {}
        struct Wrapper: Codable { let data: StatusResult }
        struct StatusResult: Codable { let status: String }
        let _: Wrapper = try await APIService.shared.post("/plans/\(planId)/members/accept", body: EmptyBody(), token: token)
    }

    func declineInvitation(planId: String, token: String) async throws {
        struct EmptyBody: Encodable {}
        struct Wrapper: Codable { let data: StatusResult }
        struct StatusResult: Codable { let status: String }
        let _: Wrapper = try await APIService.shared.post("/plans/\(planId)/members/decline", body: EmptyBody(), token: token)
    }

    func leavePlan(planId: String, token: String) async throws {
        struct Empty: Codable {}
        struct Wrapper: Codable { let data: Empty }
        let _: Wrapper = try await APIService.shared.delete("/plans/\(planId)/members/me", token: token)
    }

    func getInvitationCount(token: String) async throws -> Int {
        let response: InvitationCountResponse = try await APIService.shared.get("/plans/invitations/count", token: token)
        return response.data.count
    }

    func getMutualFollowers(token: String) async throws -> [FollowerUser] {
        struct Wrapper: Codable { let data: [FollowerUser] }
        let response: Wrapper = try await APIService.shared.get("/users/me/mutual-followers", token: token)
        return response.data
    }
}
