import Foundation

// Mark as nonisolated to avoid MainActor isolation warnings when used in actor contexts
nonisolated struct User: Codable, Identifiable {
    let id: String
    let email: String
    var name: String
    var profilePictureUrl: String?
    var isPrivate: Bool?
    var bio: String?
    var selectedCity: String?
    var cities: [String]

    enum CodingKeys: String, CodingKey {
        case id, email, name, bio
        case profilePictureUrl = "profilePictureUrl"
        case isPrivate = "isPrivate"
        case selectedCity = "selectedCity"
        case cities = "cities"
    }

    init(id: String, email: String, name: String, profilePictureUrl: String? = nil, isPrivate: Bool? = nil, bio: String? = nil, selectedCity: String? = nil, cities: [String] = []) {
        self.id = id
        self.email = email
        self.name = name
        self.profilePictureUrl = profilePictureUrl
        self.isPrivate = isPrivate
        self.bio = bio
        self.selectedCity = selectedCity
        self.cities = cities
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        email = try container.decode(String.self, forKey: .email)
        name = try container.decode(String.self, forKey: .name)
        profilePictureUrl = try container.decodeIfPresent(String.self, forKey: .profilePictureUrl)
        isPrivate = try container.decodeIfPresent(Bool.self, forKey: .isPrivate)
        bio = try container.decodeIfPresent(String.self, forKey: .bio)
        selectedCity = try container.decodeIfPresent(String.self, forKey: .selectedCity)
        cities = try container.decodeIfPresent([String].self, forKey: .cities) ?? []
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

