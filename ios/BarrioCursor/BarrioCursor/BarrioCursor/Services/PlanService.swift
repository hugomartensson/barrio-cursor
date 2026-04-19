import Foundation

// MARK: - Plan domain models

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

    static func == (lhs: PlanData, rhs: PlanData) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

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

    private static let planDateFormatter: DateFormatter = {
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
    let items: [PlanItemEntry]

    var numberOfDays: Int {
        PlanData(id: id, userId: userId, name: name, startDate: startDate, endDate: endDate,
                 itemCount: itemCount, previewImageURLs: previewImageURLs, createdAt: createdAt, updatedAt: updatedAt).numberOfDays
    }

    func date(for dayOffset: Int) -> Date? {
        PlanData(id: id, userId: userId, name: name, startDate: startDate, endDate: endDate,
                 itemCount: itemCount, previewImageURLs: previewImageURLs, createdAt: createdAt, updatedAt: updatedAt).date(for: dayOffset)
    }

    func items(for dayOffset: Int) -> [PlanItemEntry] {
        items.filter { $0.dayOffset == dayOffset }
    }

    var dateRangeLabel: String {
        PlanData(id: id, userId: userId, name: name, startDate: startDate, endDate: endDate,
                 itemCount: itemCount, previewImageURLs: previewImageURLs, createdAt: createdAt, updatedAt: updatedAt).dateRangeLabel
    }
}

nonisolated struct PlanItemEntry: Codable, Identifiable {
    let id: String
    let itemType: String   // "spot" | "event"
    let dayOffset: Int
    let order: Int
    let addedAt: String
    let spot: PlanItemSpot?
    let event: Event?
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

nonisolated struct AddPlanItemsBody: Encodable {
    let items: [PlanItemBody]
}

nonisolated struct PlanItemBody: Encodable {
    let itemType: String
    let itemId: String
    let dayOffset: Int
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
}
