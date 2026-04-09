import Foundation
import SwiftUI
import Combine

@MainActor
class AuthManager: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var token: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let api = APIService.shared
    private var sessionExpiredObserver: NSObjectProtocol?
    
    init() {
        sessionExpiredObserver = NotificationCenter.default.addObserver(
            forName: .sessionExpiredRequireLogout,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.logout()
        }
    }
    
    deinit {
        if let o = sessionExpiredObserver {
            NotificationCenter.default.removeObserver(o)
        }
    }
    
    // MARK: - Public Methods
    
    func checkStoredToken() {
        if let token = KeychainHelper.get(key: AppConfig.keychainTokenKey),
           let userData = KeychainHelper.get(key: AppConfig.keychainUserKey),
           let user = try? JSONDecoder().decode(User.self, from: Data(userData.utf8)) {
            self.token = token
            self.currentUser = user
            self.isAuthenticated = true
        }
    }
    
    func refreshTokenIfNeeded() async -> Bool {
        guard let refreshToken = KeychainHelper.get(key: AppConfig.keychainRefreshTokenKey) else {
            return false
        }
        
        do {
            let response = try await api.refreshToken(refreshToken)
            handleAuthSuccess(
                user: response.data.user,
                token: response.data.token,
                refreshToken: response.data.refreshToken
            )
            return true
        } catch {
            // Refresh failed - logout user
            logout()
            return false
        }
    }
    
    func signup(email: String, password: String, name: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await api.signup(email: email, password: password, name: name)
            handleAuthSuccess(
                user: response.data.user,
                token: response.data.token,
                refreshToken: response.data.refreshToken
            )
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        // UI test only: bypass API when --uitesting and test account credentials are used
        if ProcessInfo.processInfo.arguments.contains("--uitesting"),
           Self.isTestAccount(email: email, password: password) {
            let user = User(id: "uitest-user", email: email, name: "UI Test User", profilePictureUrl: nil, isPrivate: nil, bio: nil)
            handleAuthSuccess(user: user, token: "uitest-token", refreshToken: "uitest-refresh")
            isLoading = false
            return
        }
        
        do {
            let response = try await api.login(email: email, password: password)
            handleAuthSuccess(
                user: response.data.user,
                token: response.data.token,
                refreshToken: response.data.refreshToken
            )
        } catch let error as APIError {
            errorMessage = error.errorDescription
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    /// Test accounts used by UI tests (must match BaseTestCase.TestAccounts)
    private static func isTestAccount(email: String, password: String) -> Bool {
        let accounts: [(email: String, password: String)] = [
            ("test1@barrio.app", "TestPassword123!"),
            ("test2@barrio.app", "TestPassword123!")
        ]
        return accounts.contains { $0.email == email && $0.password == password }
    }
    
    func logout() {
        token = nil
        currentUser = nil
        isAuthenticated = false
        KeychainHelper.delete(key: AppConfig.keychainTokenKey)
        KeychainHelper.delete(key: AppConfig.keychainRefreshTokenKey)
        KeychainHelper.delete(key: AppConfig.keychainUserKey)
    }
    
    // MARK: - Private Methods
    
    private func handleAuthSuccess(user: User, token: String, refreshToken: String? = nil) {
        self.currentUser = user
        self.token = token
        self.isAuthenticated = true
        
        // Store in keychain
        KeychainHelper.set(key: AppConfig.keychainTokenKey, value: token)
        if let refreshToken = refreshToken {
            KeychainHelper.set(key: AppConfig.keychainRefreshTokenKey, value: refreshToken)
        }
        persistUserToKeychain(user)
    }

    /// Writes the given user to the keychain (same shape as after login).
    func persistUserToKeychain(_ user: User) {
        if let userData = try? JSONEncoder().encode(user),
           let userString = String(data: userData, encoding: .utf8) {
            KeychainHelper.set(key: AppConfig.keychainUserKey, value: userString)
        }
    }
}

// MARK: - Keychain Helper

enum KeychainHelper {
    nonisolated static func set(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    nonisolated static func get(key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        
        return String(data: data, encoding: .utf8)
    }
    
    nonisolated static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

