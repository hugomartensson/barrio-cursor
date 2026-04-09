import Foundation

actor APIService {
    static let shared = APIService()
    
    /// When true, all network calls are skipped (UI testing mode).
    nonisolated static let isUITesting = ProcessInfo.processInfo.arguments.contains("--uitesting")
    
    private var baseURL: String? = nil
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let urlSession: URLSession
    private var isDiscovering = false
    
    private init() {
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        
        // Configure URLSession for better localhost compatibility
        // Use ephemeral configuration to avoid connection state issues in simulator
        let configuration = URLSessionConfiguration.ephemeral
        // Reasonable timeouts for uploads: 13MB video → ~17MB base64
        // At 1MB/s (slow hotspot), that's ~17s transfer + processing = 60s should be enough
        configuration.timeoutIntervalForRequest = 60  // 1 minute per chunk (enough for large uploads)
        configuration.timeoutIntervalForResource = 120  // 2 minutes total (includes network + server processing)
        configuration.waitsForConnectivity = false  // Don't wait - fail fast to avoid network stack issues
        configuration.allowsCellularAccess = true
        // Disable connection pooling and reuse to avoid network stack issues
        configuration.httpShouldUsePipelining = false
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        // Set network service type for better simulator compatibility
        configuration.networkServiceType = .default
        // Disable all caching
        configuration.urlCache = nil
        // Additional settings to help with simulator network issues
        configuration.httpShouldSetCookies = false
        configuration.httpCookieAcceptPolicy = .never
        
        urlSession = URLSession(configuration: configuration)
    }
    
    // MARK: - Base URL Management
    
    /// Get the base URL, auto-discovering if needed
    private func getBaseURL() async -> String {
        if Self.isUITesting {
            return "http://localhost:0"
        }

        if let cached = baseURL {
            return cached
        }
        
        if isDiscovering {
            try? await Task.sleep(nanoseconds: 100_000_000)
            if let cached = baseURL {
                return cached
            }
        }
        
        isDiscovering = true
        let discoveredURL = await AppConfig.getAPIBaseURL()
        baseURL = discoveredURL
        isDiscovering = false
        
        #if DEBUG
        print("🌐 APIService: Using base URL: \(discoveredURL)")
        #endif
        return discoveredURL
    }
    
    /// Reset base URL (for re-discovery)
    func resetBaseURL() {
        baseURL = nil
        #if DEBUG
        print("🔄 APIService: Base URL reset, will re-discover on next request")
        #endif
    }
    
    // MARK: - Generic Request Methods
    
    func get<T: Decodable>(_ endpoint: String, token: String? = nil) async throws -> T {
        let base = await getBaseURL()
        let request = try buildRequest(baseURL: base, endpoint: endpoint, method: "GET", token: token)
        return try await performRequest(request)
    }
    
    func post<T: Decodable, B: Encodable>(_ endpoint: String, body: B, token: String? = nil) async throws -> T {
        let base = await getBaseURL()
        var request = try buildRequest(baseURL: base, endpoint: endpoint, method: "POST", token: token)
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await performRequest(request)
    }
    
    func post<T: Decodable>(_ endpoint: String, token: String? = nil) async throws -> T {
        let base = await getBaseURL()
        let request = try buildRequest(baseURL: base, endpoint: endpoint, method: "POST", token: token)
        return try await performRequest(request)
    }
    
    func patch<T: Decodable, B: Encodable>(_ endpoint: String, body: B, token: String? = nil) async throws -> T {
        let base = await getBaseURL()
        var request = try buildRequest(baseURL: base, endpoint: endpoint, method: "PATCH", token: token)
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return try await performRequest(request)
    }
    
    func delete<T: Decodable>(_ endpoint: String, token: String? = nil) async throws -> T {
        let base = await getBaseURL()
        let request = try buildRequest(baseURL: base, endpoint: endpoint, method: "DELETE", token: token)
        return try await performRequest(request)
    }
    
    // MARK: - Private Helpers
    
    private func buildRequest(baseURL: String, endpoint: String, method: String, token: String?) throws -> URLRequest {
        guard let url = URL(string: "\(baseURL)\(endpoint)") else {
            throw APIError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        // Use longer timeout for uploads (especially /upload endpoint for videos)
        // Regular requests use 30s, uploads may need up to 60s for large videos
        request.timeoutInterval = endpoint.contains("/upload") ? 60 : 30
        
        if let token = token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
    
    private func performRequest<T: Decodable>(_ request: URLRequest, retryOn401: Bool = true, retryCount: Int = 0) async throws -> T {
        if Self.isUITesting {
            throw APIError.networkError(NSError(domain: "UITesting", code: 0, userInfo: [NSLocalizedDescriptionKey: "Network disabled during UI testing"]))
        }

        let data: Data
        let response: URLResponse
        
        do {
            #if DEBUG
            if let url = request.url {
                print("🌐 APIService: Attempting connection to \(url.absoluteString)")
            }
            #endif
            
            (data, response) = try await urlSession.data(for: request)
            
            #if DEBUG
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ APIService: Response received - Status: \(httpResponse.statusCode)")
            }
            #endif
        } catch {
            let errorDescription = error.localizedDescription
            let nsError = error as NSError
            #if DEBUG
            print("❌ APIService: Connection failed - \(errorDescription)")
            if let url = request.url {
                print("   URL: \(url.absoluteString)")
            }
            print("   Error Domain: \(nsError.domain)")
            print("   Error Code: \(nsError.code)")
            print("   Retry count: \(retryCount)")
            if nsError.code == -999 {
                print("   DIAGNOSIS: Request CANCELLED (-999). Possible causes:")
                print("   - The Task that started this request was cancelled (e.g. debounced load replaced by new one)")
                print("   - View disappeared and SwiftUI cancelled the task")
                print("   Task.isCancelled: \(Task.isCancelled)")
            }
            if errorDescription.contains("timed out") || errorDescription.contains("timeout") || nsError.code == -1001 {
                print("⚠️  DIAGNOSIS: Request timed out")
                print("   This usually means:")
                print("   1. ❌ Auto-discovery failed to find server")
                print("      → Try resetting: APIService.shared.resetBaseURL()")
                print("   2. ❌ Mac and iPhone are on different networks")
                print("      → Both must be on the same WiFi network")
                print("   3. ❌ Mac firewall blocking port 3000")
                print("      → System Settings → Network → Firewall → Options")
                print("      → Allow incoming connections for Node.js")
                print("   4. ❌ Server not running or not accessible")
                print("      → Test from Mac: curl http://localhost:3000/api/health")
                print("      → Test from iPhone Safari: http://<MAC_IP>:3000/api/health")
            }
            if let underlyingError = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
                print("   Underlying Error Code: \(underlyingError.code)")
                if let streamErrorCode = underlyingError.userInfo["_kCFStreamErrorCodeKey"] as? Int {
                    print("   Stream Error Code: \(streamErrorCode)")
                    if streamErrorCode == 61 {
                        print("⚠️  DIAGNOSIS: Connection refused (code 61)")
                        print("   - Server is not accepting connections on this port")
                        print("   - Verify server is running: curl http://127.0.0.1:3000/api/health")
                        print("   - Check if port 3000 is in use: lsof -i :3000")
                    }
                }
            }
            #endif
            
            // Reset base URL on timeout to trigger re-discovery
            if errorDescription.contains("timed out") || errorDescription.contains("timeout") || nsError.code == -1001 {
                Task {
                    await self.resetBaseURL()
                }
            }
            
            // Retry on network errors (especially socket errors in simulator)
            if retryCount < 3 && (errorDescription.contains("socket") || 
                                  errorDescription.contains("connection") ||
                                  errorDescription.contains("1004") ||
                                  errorDescription.contains("Could not connect")) {
                let delay = UInt64((retryCount + 1) * 1_000_000_000) // 1s, 2s, 3s
                #if DEBUG
                print("🔄 APIService: Retrying in \(retryCount + 1) second(s)... (\(retryCount + 1)/3)")
                #endif
                try await Task.sleep(nanoseconds: delay)
                return try await performRequest(request, retryOn401: retryOn401, retryCount: retryCount + 1)
            }
            
            #if DEBUG
            let host = request.url?.host ?? "127.0.0.1"
            print("❌ APIService: Connection failed after retries (attempt \(retryCount + 1))")
            print("   Base URL used: http://\(host):\(request.url?.port ?? 3000)")
            print("   DIAGNOSTIC CHECKLIST:")
            print("   1. Is server running? Test: curl http://\(host):3000/api/health")
            print("   2. Is server listening? Check: lsof -i :3000")
            print("   3. Simulator: localhost. Device: connect Mac to iPhone hotspot (or same Wi‑Fi), server discovers automatically")
            print("   4. Check server logs for connection attempts")
            if nsError.code == -999 {
                print("   5. -999 = cancelled: ensure map/location debounce is not cancelling the request (check MapViewModel)")
            }
            #endif
            
            throw APIError.networkError(error)
        }
        
        guard let httpResponse = response as? HTTPURLResponse else {
            #if DEBUG
            print("❌ APIService: Invalid response type")
            #endif
            throw APIError.unknown(0)
        }
        
        #if DEBUG
        print("📡 APIService: HTTP \(httpResponse.statusCode) - \(request.httpMethod ?? "?") \(request.url?.path ?? "?")")
        #endif
        
        // Handle 401 - attempt token refresh and retry
        if httpResponse.statusCode == 401 && retryOn401 {
            if let newToken = try await attemptTokenRefresh() {
                // Retry original request with new token
                var retryRequest = request
                retryRequest.setValue("Bearer \(newToken)", forHTTPHeaderField: "Authorization")
                return try await performRequest(retryRequest, retryOn401: false)
            } else {
                throw APIError.unauthorized
            }
        }
        
        // Handle other error responses
        if httpResponse.statusCode >= 400 {
            #if DEBUG
            print("❌ APIService: HTTP Error \(httpResponse.statusCode)")
            #endif
            
            // Try to decode error response for detailed diagnostics
            if let errorResponse = try? decoder.decode(APIErrorResponse.self, from: data) {
                #if DEBUG
                print("   Error Code: \(errorResponse.error.code)")
                print("   Error Message: \(errorResponse.error.message)")
                if let details = errorResponse.error.details {
                    print("   Error Details:")
                    for (key, value) in details {
                        print("     \(key): \(value)")
                    }
                }
                switch errorResponse.error.code {
                case "SERVICE_UNAVAILABLE":
                    print("⚠️  DIAGNOSIS: Supabase or external service is unreachable")
                    print("   - Check if Supabase is accessible")
                    print("   - Run GET /api/health to check service status")
                case "AUTH_ERROR":
                    print("⚠️  DIAGNOSIS: Authentication service error")
                    if let issue = errorResponse.error.details?["issue"] {
                        print("   - Issue: \(issue)")
                    }
                default:
                    break
                }
                #endif
                throw APIError.serverError(errorResponse.error)
            }
            
            if httpResponse.statusCode == 401 {
                throw APIError.unauthorized
            }
            if httpResponse.statusCode == 404 {
                throw APIError.notFound
            }
            #if DEBUG
            if httpResponse.statusCode == 503 {
                print("⚠️  DIAGNOSIS: Service unavailable (503)")
                print("   - Server is running but a dependency (Supabase/Database) is unreachable")
                print("   - Check GET /api/health for service status")
            }
            if let responseString = String(data: data, encoding: .utf8) {
                print("   Raw Response: \(responseString.prefix(200))")
            }
            #endif
            
            throw APIError.unknown(httpResponse.statusCode)
        }
        
        // Decode success response
        do {
            let decoded = try decoder.decode(T.self, from: data)
            return decoded
        } catch {
            #if DEBUG
            if let responseString = String(data: data, encoding: .utf8) {
                print("❌ APIService: Decoding failed")
                print("   Response body: \(responseString.prefix(500))")
            }
            print("   Decoding error: \(error)")
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .keyNotFound(let key, let context):
                    print("   Missing key: \(key.stringValue) at \(context.codingPath)")
                case .typeMismatch(let type, let context):
                    print("   Type mismatch: expected \(type) at \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("   Value not found: \(type) at \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("   Data corrupted at \(context.codingPath): \(context.debugDescription)")
                @unknown default:
                    print("   Unknown decoding error: \(decodingError)")
                }
            }
            #endif
            throw APIError.decodingError(error)
        }
    }
    
    // Attempt to refresh token and return new access token, or nil if refresh failed
    private func attemptTokenRefresh() async throws -> String? {
        let refreshTokenValue = KeychainHelper.get(key: AppConfig.keychainRefreshTokenKey)
        guard let refreshTokenValue = refreshTokenValue else {
            return nil
        }
        
        do {
            let response = try await self.refreshToken(refreshTokenValue)
            
            // Update Keychain with new tokens
            KeychainHelper.set(key: AppConfig.keychainTokenKey, value: response.data.token)
            if let newRefreshToken = response.data.refreshToken {
                KeychainHelper.set(key: AppConfig.keychainRefreshTokenKey, value: newRefreshToken)
            }
            
            // Update user data if available
            if let userData = try? JSONEncoder().encode(response.data.user),
               let userString = String(data: userData, encoding: .utf8) {
                KeychainHelper.set(key: AppConfig.keychainUserKey, value: userString)
            }
            
            return response.data.token
        } catch {
            // Refresh failed - clear tokens and notify so UI signs user out
            KeychainHelper.delete(key: AppConfig.keychainTokenKey)
            KeychainHelper.delete(key: AppConfig.keychainRefreshTokenKey)
            Task { @MainActor in
                NotificationCenter.default.post(name: .sessionExpiredRequireLogout, object: nil)
            }
            return nil
        }
    }
}

extension Notification.Name {
    /// Posted when the session is invalid (401 + refresh failed). AuthManager should call logout().
    static let sessionExpiredRequireLogout = Notification.Name("SessionExpiredRequireLogout")
}

// MARK: - Auth Endpoints

extension APIService {
    struct SignupRequest: Encodable {
        let email: String
        let password: String
        let name: String
    }
    
    struct LoginRequest: Encodable {
        let email: String
        let password: String
    }
    
    func signup(email: String, password: String, name: String) async throws -> AuthResponse {
        let body = SignupRequest(email: email, password: password, name: name)
        return try await post("/auth/signup", body: body)
    }
    
    func login(email: String, password: String) async throws -> AuthResponse {
        let body = LoginRequest(email: email, password: password)
        return try await post("/auth/login", body: body)
    }
    
    func getProfile(token: String) async throws -> UserProfileResponse {
        return try await get("/users/me", token: token)
    }
    
    struct RefreshRequest: Encodable {
        let refreshToken: String
    }
    
    func refreshToken(_ refreshToken: String) async throws -> AuthResponse {
        let body = RefreshRequest(refreshToken: refreshToken)
        return try await post("/auth/refresh", body: body)
    }
}

nonisolated struct UserProfileResponse: Codable {
    let data: UserProfile
}

nonisolated struct UserProfile: Codable {
    let id: String
    let email: String
    let name: String
    let profilePictureUrl: String?
    let isPrivate: Bool?
    let bio: String?
    let followerCount: Int?
    let followingCount: Int?
    /// Portal: count of Save records (saved spots + events)
    let savedCount: Int?
    /// Portal: count of collections owned by the user
    let collectionsCount: Int?
    /// Portal: same as followingCount (users the current user follows)
    let followedCount: Int?
    let handle: String?
    let initials: String?
    /// Portal: current city for profile header (from GET /users/me)
    let selectedCity: String?
}

// Portal: Saved spots (GET /users/me/saved-spots)
nonisolated struct SavedSpotsListResponse: Codable {
    let data: [SavedSpotEntry]
}
nonisolated struct SavedSpotEntry: Codable, Identifiable {
    let id: String
    let name: String
    let address: String?
    let neighborhood: String?
    let imageUrl: String?
    let saveCount: Int?
    let collectionId: String?
    let collectionName: String?
    let savedAt: String?
}

// Portal: Saved events (GET /users/me/saved-events) — server returns flat event + collection fields per item
nonisolated struct SavedEventsListResponse: Codable {
    let data: [SavedEventEntry]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let flatItems = try c.decode([FlatSavedEventItem].self, forKey: .data)
        data = flatItems.map { SavedEventEntry(event: $0.toEvent(), collectionId: $0.collectionId, collectionName: $0.collectionName, savedAt: $0.savedAt) }
    }

    private enum CodingKeys: String, CodingKey { case data }
}

/// Server returns each saved event as a flat object (event fields + collectionId, collectionName, savedAt), not nested under "event".
private struct FlatSavedEventItem: Codable {
    let id: String
    let title: String
    let description: String
    let category: String
    let address: String
    let neighborhood: String?
    let latitude: Double
    let longitude: Double
    let startTime: Date
    let endTime: Date?
    let createdAt: Date
    let saveCount: Int
    let media: [MediaItem]
    let user: EventUser
    let collectionId: String?
    let collectionName: String?
    let savedAt: String?

    func toEvent() -> Event {
        Event(
            id: id,
            title: title,
            description: description,
            category: EventCategory(rawValue: category) ?? .community,
            address: address,
            neighborhood: neighborhood,
            latitude: latitude,
            longitude: longitude,
            startTime: startTime,
            endTime: endTime,
            createdAt: createdAt,
            saveCount: saveCount,
            distance: nil,
            media: media,
            user: user
        )
    }
}

nonisolated struct SavedEventEntry: Codable {
    let event: Event
    let collectionId: String?
    let collectionName: String?
    let savedAt: String?
}

// Portal: Spots (GET /spots)
nonisolated struct SpotsListResponse: Codable {
    let data: [SpotData]
}
nonisolated struct SpotData: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let address: String
    let latitude: Double
    let longitude: Double
    let neighborhood: String?
    let categoryTag: String?
    let imageUrl: String?
    let distance: Double
    let ownerId: String
    let ownerHandle: String?
    /// Number of saves; optional in case API omits it.
    let saveCount: Int?
}

// Portal: Save/unsave collection response
nonisolated struct SaveCollectionResponse: Codable {
    let data: SaveCollectionData
}
nonisolated struct SaveCollectionData: Codable {
    let saved: Bool
}
nonisolated struct UnsaveCollectionResponse: Codable {
    let data: SaveCollectionData
}

nonisolated struct SpotSaveResponse {
    let saved: Bool
    let saveCount: Int
}

// Portal: Suggested users / People you know (GET /users/suggested)
nonisolated struct SuggestedUsersListResponse: Codable {
    let data: [SuggestedUserData]
}
nonisolated struct SuggestedUserData: Codable, Identifiable {
    let id: String
    let handle: String?
    let initials: String?
    let followerCount: Int
    let cities: [String]
    let profilePictureUrl: String?
}

// Portal: Collections
nonisolated struct CollectionResponse: Codable {
    let data: CollectionData
}
nonisolated struct CollectionsListResponse: Codable {
    let data: [CollectionData]
}

/// Response of GET /collections/:id/items (spots and events in collection order).
nonisolated struct CollectionItemsResponse: Codable {
    let data: [CollectionItemEntry]
}
nonisolated struct CollectionItemEntry: Codable {
    let itemType: String
    let addedAt: String
    let spot: CollectionItemSpotPayload?
    let event: Event?
}
/// Spot payload in collection items (matches server CollectionItemSpotPayload).
nonisolated struct CollectionItemSpotPayload: Codable {
    let id: String
    let name: String
    let description: String?
    let address: String
    let latitude: Double
    let longitude: Double
    let neighborhood: String?
    let categoryTag: String?
    let tags: [String]?
    let imageUrl: String?
    let saveCount: Int
    let distance: Double
    let ownerId: String
    let ownerHandle: String?
}

nonisolated struct CollectionData: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let userId: String?
    let itemCount: Int?
    let createdAt: String?
    let updatedAt: String?
    let visibility: String?
    let owned: Bool?
    let ownerHandle: String?
    let ownerInitials: String?
    /// PRD: approximate city for this collection (optional)
    let city: String?
    /// PRD: number of saves this collection has received (optional); var for optimistic UI updates
    var saveCount: Int?
    /// Optional cover image URL for collection detail hero
    let coverImageURL: String?
    /// Optional first few spot image URLs for collection card strip miniatures
    let previewSpotImageURLs: [String]?
}

nonisolated struct UpdateUserResponse: Codable {
    let data: UpdatedUser
}

nonisolated struct UpdatedUser: Codable {
    let id: String
    let email: String
    let name: String
    let profilePictureUrl: String?
    let isPrivate: Bool?
    let bio: String?
}

// MARK: - Events Endpoints

extension APIService {
    func getNearbyEvents(lat: Double, lng: Double, followingOnly: Bool = false, token: String) async throws -> EventsListResponse {
        var endpoint = "/events/nearby?lat=\(lat)&lng=\(lng)"
        if followingOnly {
            endpoint += "&followingOnly=true"
        }
        return try await get(endpoint, token: token)
    }
    
    func getEvent(id: String, lat: Double? = nil, lng: Double? = nil, token: String) async throws -> EventResponse {
        var endpoint = "/events/\(id)"
        if let lat = lat, let lng = lng {
            endpoint += "?lat=\(lat)&lng=\(lng)"
        }
        return try await get(endpoint, token: token)
    }
    
    func updateEvent(id: String, title: String?, description: String?, category: EventCategory?, address: String?, startTime: Date?, endTime: Date?, media: [MediaInput]?, token: String) async throws -> EventResponse {
        struct UpdateEventRequest: Encodable {
            let title: String?
            let description: String?
            let category: String?
            let address: String?
            let startTime: String?
            let endTime: String?
            let media: [MediaInput]?
            
            enum CodingKeys: String, CodingKey {
                case title, description, category, address, startTime, endTime, media
            }
        }
        
        let formatter = ISO8601DateFormatter()
        let body = UpdateEventRequest(
            title: title,
            description: description,
            category: category?.rawValue,
            address: address,
            startTime: startTime.map { formatter.string(from: $0) },
            endTime: endTime.map { formatter.string(from: $0) },
            media: media
        )
        return try await patch("/events/\(id)", body: body, token: token)
    }
    
    func deleteEvent(id: String, token: String) async throws -> SuccessResponse {
        return try await delete("/events/\(id)", token: token)
    }
    
    struct CreateEventRequest: Encodable {
        let title: String
        let description: String
        let category: String
        let address: String
        let neighborhood: String?
        let startTime: String
        let endTime: String?
        let media: [MediaInput]
    }

    struct MediaInput: Encodable {
        let url: String
        let type: String
        let thumbnailUrl: String?
    }

    func createEvent(
        title: String,
        description: String,
        category: EventCategory,
        address: String,
        neighborhood: String?,
        startTime: Date,
        endTime: Date?,
        mediaURLs: [(url: String, type: MediaType, thumbnailUrl: String?)],
        token: String
    ) async throws -> EventResponse {
        let formatter = ISO8601DateFormatter()
        let body = CreateEventRequest(
            title: title,
            description: description,
            category: category.rawValue,
            address: address,
            neighborhood: neighborhood,
            startTime: formatter.string(from: startTime),
            endTime: endTime.map { formatter.string(from: $0) },
            media: mediaURLs.map { MediaInput(url: $0.url, type: $0.type.rawValue, thumbnailUrl: $0.thumbnailUrl) }
        )
        return try await post("/events", body: body, token: token)
    }
    
    func toggleEventSave(eventId: String, token: String) async throws -> SaveResponse {
        return try await post("/events/\(eventId)/save", token: token)
    }
    
    func getMyEvents(token: String) async throws -> EventsListResponse {
        return try await get("/users/me/events", token: token)
    }
    
    func getMySavedEvents(token: String) async throws -> EventsListResponse {
        return try await get("/users/me/saved", token: token)
    }
    
    // PRD Section 7.2: Update user profile
    func updateUser(
        name: String?,
        profilePictureUrl: String?,
        isPrivate: Bool?,
        bio: String?,
        token: String
    ) async throws -> UpdateUserResponse {
        struct UpdateUserRequest: Encodable {
            let name: String?
            let profilePictureUrl: String?
            let isPrivate: Bool?
            let bio: String?
        }

        let body = UpdateUserRequest(name: name, profilePictureUrl: profilePictureUrl, isPrivate: isPrivate, bio: bio)
        return try await patch("/users/me", body: body, token: token)
    }
    
    func getUserProfile(userId: String, token: String) async throws -> UserProfileResponse {
        return try await get("/users/\(userId)", token: token)
    }
    
    func getUserEvents(userId: String, token: String) async throws -> EventsListResponse {
        return try await get("/users/\(userId)/events", token: token)
    }
    
    func getUserSavedEvents(userId: String, token: String) async throws -> EventsListResponse {
        return try await get("/users/\(userId)/saved", token: token)
    }
    
    // MARK: - Social Endpoints (Following)
    
    // PRD Section 6.1: Following System
    func followUser(userId: String, token: String) async throws -> FollowResponse {
        return try await post("/users/\(userId)/follow", token: token)
    }
    
    func unfollowUser(userId: String, token: String) async throws -> FollowResponse {
        return try await delete("/users/\(userId)/follow", token: token)
    }
    
    func getFollowers(userId: String, token: String) async throws -> FollowersListResponse {
        return try await get("/users/\(userId)/followers", token: token)
    }
    
    func getFollowing(userId: String, token: String) async throws -> FollowingListResponse {
        return try await get("/users/\(userId)/following", token: token)
    }
    
    func getFollowRequests(token: String) async throws -> FollowRequestsResponse {
        return try await get("/users/me/follow-requests", token: token)
    }

    // MARK: - Portal: Saved Spots / Saved Events

    func getSavedSpots(token: String) async throws -> SavedSpotsListResponse {
        return try await get("/users/me/saved-spots", token: token)
    }

    func getSavedEvents(token: String) async throws -> SavedEventsListResponse {
        return try await get("/users/me/saved-events", token: token)
    }

    func acceptFollowRequest(requestId: String, token: String) async throws -> SuccessResponse {
        return try await post("/follow-requests/\(requestId)/accept", token: token)
    }
    
    func declineFollowRequest(requestId: String, token: String) async throws -> SuccessResponse {
        return try await post("/follow-requests/\(requestId)/decline", token: token)
    }
    
    // MARK: - Portal: Collections

    func createCollection(name: String, description: String?, visibility: String, token: String) async throws -> CollectionResponse {
        struct CreateCollectionBody: Encodable {
            let name: String
            let description: String?
            let visibility: String
        }
        let body = CreateCollectionBody(name: name, description: description, visibility: visibility)
        return try await post("/collections", body: body, token: token)
    }

    func getCollections(token: String) async throws -> CollectionsListResponse {
        return try await get("/collections", token: token)
    }

    func getCollection(id: String, token: String) async throws -> CollectionResponse {
        return try await get("/collections/\(id)", token: token)
    }

    /// GET /collections/:id/items — spots and events in the collection (order preserved).
    func getCollectionItems(collectionId: String, token: String) async throws -> CollectionItemsResponse {
        return try await get("/collections/\(collectionId)/items", token: token)
    }

    func updateCollection(id: String, name: String?, description: String?, token: String) async throws -> CollectionResponse {
        struct UpdateCollectionBody: Encodable {
            let name: String?
            let description: String?
        }
        let body = UpdateCollectionBody(name: name, description: description)
        return try await patch("/collections/\(id)", body: body, token: token)
    }

    func deleteCollection(id: String, token: String) async throws -> SuccessResponse {
        return try await delete("/collections/\(id)", token: token)
    }

    func addItemToCollection(collectionId: String, itemType: String, itemId: String, token: String) async throws -> SuccessResponse {
        struct AddItemBody: Encodable {
            let itemType: String
            let itemId: String
        }
        let body = AddItemBody(itemType: itemType, itemId: itemId)
        return try await post("/collections/\(collectionId)/items", body: body, token: token)
    }

    func removeItemFromCollection(collectionId: String, itemId: String, token: String) async throws -> SuccessResponse {
        return try await delete("/collections/\(collectionId)/items/\(itemId)", token: token)
    }

    // Portal: Spots (Discover + Map)
    func getSpots(lat: Double, lng: Double, radius: Double = 5000, limit: Int = 20, categoryTag: String? = nil, token: String) async throws -> SpotsListResponse {
        var endpoint = "/spots?lat=\(lat)&lng=\(lng)&radius=\(radius)&limit=\(limit)"
        if let tag = categoryTag, !tag.isEmpty {
            endpoint += "&categoryTag=\(tag.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? tag)"
        }
        return try await get(endpoint, token: token)
    }

    /// POST /spots — create a new spot. Lat/lng optional; server geocodes from address when omitted (user never sees/inputs coordinates).
    nonisolated struct CreateSpotRequest: Encodable {
        let name: String
        let description: String
        let category: String
        let address: String
        let image: CreateSpotImageInput
        let neighborhood: String?
        let tags: [String]?
    }
    nonisolated struct CreateSpotImageInput: Encodable {
        let url: String
        let thumbnailUrl: String?
    }
    nonisolated struct SpotCreateResponse: Codable {
        let data: SpotData
    }
    func createSpot(
        name: String,
        description: String,
        category: String,
        address: String,
        imageURL: String,
        imageThumbnailURL: String?,
        neighborhood: String?,
        token: String
    ) async throws -> SpotCreateResponse {
        let body = CreateSpotRequest(
            name: name,
            description: description,
            category: category,
            address: address,
            image: CreateSpotImageInput(url: imageURL, thumbnailUrl: imageThumbnailURL),
            neighborhood: neighborhood,
            tags: nil
        )
        return try await post("/spots", body: body, token: token)
    }

    /// POST /spots/:id/save — toggle save on a spot. Returns current saved state and saveCount.
    func toggleSaveSpot(spotId: String, token: String) async throws -> SpotSaveResponse {
        struct SpotSaveData: Codable { let saved: Bool; let saveCount: Int }
        struct SpotSaveResponseBody: Codable { let data: SpotSaveData }
        let body: SpotSaveResponseBody = try await post("/spots/\(spotId)/save", token: token)
        return SpotSaveResponse(saved: body.data.saved, saveCount: body.data.saveCount)
    }

    // Portal: Recommended collections + save/unsave collection
    func getRecommendedCollections(lat: Double, lng: Double, radiusMeters: Double = 5000, token: String) async throws -> CollectionsListResponse {
        let q = "lat=\(lat)&lng=\(lng)&radiusM=\(radiusMeters)"
        return try await get("/collections/recommended?\(q)", token: token)
    }

    func saveCollection(collectionId: String, token: String) async throws -> SaveCollectionResponse {
        return try await post("/collections/\(collectionId)/save", token: token)
    }

    func unsaveCollection(collectionId: String, token: String) async throws -> UnsaveCollectionResponse {
        return try await delete("/collections/\(collectionId)/save", token: token)
    }

    // Portal: Suggested users (People you know)
    func getSuggestedUsers(city: String? = nil, limit: Int = 20, token: String) async throws -> SuggestedUsersListResponse {
        var endpoint = "/users/suggested?limit=\(limit)"
        if let c = city, !c.isEmpty {
            endpoint += "&city=\(c.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? c)"
        }
        return try await get(endpoint, token: token)
    }

    // MARK: - Upload Endpoint
    
    struct UploadRequest: Encodable {
        let image: String  // base64 encoded
        let contentType: String
        let duration: Double?  // Video duration in seconds (required for videos)
    }
    
    struct UploadResponse: Codable {
        struct Data: Codable {
            let url: String
            let type: String
        }
        let data: Data
    }
    
    func uploadImage(base64Image: String, contentType: String, token: String) async throws -> String {
        let body = UploadRequest(image: base64Image, contentType: contentType, duration: nil)
        let response: UploadResponse = try await post("/upload", body: body, token: token)
        return response.data.url
    }
    
    func uploadVideo(base64Video: String, contentType: String, duration: Double, token: String) async throws -> String {
        let body = UploadRequest(image: base64Video, contentType: contentType, duration: duration)
        let response: UploadResponse = try await post("/upload", body: body, token: token)
        return response.data.url
    }
    
    // MARK: - Direct Upload (Signed URLs)
    
    struct SignedUploadUrlResponse: Codable {
        struct Data: Codable {
            let uploadUrl: String
            let filePath: String
            let publicUrl: String
        }
        let data: Data
    }
    
    /// Get signed upload URL for direct upload to Supabase
    func getSignedUploadUrl(contentType: String, duration: Double?, token: String) async throws -> (uploadUrl: String, publicUrl: String) {
        var queryItems: [String] = []
        queryItems.append("contentType=\(contentType.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? contentType)")
        if let duration = duration {
            queryItems.append("duration=\(duration)")
        }
        let queryString = queryItems.joined(separator: "&")
        let endpoint = "/upload/signed-url?\(queryString)"
        
        // This is a small request, use shorter timeout
        let base = await getBaseURL()
        var request = try buildRequest(baseURL: base, endpoint: endpoint, method: "GET", token: token)
        request.timeoutInterval = 10 // 10 seconds is plenty for getting a signed URL
        
        let response: SignedUploadUrlResponse = try await performRequest(request)
        return (uploadUrl: response.data.uploadUrl, publicUrl: response.data.publicUrl)
    }
}

