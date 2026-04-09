import Foundation

// Mark as nonisolated to avoid MainActor isolation warnings when used in actor contexts
nonisolated struct APIErrorResponse: Codable {
    let error: APIErrorDetail
}

nonisolated struct APIErrorDetail: Codable {
    let code: String
    let message: String
    let details: [String: String]?
}

enum APIError: LocalizedError, Equatable {
    case invalidURL
    case networkError(Error)
    case decodingError(Error)
    case serverError(APIErrorDetail)
    case unauthorized
    case notFound
    case unknown(Int)
    
    static func == (lhs: APIError, rhs: APIError) -> Bool {
        switch (lhs, rhs) {
        case (.invalidURL, .invalidURL),
             (.unauthorized, .unauthorized),
             (.notFound, .notFound):
            return true
        case (.networkError(let lhsError), .networkError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.decodingError(let lhsError), .decodingError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.serverError(let lhsDetail), .serverError(let rhsDetail)):
            return lhsDetail.code == rhsDetail.code
        case (.unknown(let lhsCode), .unknown(let rhsCode)):
            return lhsCode == rhsCode
        default:
            return false
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
        case .decodingError(let error):
            return "Failed to parse response: \(error.localizedDescription)"
        case .serverError(let detail):
            return detail.message
        case .unauthorized:
            return "Please log in again"
        case .notFound:
            return "Not found"
        case .unknown(let code):
            return "Unknown error (code: \(code))"
        }
    }
}

