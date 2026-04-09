import SwiftUI

// MARK: - portal· Main container
// Discover is the main view. No tab bar. Profile = top-right icon. Map = floating pill.

struct MainTabView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var locationManager: LocationManager
    @StateObject private var discoverFilters = DiscoverFilters()
    @State private var showMap = false

    var body: some View {
        ZStack {
            Color.portalBackground
                .ignoresSafeArea()

            DiscoverView()
                .clipped()
                .environmentObject(locationManager)
                .environmentObject(discoverFilters)
                .accessibilityIdentifier("Discover")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea(edges: .bottom)
        .accessibilityIdentifier("main_tab_view")
        .overlay(alignment: .bottomTrailing) {
            if !discoverFilters.isDetailPresented {
                portalMapPill
                    .padding(.trailing, CGFloat.portalPagePadding)
                    .padding(.bottom, 24)
            }
        }
        .onAppear {
            if !ProcessInfo.processInfo.arguments.contains("--uitesting") {
                locationManager.requestPermission()
            }
        }
        .fullScreenCover(isPresented: $showMap) {
            MapView()
                .environmentObject(authManager)
                .environmentObject(locationManager)
                .environmentObject(discoverFilters)
                .accessibilityIdentifier("Map")
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToMapTab"))) { _ in
            showMap = true
        }
    }

    private var portalMapPill: some View {
        Button {
            showMap = true
        } label: {
            Image(systemName: "map")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.portalPrimaryForeground)
                .frame(width: 44, height: 44)
                .background(Color.portalPrimary)
                .clipShape(Capsule())
                .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Map")
        .accessibilityIdentifier("map_pill")
    }
}

#Preview {
    MainTabView()
        .environmentObject(AuthManager())
}
