import Foundation

enum AppConfig {
    // API Configuration
    // - Debug: auto-discovery (saved IP → simulator localhost → Bonjour → subnet scan).
    // - Release/TestFlight: set productionAPIBaseURL to your Fly.io (or other) API URL.
    //   Example: "https://your-app-name.fly.dev/api"
    //   Leave nil to fall back to discovery (e.g. internal TestFlight with dev server).
    
    /// Production API base URL. Set this for TestFlight/Release when backend is deployed (e.g. Railway).
    /// Must be HTTPS. Leave nil to use auto-discovery.
    nonisolated static let productionAPIBaseURL: String? = "https://portal-api123.fly.dev/api"
    
    /// When true, debug builds also use the production API (skips local discovery).
    /// Flip to false when you want to develop against a local server.
    nonisolated static let useProductionInDebug = true
    
    /// Get the API base URL. In Release, uses productionAPIBaseURL if set; otherwise discovery.
    nonisolated static func getAPIBaseURL() async -> String {
        #if DEBUG
        if useProductionInDebug, let prod = productionAPIBaseURL, !prod.isEmpty {
            return prod
        }
        return await NetworkDiscoveryService.shared.getAPIBaseURL()
        #else
        if let prod = productionAPIBaseURL, !prod.isEmpty {
            return prod
        }
        return await NetworkDiscoveryService.shared.getAPIBaseURL()
        #endif
    }
    
    /// Legacy static URL (fallback only)
    nonisolated static let apiBaseURL = "http://127.0.0.1:3000/api"
    
    // Supabase Configuration
    nonisolated static let supabaseURL = "https://gdrvnmvayroaamsnogpy.supabase.co"
    nonisolated static let supabaseAnonKey = "sb_publishable_Q0KYS4kX3w3ShiGO1ZORDQ_YSom4IrP"
    nonisolated static let storageBucket = "media"
    
    // Map Configuration
    nonisolated static let defaultRadiusKm: Double = 5.0
    nonisolated static let defaultLatitude: Double = 40.7128  // NYC (when location not yet available)
    nonisolated static let defaultLongitude: Double = -74.0060
    /// Fallback when location permission is denied (e.g. first-run city fallback)
    nonisolated static let fallbackLatitude: Double = 59.3293   // Stockholm
    nonisolated static let fallbackLongitude: Double = 18.0686
    
    // Keychain Keys
    nonisolated static let keychainTokenKey = "barrio_auth_token"
    nonisolated static let keychainRefreshTokenKey = "barrio_refresh_token"
    nonisolated static let keychainUserKey = "barrio_user"
}

