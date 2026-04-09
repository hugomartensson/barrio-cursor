import Foundation

/// Centralized Save abstraction for events (and, in future, spots).
actor SaveService {
    static let shared = SaveService()
    
    struct SaveResult {
        let isSaved: Bool
        let saveCount: Int
    }
    
    private let api = APIService.shared
    
    /// Toggle save state for an event and return the updated state + count.
    func toggleEventSave(eventId: String, token: String) async throws -> SaveResult {
        let response = try await api.toggleEventSave(eventId: eventId, token: token)
        let data = response.data
        return SaveResult(isSaved: data.saved, saveCount: data.saveCount)
    }
}

