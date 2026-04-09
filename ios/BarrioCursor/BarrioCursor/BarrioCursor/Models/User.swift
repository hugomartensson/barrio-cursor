import Foundation

// Mark as nonisolated to avoid MainActor isolation warnings when used in actor contexts
nonisolated struct User: Codable, Identifiable {
    let id: String
    let email: String
    var name: String
    var profilePictureUrl: String?
    var isPrivate: Bool?
    var bio: String?

    enum CodingKeys: String, CodingKey {
        case id, email, name, bio
        case profilePictureUrl = "profilePictureUrl"
        case isPrivate = "isPrivate"
    }
}

nonisolated struct AuthResponse: Codable {
    let data: AuthData
}

nonisolated struct AuthData: Codable {
    let user: User
    let token: String
    let refreshToken: String?
    let message: String?
}

