import SwiftUI

@main
struct BarrioCursorApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var locationManager = LocationManager()
    
    init() {
        #if DEBUG
        print("📱 BarrioCursor: Starting app")
        print("📱 Network discovery: Will auto-detect server IP on first API call")
        #endif
        // Network discovery happens automatically on first API request
        // No manual IP configuration needed!
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authManager)
                .environmentObject(locationManager)
        }
    }
}


