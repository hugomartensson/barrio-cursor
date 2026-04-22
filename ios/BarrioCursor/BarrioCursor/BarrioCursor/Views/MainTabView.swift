import SwiftUI

enum AppTab: String, CaseIterable {
    case discover
    case plans
    case map
    case profile
}

// MARK: - portal· Main tab container
struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var discoverFilters = DiscoverFilters()
    @StateObject private var planNotificationManager = PlanNotificationManager()
    @State private var selectedTab: AppTab = .discover

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Discover", systemImage: "magnifyingglass", value: AppTab.discover) {
                discoverTab
            }
            Tab("Plans", systemImage: "calendar", value: AppTab.plans) {
                plansTab
            }
            .badge(planNotificationManager.pendingInvitationCount > 0 ? planNotificationManager.pendingInvitationCount : 0)
            Tab("Map", systemImage: "map", value: AppTab.map) {
                mapTab
            }
            Tab("Profile", systemImage: "person.crop.circle", value: AppTab.profile) {
                profileTab
            }
        }
        .tint(Color.portalPrimary)
        .accessibilityIdentifier("main_tab_view")
        .onAppear {
            if !ProcessInfo.processInfo.arguments.contains("--uitesting") {
                locationManager.requestPermission()
            }
            Task { await refreshBadge() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToMapTab"))) { _ in
            selectedTab = .map
        }
    }

    // MARK: - Tab content

    private var discoverTab: some View {
        DiscoverView()
            .environmentObject(locationManager)
            .environmentObject(discoverFilters)
            .accessibilityIdentifier("Discover")
    }

    private var plansTab: some View {
        PlansTabView()
            .environmentObject(authManager)
            .environmentObject(planNotificationManager)
            .accessibilityIdentifier("Plans")
    }

    private var mapTab: some View {
        MapView()
            .environmentObject(authManager)
            .environmentObject(locationManager)
            .environmentObject(discoverFilters)
            .accessibilityIdentifier("Map")
    }

    private var profileTab: some View {
        ProfileView(isTab: true)
            .environmentObject(authManager)
            .accessibilityIdentifier("Profile")
    }

    private func refreshBadge() async {
        guard let token = authManager.token, !token.isEmpty else { return }
        await planNotificationManager.refresh(token: token)
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager())
        .environmentObject(LocationManager())
}
