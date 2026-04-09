import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authManager: AuthManager
    
    var body: some View {
        Group {
            if authManager.isAuthenticated {
                MainTabView()
                    .accessibilityIdentifier("main_tab_view")
            } else {
                AuthView()
                    .accessibilityIdentifier("auth_view")
            }
        }
        .onAppear {
            authManager.checkStoredToken()
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager())
}

