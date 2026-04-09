import SwiftUI
import Combine
import CoreLocation

// MARK: - Profile tab (saved items)
enum ProfileTab: String, CaseIterable {
    case collections = "Collections"
    case spots = "Spots"
    case events = "Events"
}

// For navigation to collection detail from profile
struct ProfileCollectionRoute: Identifiable, Hashable {
    let id: String
    let name: String
}

private struct ProfileSpotIdWrapper: Identifiable, Hashable {
    let id: String
}

struct ProfileView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var profileVM = ProfileViewModel()
    @State private var selectedTab: ProfileTab = .collections
    @State private var showLogoutAlert = false
    @State private var showEditProfile = false
    @State private var showCreateCollection = false
    @State private var showCreateEvent = false
    @State private var showCreateSpotPlaceholder = false
    @State private var selectedSpotIdWrapper: ProfileSpotIdWrapper?
    @State private var collectionIdPendingDelete: String?
    @State private var showDeleteCollectionConfirm = false

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    Color.clear.frame(height: 100)
                    profileHero
                    createActionsSection
                    tabBar
                    tabContent
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.portalBackground)
                .ignoresSafeArea(edges: .top)

                floatingHeader
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.portalBackground)
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: Event.self) { event in
                EventDetailView(event: event, isSaved: profileVM.savedEventIds.contains(event.id))
                    .environmentObject(authManager)
            }
            .navigationDestination(for: ProfileCollectionRoute.self) { route in
                CollectionDetailView(collectionId: route.id, name: route.name)
                    .environmentObject(authManager)
            }
            .sheet(item: $selectedSpotIdWrapper, onDismiss: { selectedSpotIdWrapper = nil }) { wrapper in
                Group {
                    if let spot = profileVM.spotItems.first(where: { $0.id == wrapper.id }) {
                        SpotDetailView(
                            spot: spot,
                            isSaved: profileVM.savedSpotIds.contains(spot.id),
                            saveCount: max(spot.saveCount, profileVM.savedSpotIds.contains(spot.id) ? 1 : 0),
                            onSaveToggle: {
                                guard let token = authManager.token else { return }
                                Task { await profileVM.toggleSaveSpot(spotId: spot.id, token: token) }
                            },
                            onDismiss: { selectedSpotIdWrapper = nil }
                        )
                        .environmentObject(authManager)
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.portalBackground)
                    }
                }
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showCreateCollection) {
                CreateCollectionView(onCreated: {
                    showCreateCollection = false
                    Task { await profileVM.loadAll(token: authManager.token) }
                })
                .environmentObject(authManager)
            }
            .sheet(isPresented: $showCreateEvent) {
                CreateEventView(onEventSaved: {
                    showCreateEvent = false
                    Task { await profileVM.loadAll(token: authManager.token) }
                })
                .environmentObject(authManager)
                .environmentObject(LocationManager())
            }
            .sheet(isPresented: $showCreateSpotPlaceholder) {
                CreateSpotView(onSpotSaved: {
                    showCreateSpotPlaceholder = false
                    Task { await profileVM.loadAll(token: authManager.token) }
                })
                .environmentObject(authManager)
                .environmentObject(LocationManager())
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileView()
                    .environmentObject(authManager)
                    .onDisappear { Task { await profileVM.loadAll(token: authManager.token) } }
            }
            .alert("Log Out", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Log Out", role: .destructive) {
                    authManager.logout()
                }
            } message: {
                Text("Are you sure you want to log out?")
            }
            .confirmationDialog(
                "Delete this collection?",
                isPresented: $showDeleteCollectionConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    if let id = collectionIdPendingDelete, let token = authManager.token {
                        Task { await profileVM.deleteCollection(id: id, token: token) }
                    }
                    collectionIdPendingDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    collectionIdPendingDelete = nil
                }
            } message: {
                Text("This cannot be undone. Items will be removed from this collection.")
            }
            .task {
                await profileVM.loadAll(token: authManager.token)
            }
            .refreshable {
                await profileVM.loadAll(token: authManager.token)
            }
        }
    }

    // MARK: - Floating header (X flush top-left, name center, gear flush top-right) — no dead gray bar
    private var floatingHeader: some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.portalForeground)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
            Text(profileVM.userName.isEmpty ? "Profile" : profileVM.userName)
                .font(.portalDisplay22)
                .foregroundColor(.portalForeground)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button {
                showLogoutAlert = true
            } label: {
                Text("Log Out")
                    .font(.portalLabel)
                    .foregroundColor(.portalMutedForeground)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Log Out")
            .accessibilityIdentifier("logout")
            Button {
                showEditProfile = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.portalForeground)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Edit Profile")
            .accessibilityIdentifier("edit_profile")
        }
        .padding(.leading, 8)
        .padding(.trailing, 8)
        .padding(.top, 44)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .background(Color.portalBackground)
    }

    // MARK: - Hero (avatar + handle, followers/following, city, description placeholder)
    private var profileHero: some View {
        HStack(alignment: .top, spacing: .portalPagePadding) {
            Group {
                if let urlString = profileVM.profilePictureUrl?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !urlString.isEmpty,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        default:
                            Circle()
                                .fill(Color.portalPrimary)
                                .overlay {
                                    Text(profileVM.userInitial)
                                        .font(.portalDisplay22)
                                        .foregroundColor(.portalPrimaryForeground)
                                }
                        }
                    }
                } else {
                    Circle()
                        .fill(Color.portalPrimary)
                        .overlay {
                            Text(profileVM.userInitial)
                                .font(.portalDisplay22)
                                .foregroundColor(.portalPrimaryForeground)
                        }
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(Circle())
            VStack(alignment: .leading, spacing: 8) {
                if let handle = profileVM.handle, !handle.isEmpty {
                    Text("@\(handle)")
                        .font(.portalMetadata)
                        .foregroundColor(.portalMutedForeground)
                }
                HStack(spacing: 16) {
                    if let myId = authManager.currentUser?.id {
                        NavigationLink(destination: FollowRequestsView(currentUserId: myId).environmentObject(authManager)) {
                            HStack(spacing: 4) {
                                Text("\(profileVM.followerCount) followers")
                                    .font(.portalMetadata)
                                    .foregroundColor(.portalForeground)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("profile_followers_link")
                        NavigationLink(destination: FollowersListView(userId: myId, isFollowers: false).environmentObject(authManager)) {
                            Text("\(profileVM.followingCount) following")
                                .font(.portalMetadata)
                                .foregroundColor(.portalForeground)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("profile_following_link")
                    } else {
                        Text("\(profileVM.followerCount) followers")
                            .font(.portalMetadata)
                            .foregroundColor(.portalForeground)
                        Text("\(profileVM.followingCount) following")
                            .font(.portalMetadata)
                            .foregroundColor(.portalForeground)
                    }
                }
                if let city = profileVM.currentCity, !city.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.system(size: 11))
                        Text(city)
                            .font(.portalMetadata)
                    }
                    .foregroundColor(.portalMutedForeground)
                }
                if let bio = profileVM.bio, !bio.isEmpty {
                    Text(bio)
                        .font(.portalMetadata)
                        .foregroundColor(.portalForeground.opacity(0.85))
                        .lineLimit(2)
                } else {
                    Button {
                        showEditProfile = true
                    } label: {
                        Text("Add a short bio")
                            .font(.portalMetadata)
                            .foregroundColor(.portalMutedForeground.opacity(0.8))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("add_bio")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
        }
        .padding(.portalPagePadding)
        .padding(.top, 8)
        .background(Color.portalBackground)
    }

    // MARK: - Create actions (Lovable-style: grid, mappin, calendar in teal circle)
    private var createActionsSection: some View {
        HStack(spacing: .portalCardGap) {
            createActionCard(icon: "square.grid.2x2", label: "COLLECTION", accessibilityId: "create_collection_action") {
                showCreateCollection = true
            }
            createActionCard(icon: "mappin", label: "SPOT", accessibilityId: "create_spot_action") {
                showCreateSpotPlaceholder = true
            }
            createActionCard(icon: "calendar", label: "EVENT", accessibilityId: "create_event_action") {
                showCreateEvent = true
            }
        }
        .padding(.horizontal, .portalPagePadding)
        .padding(.bottom, 16)
    }

    private func createActionCard(icon: String, label: String, accessibilityId: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    Image(systemName: icon)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.portalPrimaryForeground)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color.portalPrimary))
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.portalPrimaryForeground)
                        .background(Circle().fill(Color.portalPrimary))
                        .offset(x: 2, y: 2)
                }
                .frame(height: 44)
                Text(label)
                    .font(.portalSectionLabel)
                    .tracking(0.18)
                    .foregroundColor(.portalMutedForeground)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(Color.portalCard)
            .clipShape(RoundedRectangle(cornerRadius: .portalRadius))
            .contentShape(RoundedRectangle(cornerRadius: .portalRadius))
            .shadow(color: Color.portalForeground.opacity(0.05), radius: 1, x: 0, y: 1)
            .shadow(color: Color.portalForeground.opacity(0.07), radius: 6, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityIdentifier(accessibilityId ?? label)
    }

    // MARK: - Tab bar
    private var tabBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                ForEach(ProfileTab.allCases, id: \.self) { tab in
                    Button {
                        selectedTab = tab
                    } label: {
                        VStack(spacing: 8) {
                            Text(tab.rawValue)
                                .font(.portalLabelSemibold)
                                .foregroundColor(selectedTab == tab ? .portalForeground : .portalMutedForeground)
                            Rectangle()
                                .fill(selectedTab == tab ? Color.portalPrimary : Color.clear)
                                .frame(height: 2)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .accessibilityLabel(tab == .collections ? "My Collections" : (tab == .events ? "My Events" : tab.rawValue))
                    .accessibilityIdentifier(tab == .collections ? "my_collections_tab" : (tab == .events ? "my_events_tab" : "profile_tab_\(tab.rawValue)"))
                }
            }
            .padding(.horizontal, .portalPagePadding)
            .padding(.top, 8)
            .padding(.bottom, 4)
            Rectangle()
                .fill(Color.portalBorder.opacity(0.5))
                .frame(height: 1)
        }
        .background(Color.portalBackground)
    }

    // MARK: - Tab content
    @ViewBuilder
    private var tabContent: some View {
        Group {
            if profileVM.isLoading && profileVM.isEmpty {
                LoadingView(message: "Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                switch selectedTab {
                case .collections:
                    collectionsTabContent
                case .spots:
                    spotsTabContent
                case .events:
                    eventsTabContent
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var collectionsTabContent: some View {
        Group {
            if profileVM.collections.isEmpty {
                ProfileEmptyStateView(
                    icon: "bookmark",
                    title: "No collections yet",
                    subtitle: "Save or create collections to see them here."
                )
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: .portalCardGap) {
                        ForEach(profileVM.collectionItems) { item in
                            ZStack(alignment: .topTrailing) {
                                NavigationLink(value: ProfileCollectionRoute(id: item.id, name: item.title)) {
                                    PortalCollectionCard(
                                        collection: item,
                                        isSaved: profileVM.savedCollectionIds.contains(item.id) || profileVM.isCollectionOwned(item.id),
                                        onSaveToggle: nil,
                                        cardWidth: nil,
                                        isExpanded: false
                                    )
                                }
                                .buttonStyle(.plain)
                                .contentShape(Rectangle())
                                .zIndex(0)
                                let collSaved = profileVM.savedCollectionIds.contains(item.id) || profileVM.isCollectionOwned(item.id)
                                PortalSaveButton(isSaved: collSaved, count: item.saveCount ?? 0, surface: .light) {
                                    guard let token = authManager.token else { return }
                                    Task { await profileVM.toggleSaveCollection(collectionId: item.id, token: token) }
                                }
                                .padding(10)
                                .zIndex(1)
                            }
                            .contextMenu {
                                if profileVM.isCollectionOwned(item.id) {
                                    Button(role: .destructive) {
                                        collectionIdPendingDelete = item.id
                                        showDeleteCollectionConfirm = true
                                    } label: {
                                        Label("Delete collection", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, .portalPagePadding)
                    .padding(.vertical, 4)
                }
                .frame(height: 330)
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var spotsTabContent: some View {
        Group {
            if profileVM.spotItems.isEmpty {
                ProfileEmptyStateView(
                    icon: "mappin.circle",
                    title: "No saved spots yet",
                    subtitle: "Save spots from Discover to see them here."
                )
            } else {
                ScrollView {
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: .portalCardGap),
                        GridItem(.flexible(), spacing: .portalCardGap)
                    ], spacing: .portalCardGap) {
                        ForEach(profileVM.spotItems) { spot in
                            ZStack(alignment: .topTrailing) {
                                Button {
                                    selectedSpotIdWrapper = ProfileSpotIdWrapper(id: spot.id)
                                } label: {
                                    PortalSpotCard(
                                        spot: spot,
                                        cardWidth: profileGridCardWidth,
                                        isSaved: profileVM.savedSpotIds.contains(spot.id),
                                        onSaveToggle: nil
                                    )
                                }
                                .buttonStyle(.plain)
                                .zIndex(0)
                                let gridSpotSaved = profileVM.savedSpotIds.contains(spot.id)
                                PortalSaveButton(
                                    isSaved: gridSpotSaved,
                                    count: max(spot.saveCount, gridSpotSaved ? 1 : 0),
                                    surface: .light
                                ) {
                                    guard let token = authManager.token else { return }
                                    Task { await profileVM.toggleSaveSpot(spotId: spot.id, token: token) }
                                }
                                .padding(10)
                                .zIndex(1)
                            }
                        }
                    }
                    .padding(.portalPagePadding)
                    .padding(.bottom, 120)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var eventsTabContent: some View {
        Group {
            if profileVM.mergedEvents.isEmpty {
                ProfileEmptyStateView(
                    icon: "calendar.circle",
                    title: "No events yet",
                    subtitle: "Save or create events to see them here."
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: .portalCardGap) {
                        ForEach(profileVM.mergedEvents) { event in
                            ZStack(alignment: .topTrailing) {
                                NavigationLink(value: event) {
                                    PortalEventCard(
                                        event: event,
                                        isSaved: profileVM.savedEventIds.contains(event.id),
                                        onSaveToggle: nil
                                    )
                                    .environmentObject(authManager)
                                }
                                .buttonStyle(.plain)
                                let gridEventSaved = profileVM.savedEventIds.contains(event.id)
                                PortalSaveButton(isSaved: gridEventSaved, count: event.saveCount, surface: .light) {
                                    guard let token = authManager.token else { return }
                                    Task { await profileVM.toggleSaveEvent(eventId: event.id, token: token) }
                                }
                                .padding(10)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.portalPagePadding)
                    .padding(.bottom, 120)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var profileGridCardWidth: CGFloat {
        let padding = CGFloat.portalPagePadding * 2
        let gap = CGFloat.portalCardGap
        return (PortalScreenBounds.width - padding - gap) / 2
    }

}

// MARK: - Profile empty state
private struct ProfileEmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(spacing: .portalSectionSpacing) {
            Image(systemName: icon)
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.portalMutedForeground)
            Text(title)
                .font(.portalDisplay22)
                .foregroundColor(.portalForeground)
            Text(subtitle)
                .font(.portalMetadata)
                .foregroundColor(.portalMutedForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - PortalSpotItem from SavedSpotEntry (profile spots tab)
extension PortalSpotItem {
    init(from saved: SavedSpotEntry) {
        self.init(
            id: saved.id,
            name: saved.name,
            neighborhood: saved.neighborhood ?? "",
            imageURL: saved.imageUrl,
            categoryLabel: nil,
            ownerHandle: "?",
            ownerInitial: "?",
            saveCount: saved.saveCount ?? 0
        )
    }
}

// MARK: - Follow Requests & Followers (own profile: pending requests + followers list)
struct FollowRequestsView: View {
    let currentUserId: String
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = FollowRequestsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.requests.isEmpty && viewModel.followers.isEmpty {
                LoadingView(message: "Loading...")
            } else {
                List {
                    if !viewModel.requests.isEmpty {
                        Section("Follow requests") {
                            ForEach(viewModel.requests.filter { $0.status == "pending" }) { request in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(request.fromUserName)
                                            .font(.system(size: 15, weight: .medium))
                                        Text("@\(request.fromUserId)")
                                            .font(.caption)
                                            .foregroundColor(.portalMutedForeground)
                                    }
                                    Spacer()
                                    HStack(spacing: 8) {
                                        Button("Decline") {
                                            Task { await viewModel.decline(requestId: request.id, token: authManager.token) }
                                        }
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(.portalMutedForeground)
                                        Button("Accept") {
                                            Task { await viewModel.accept(requestId: request.id, token: authManager.token) }
                                        }
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.portalPrimary)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                    Section("Followers") {
                        if viewModel.followers.isEmpty && !viewModel.isLoading {
                            Text("No followers yet")
                                .font(.portalMetadata)
                                .foregroundColor(.portalMutedForeground)
                        } else {
                            ForEach(viewModel.followers) { user in
                                NavigationLink(destination: UserProfileView(userId: user.id).environmentObject(authManager)) {
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(Color.portalPrimary.opacity(0.3))
                                            .frame(width: 40, height: 40)
                                            .overlay(Text(user.name.prefix(1).uppercased()).font(.system(size: 16, weight: .semibold)).foregroundColor(.portalForeground))
                                        Text(user.name)
                                            .font(.system(size: 15))
                                    }
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .accessibilityIdentifier("follow_requests_screen")
            }
        }
        .navigationTitle("Followers")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(currentUserId: currentUserId, token: authManager.token)
        }
    }
}

@MainActor
final class FollowRequestsViewModel: ObservableObject {
    @Published var requests: [FollowRequest] = []
    @Published var followers: [FollowerUser] = []
    @Published var isLoading = false

    private let api = APIService.shared

    func load(currentUserId: String, token: String?) async {
        guard let token = token, !token.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let reqTask = api.getFollowRequests(token: token)
            async let folTask = api.getFollowers(userId: currentUserId, token: token)
            let (reqRes, folRes) = try await (reqTask, folTask)
            requests = reqRes.data
            followers = folRes.data
        } catch {
            #if DEBUG
            print("❌ FollowRequestsViewModel: \(error.localizedDescription)")
            #endif
        }
    }

    func accept(requestId: String, token: String?) async {
        guard let token = token else { return }
        do {
            _ = try await api.acceptFollowRequest(requestId: requestId, token: token)
            requests.removeAll { $0.id == requestId }
        } catch { }
    }

    func decline(requestId: String, token: String?) async {
        guard let token = token else { return }
        do {
            _ = try await api.declineFollowRequest(requestId: requestId, token: token)
            requests.removeAll { $0.id == requestId }
        } catch { }
    }
}

// MARK: - My Events View

struct MyEventsView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = MyEventsViewModel()
    @State private var showCreateEvent = false
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.events.isEmpty {
                LoadingView(message: "Loading your events...")
            } else if let error = viewModel.error {
                ErrorView(
                    error: error,
                    retry: {
                        Task {
                            await viewModel.loadEvents(token: authManager.token ?? "")
                        }
                    }
                )
            } else if viewModel.events.isEmpty {
                MyEventsEmptyStateView()
            } else {
                eventsList
            }
        }
        .navigationTitle("My Events")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateEvent = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.portalPrimary)
                }
                .accessibilityIdentifier("add")
            }
        }
        .sheet(isPresented: $showCreateEvent) {
            NavigationStack {
                CreateEventView(onEventSaved: {
                    showCreateEvent = false
                    Task { await viewModel.loadEvents(token: authManager.token ?? "") }
                })
                .environmentObject(authManager)
                .environmentObject(LocationManager())
            }
        }
        .navigationDestination(for: Event.self) { event in
            EventDetailView(event: event)
                .environmentObject(authManager)
        }
        .refreshable {
            await viewModel.loadEvents(token: authManager.token ?? "")
        }
        .task {
            await viewModel.loadEvents(token: authManager.token ?? "")
        }
        .alert("Error", isPresented: .constant(viewModel.error != nil)) {
            Button("OK") {
                viewModel.error = nil
            }
        } message: {
            if let error = viewModel.error {
                Text(error.localizedDescription)
            }
        }
    }
    
    private var eventsList: some View {
        ScrollView {
            LazyVStack(spacing: .portalSectionSpacing) {
                ForEach(viewModel.events) { event in
                    NavigationLink(value: event) {
                        PortalEventCard(event: event)
                            .environmentObject(authManager)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.portalPagePadding)
        }
    }
}

struct MyEventsEmptyStateView: View {
    var body: some View {
        VStack(spacing: .portalSectionSpacing) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.portalMutedForeground)
            
            Text("No events yet")
                .font(.portalDisplay22)
                .foregroundColor(.portalForeground)
            
            Text("Create your first event to get started!")
                .font(.portalBody)
                .foregroundColor(.portalMutedForeground)
                .multilineTextAlignment(.center)
        }
        .padding(32)
    }
}

@MainActor
class MyEventsViewModel: ObservableObject {
    @Published var events: [Event] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let api = APIService.shared
    
    func loadEvents(token: String) async {
        isLoading = true
        error = nil
        
        do {
            let response = try await api.getMyEvents(token: token)
            events = response.data
            error = nil
        } catch let err {
            error = err
            #if DEBUG
            print("❌ MyEventsViewModel: Error loading events: \(err.localizedDescription)")
            #endif
        }
        
        isLoading = false
    }
}

// MARK: - Profile ViewModel (loads collections, saved spots, saved + owned events)
@MainActor
class ProfileViewModel: ObservableObject {
    @Published var userName: String = ""
    @Published var userInitial: String = "?"
    @Published var profilePictureUrl: String?
    @Published var handle: String?
    @Published var currentCity: String?
    @Published var bio: String?
    @Published var followerCount: Int = 0
    @Published var followingCount: Int = 0
    @Published var collections: [CollectionData] = []
    @Published var savedSpots: [SavedSpotEntry] = []
    @Published var savedEvents: [SavedEventEntry] = []
    @Published var ownedEvents: [Event] = []
    @Published var savedCollectionIds: Set<String> = []
    @Published var savedSpotIds: Set<String> = []
    @Published var savedEventIds: Set<String> = []
    @Published var isLoading: Bool = false
    @Published var error: Error?

    private let api = APIService.shared

    var collectionItems: [PortalCollectionItem] {
        collections.map { PortalCollectionItem(from: $0) }
    }

    var spotItems: [PortalSpotItem] {
        savedSpots.map { PortalSpotItem(from: $0) }
    }

    /// Merged saved + owned events, deduplicated by id, most recent first
    var mergedEvents: [Event] {
        var byId: [String: Event] = [:]
        for entry in savedEvents {
            byId[entry.event.id] = entry.event
        }
        for event in ownedEvents {
            byId[event.id] = event
        }
        return byId.values.sorted { $0.startTime > $1.startTime }
    }

    var isEmpty: Bool {
        collections.isEmpty && savedSpots.isEmpty && savedEvents.isEmpty && ownedEvents.isEmpty
    }

    func isCollectionOwned(_ collectionId: String) -> Bool {
        collections.first(where: { $0.id == collectionId })?.owned == true
    }

    func loadAll(token: String?) async {
        guard let token = token, !token.isEmpty else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            async let profileTask = api.getProfile(token: token)
            async let collectionsTask = api.getCollections(token: token)
            async let savedSpotsTask = api.getSavedSpots(token: token)
            async let savedEventsTask = api.getSavedEvents(token: token)
            async let ownedEventsTask = api.getMyEvents(token: token)

            let (profileRes, collectionsRes, spotsRes, eventsRes, myEventsRes) = try await (
                profileTask, collectionsTask, savedSpotsTask, savedEventsTask, ownedEventsTask
            )

            userName = profileRes.data.name
            userInitial = profileRes.data.initials.flatMap { $0.prefix(1).uppercased() } ?? String(profileRes.data.name.prefix(1)).uppercased()
            profilePictureUrl = profileRes.data.profilePictureUrl
            handle = profileRes.data.handle
            currentCity = profileRes.data.selectedCity
            bio = profileRes.data.bio
            followerCount = profileRes.data.followerCount ?? 0
            followingCount = profileRes.data.followingCount ?? 0

            collections = collectionsRes.data
            savedCollectionIds = Set(collectionsRes.data.filter { $0.owned == false }.map { $0.id })
            savedSpots = spotsRes.data
            savedSpotIds = Set(spotsRes.data.map { $0.id })
            savedEvents = eventsRes.data
            savedEventIds = Set(eventsRes.data.map { $0.event.id })
            ownedEvents = myEventsRes.data
        } catch let err {
            self.error = err
        }
    }

    func toggleSaveCollection(collectionId: String, token: String) async {
        let isOwned = collections.first(where: { $0.id == collectionId })?.owned == true
        if isOwned {
            return
        }
        let isSaved = savedCollectionIds.contains(collectionId)
        do {
            if isSaved {
                _ = try await api.unsaveCollection(collectionId: collectionId, token: token)
                savedCollectionIds.remove(collectionId)
                if let idx = collections.firstIndex(where: { $0.id == collectionId }) {
                    var updated = collections[idx]
                    updated.saveCount = max(0, (updated.saveCount ?? 0) - 1)
                    collections[idx] = updated
                }
            } else {
                _ = try await api.saveCollection(collectionId: collectionId, token: token)
                savedCollectionIds.insert(collectionId)
                if let idx = collections.firstIndex(where: { $0.id == collectionId }) {
                    var updated = collections[idx]
                    updated.saveCount = (updated.saveCount ?? 0) + 1
                    collections[idx] = updated
                }
            }
        } catch { }
    }

    func deleteCollection(id: String, token: String) async {
        do {
            _ = try await api.deleteCollection(id: id, token: token)
            collections.removeAll { $0.id == id }
            savedCollectionIds.remove(id)
        } catch {
            self.error = error
        }
    }

    func toggleSaveSpot(spotId: String, token: String) async {
        do {
            let response = try await api.toggleSaveSpot(spotId: spotId, token: token)
            if response.saved {
                savedSpotIds.insert(spotId)
            } else {
                savedSpotIds.remove(spotId)
            }
        } catch { }
    }

    func toggleSaveEvent(eventId: String, token: String) async {
        do {
            let result = try await SaveService.shared.toggleEventSave(eventId: eventId, token: token)
            if result.isSaved {
                savedEventIds.insert(eventId)
            } else {
                savedEventIds.remove(eventId)
            }
        } catch { }
    }
}

@MainActor
class FollowingViewModel: ObservableObject {
    @Published var users: [FollowerUser] = []
    
    private let api = APIService.shared
    
    func loadFollowing(userId: String, token: String) async {
        guard !token.isEmpty else { return }
        do {
            let response = try await api.getFollowing(userId: userId, token: token)
            users = response.data
        } catch {
            // Keep previous list on error
        }
    }
}

// MARK: - Saved Spots View (portal· — GET /users/me/saved-spots)
struct SavedSpotsView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = SavedSpotsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.spots.isEmpty {
                LoadingView(message: "Loading saved spots...")
            } else if let error = viewModel.error {
                ErrorView(
                    error: error,
                    retry: {
                        Task {
                            await viewModel.load(token: authManager.token ?? "")
                        }
                    }
                )
            } else if viewModel.spots.isEmpty {
                VStack(spacing: .portalSectionSpacing) {
                    Image(systemName: "mappin.circle")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.portalMutedForeground)
                    Text("No saved spots yet")
                        .font(.portalDisplay22)
                        .foregroundColor(.portalForeground)
                    Text("Save spots from Discover to see them here.")
                        .font(.portalMetadata)
                        .foregroundColor(.portalMutedForeground)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: .portalCardGap) {
                        ForEach(viewModel.spots) { spot in
                            SavedSpotRowView(entry: spot)
                        }
                    }
                    .padding(.portalPagePadding)
                }
            }
        }
        .navigationTitle("Saved Spots")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.load(token: authManager.token ?? "")
        }
        .refreshable {
            await viewModel.load(token: authManager.token ?? "")
        }
    }
}

private struct SavedSpotRowView: View {
    let entry: SavedSpotEntry

    var body: some View {
        HStack(spacing: .portalPagePadding) {
            RoundedRectangle(cornerRadius: .portalRadius)
                .fill(Color.portalMuted)
                .frame(width: 56, height: 56)
                .overlay(
                    AsyncImage(url: URL(string: entry.imageUrl ?? "")) { _ in } placeholder: {
                        Image(systemName: "fork.knife")
                            .foregroundColor(.portalMutedForeground)
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: .portalRadius))
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.name)
                    .font(.portalLabel)
                    .foregroundColor(.portalForeground)
                Text(entry.neighborhood ?? entry.address ?? "")
                    .font(.portalMetadata)
                    .foregroundColor(.portalMutedForeground)
            }
            Spacer(minLength: 0)
            if let name = entry.collectionName {
                Text(name)
                    .font(.portalMetadata)
                    .foregroundColor(.portalMutedForeground)
            }
        }
        .padding(.portalPagePadding)
        .background(Color.portalCard)
        .clipShape(RoundedRectangle(cornerRadius: .portalRadius))
        .shadow(color: Color.portalForeground.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}

@MainActor
class SavedSpotsViewModel: ObservableObject {
    @Published var spots: [SavedSpotEntry] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let api = APIService.shared

    func load(token: String) async {
        guard !token.isEmpty else { return }
        isLoading = true
        error = nil
        do {
            let response = try await api.getSavedSpots(token: token)
            spots = response.data
        } catch let err {
            error = err
        }
        isLoading = false
    }
}

// MARK: - Saved Events View (portal· — GET /users/me/saved-events)
struct SavedEventsView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = SavedEventsViewModel()

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.entries.isEmpty {
                LoadingView(message: "Loading saved events...")
            } else if let error = viewModel.error {
                ErrorView(
                    error: error,
                    retry: {
                        Task {
                            await viewModel.load(token: authManager.token ?? "")
                        }
                    }
                )
            } else if viewModel.entries.isEmpty {
                VStack(spacing: .portalSectionSpacing) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.portalMutedForeground)
                    Text("No saved events yet")
                        .font(.portalDisplay22)
                        .foregroundColor(.portalForeground)
                    Text("Save events from Discover to see them here.")
                        .font(.portalMetadata)
                        .foregroundColor(.portalMutedForeground)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: .portalCardGap) {
                        ForEach(viewModel.entries, id: \.event.id) { entry in
                            NavigationLink(value: entry.event) {
                                PortalEventCard(event: entry.event)
                                    .environmentObject(authManager)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.portalPagePadding)
                }
            }
        }
        .navigationTitle("Saved Events")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Event.self) { event in
            EventDetailView(event: event, isSaved: true)
                .environmentObject(authManager)
        }
        .task {
            await viewModel.load(token: authManager.token ?? "")
        }
        .refreshable {
            await viewModel.load(token: authManager.token ?? "")
        }
    }
}

// MARK: - My Saves (mixed events + spots)

struct MySavesView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = MySavesViewModel()
    
    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.entries.isEmpty {
                LoadingView(message: "Loading saved items...")
            } else if let error = viewModel.error {
                ErrorView(
                    error: error,
                    retry: {
                        Task {
                            await viewModel.load(token: authManager.token ?? "")
                        }
                    }
                )
            } else if viewModel.entries.isEmpty {
                VStack(spacing: .portalSectionSpacing) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.portalMutedForeground)
                    Text("No saved items yet")
                        .font(.portalDisplay22)
                        .foregroundColor(.portalForeground)
                    Text("Save spots and events from Discover to see them here.")
                        .font(.portalMetadata)
                        .foregroundColor(.portalMutedForeground)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: .portalCardGap) {
                        ForEach(viewModel.entries) { entry in
                            switch entry.kind {
                            case .spot(let spot):
                                SavedSpotRowView(entry: spot)
                            case .event(let savedEvent):
                                NavigationLink(value: savedEvent.event) {
                                    PortalEventCard(event: savedEvent.event)
                                        .environmentObject(authManager)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.portalPagePadding)
                }
            }
        }
        .navigationTitle("My Saves")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Event.self) { event in
            EventDetailView(event: event, isSaved: true)
                .environmentObject(authManager)
        }
        .task {
            await viewModel.load(token: authManager.token ?? "")
        }
        .refreshable {
            await viewModel.load(token: authManager.token ?? "")
        }
    }
}

struct MySaveEntry: Identifiable {
    enum Kind {
        case spot(SavedSpotEntry)
        case event(SavedEventEntry)
    }
    
    let id: String
    let savedAt: Date?
    let kind: Kind
}

@MainActor
class MySavesViewModel: ObservableObject {
    @Published var entries: [MySaveEntry] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let api = APIService.shared
    
    func load(token: String) async {
        guard !token.isEmpty else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        
        let formatter = ISO8601DateFormatter()
        
        do {
            async let spotsResponse = api.getSavedSpots(token: token)
            async let eventsResponse = api.getSavedEvents(token: token)
            
            let (spots, events) = try await (spotsResponse, eventsResponse)
            
            var combined: [MySaveEntry] = []
            
            combined.append(contentsOf: spots.data.map { spot in
                let date = spot.savedAt.flatMap { formatter.date(from: $0) }
                return MySaveEntry(
                    id: "spot-\(spot.id)",
                    savedAt: date,
                    kind: .spot(spot)
                )
            })
            
            combined.append(contentsOf: events.data.map { entry in
                let date = entry.savedAt.flatMap { formatter.date(from: $0) }
                return MySaveEntry(
                    id: "event-\(entry.event.id)",
                    savedAt: date,
                    kind: .event(entry)
                )
            })
            
            entries = combined.sorted { (a, b) in
                switch (a.savedAt, b.savedAt) {
                case let (d1?, d2?): return d1 > d2
                case (_?, nil): return true
                case (nil, _?): return false
                default: return a.id < b.id
                }
            }
        } catch {
            self.error = error
        }
    }
}

@MainActor
class SavedEventsViewModel: ObservableObject {
    @Published var entries: [SavedEventEntry] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let api = APIService.shared

    func load(token: String) async {
        guard !token.isEmpty else { return }
        isLoading = true
        error = nil
        do {
            let response = try await api.getSavedEvents(token: token)
            entries = response.data
        } catch let err {
            error = err
        }
        isLoading = false
    }
}

// MARK: - My Collections View (portal· — GET /collections, CRUD)
struct MyCollectionsView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = MyCollectionsViewModel()
    @State private var showCreateCollection = false

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.collections.isEmpty {
                LoadingView(message: "Loading collections...")
            } else if let error = viewModel.error {
                ErrorView(
                    error: error,
                    retry: {
                        Task {
                            await viewModel.load(token: authManager.token ?? "")
                        }
                    }
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: .portalCardGap) {
                        ForEach(viewModel.collections) { col in
                            NavigationLink {
                                CollectionDetailView(collectionId: col.id, name: col.name)
                            } label: {
                                HStack(spacing: .portalPagePadding) {
                                    Image(systemName: "folder.fill")
                                        .font(.title2)
                                        .foregroundColor(.portalPrimary)
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 8) {
                                            Text(col.name)
                                                .font(.portalLabel)
                                                .foregroundColor(.portalForeground)
                                            if let vis = col.visibility {
                                                Text(visibilityBadgeLabel(vis))
                                                    .font(.portalSectionLabel)
                                                    .tracking(0.18)
                                                    .foregroundColor(.portalMutedForeground)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.portalMuted)
                                                    .clipShape(Capsule())
                                            }
                                        }
                                        HStack(spacing: 8) {
                                            if let count = col.itemCount {
                                                Text("\(count) items")
                                                    .font(.portalMetadata)
                                                    .foregroundColor(.portalMutedForeground)
                                            }
                                            if let saves = col.saveCount, saves > 0 {
                                                Text("·")
                                                    .foregroundColor(.portalMutedForeground)
                                                Text("\(saves) saves")
                                                    .font(.portalMetadata)
                                                    .foregroundColor(.portalMutedForeground)
                                            }
                                        }
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundColor(.portalMutedForeground)
                                }
                                .padding(.portalPagePadding)
                                .background(Color.portalCard)
                                .clipShape(RoundedRectangle(cornerRadius: .portalRadius))
                                .shadow(color: Color.portalForeground.opacity(0.05), radius: 1, x: 0, y: 1)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.portalPagePadding)
                }
            }
        }
        .navigationTitle("My Collections")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showCreateCollection = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.portalPrimary)
                }
                .accessibilityIdentifier("add_collection")
            }
        }
        .sheet(isPresented: $showCreateCollection) {
            CreateCollectionView(onCreated: {
                showCreateCollection = false
                Task { await viewModel.load(token: authManager.token ?? "") }
            })
            .environmentObject(authManager)
        }
        .task {
            await viewModel.load(token: authManager.token ?? "")
        }
        .refreshable {
            await viewModel.load(token: authManager.token ?? "")
        }
    }

    private func visibilityBadgeLabel(_ vis: String) -> String {
        switch vis.lowercased() {
        case "private": return "Private"
        case "friends": return "Friends"
        case "public": return "Public"
        default: return vis
        }
    }
}

private enum CollectionVisibility: String, CaseIterable {
    case private_ = "private"
    case friends = "friends"
    case public_ = "public"
    var label: String {
        switch self {
        case .private_: return "Private"
        case .friends: return "Friends"
        case .public_: return "Public"
        }
    }
}

// MARK: - Collection Detail (editorial 16:10 hero, description, curator, spot list — no number badges on cards)
struct CollectionDetailView: View {
    let collectionId: String
    let name: String
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: CollectionDetailViewModel

    init(collectionId: String, name: String) {
        self.collectionId = collectionId
        self.name = name
        _viewModel = StateObject(wrappedValue: CollectionDetailViewModel(collectionId: collectionId, initialName: name))
    }

    private let heroAspectRatio: CGFloat = 16/10
    private let bodyVerticalSpacing: CGFloat = 20

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.collection == nil {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        heroSection
                        bodySection
                    }
                }
            }
        }
        .background(Color.portalBackground)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: PortalSpotItem.self) { spot in
            SpotDetailView(
                spot: spot,
                isSaved: viewModel.savedSpotIds.contains(spot.id),
                saveCount: max(spot.saveCount, viewModel.savedSpotIds.contains(spot.id) ? 1 : 0),
                onSaveToggle: {
                    guard let token = authManager.token else { return }
                    Task { await viewModel.toggleSpotSave(spotId: spot.id, token: token) }
                }
            )
            .environmentObject(authManager)
        }
        .navigationDestination(for: Event.self) { event in
            EventDetailView(event: event, isSaved: false)
                .environmentObject(authManager)
        }
        .task {
            await viewModel.load(token: authManager.token)
        }
        .refreshable {
            await viewModel.load(token: authManager.token)
        }
    }

    // MARK: - Hero (16:10, editorial)
    private var heroSection: some View {
        let c = viewModel.collection
        let titleText = c?.name ?? name
        return GeometryReader { geo in
            let w = geo.size.width
            let h = w / heroAspectRatio
            ZStack(alignment: .top) {
                collectionHeroImage
                    .frame(width: w, height: h)
                    .clipped()
                collectionHeroGradient
                    .frame(width: w, height: h)
                    .allowsHitTesting(false)
                VStack {
                    collectionHeroTopBar
                        .padding(.horizontal, .portalPagePadding)
                        .padding(.top, 16 + geo.safeAreaInsets.top)
                    Spacer(minLength: 0)
                    collectionHeroBottomBlock(title: titleText)
                        .padding(.horizontal, .portalPagePadding)
                        .padding(.bottom, 16)
                }
                .frame(width: w, height: h)
            }
        }
        .aspectRatio(heroAspectRatio, contentMode: .fit)
        .ignoresSafeArea(edges: .top)
    }

    private var collectionHeroImage: some View {
        Group {
            if let urlString = viewModel.collection?.coverImageURL.flatMap({ $0.isEmpty ? nil : $0 }),
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    default:
                        collectionHeroPlaceholder
                    }
                }
            } else {
                collectionHeroPlaceholder
            }
        }
    }

    private var collectionHeroPlaceholder: some View {
        LinearGradient(
            colors: [Color.portalPrimary.opacity(0.4), Color.portalPrimary.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var collectionHeroGradient: some View {
        LinearGradient(
            colors: [
                Color.portalForeground.opacity(0.25),
                Color.portalForeground.opacity(0),
                Color.portalForeground.opacity(0.7)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var collectionHeroTopBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.portalForeground)
                    .frame(width: 36, height: 36)
                    .background(.ultraThinMaterial, in: Circle())
                    .overlay(Circle().stroke(Color.portalBorder.opacity(0.5), lineWidth: 1))
            }
            .buttonStyle(.plain)
            Spacer(minLength: 0)
            PortalSaveButton(isSaved: viewModel.isSaved, count: viewModel.collection?.saveCount ?? 0, surface: .dark) {
                Task { await viewModel.toggleSave(token: authManager.token) }
            }
        }
    }

    private func collectionHeroBottomBlock(title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.portalDisplay22)
                .foregroundColor(.white)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Body
    private var bodySection: some View {
        VStack(alignment: .leading, spacing: bodyVerticalSpacing) {
            if let desc = viewModel.collection?.description, !desc.isEmpty {
                Text(desc)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.portalForeground.opacity(0.85))
                    .lineSpacing(4)
            }
            Divider().background(Color.portalBorder)
            curatorRow
            Divider().background(Color.portalBorder)
            placesSection
        }
        .padding(.horizontal, .portalPagePadding)
        .padding(.top, 20)
        .padding(.bottom, 32)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var curatorRow: some View {
        let c = viewModel.collection
        let ownerHandle = c?.ownerHandle ?? "?"
        let ownerInitial = c?.ownerInitials.flatMap { $0.prefix(1).uppercased() } ?? String(ownerHandle.prefix(1)).uppercased()
        let saveCount = viewModel.collection?.saveCount ?? 0
        let itemCount = viewModel.collectionItems.count
        return HStack(spacing: 12) {
            Circle()
                .fill(Color.portalPrimary)
                .frame(width: 40, height: 40)
                .overlay(
                    Text(ownerInitial)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.portalPrimaryForeground)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(ownerHandle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.portalForeground)
                Text("@\(ownerHandle)")
                    .font(.system(size: 11))
                    .foregroundColor(.portalMutedForeground)
            }
            Spacer(minLength: 0)
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Image(systemName: "bookmark")
                        .font(.system(size: 12))
                    Text("\(saveCount)")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.portalMutedForeground)
                HStack(spacing: 4) {
                    Image(systemName: "mappin")
                        .font(.system(size: 12))
                    Text("\(itemCount) items")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(.portalMutedForeground)
            }
        }
    }

    private var placesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("ITEMS IN THIS COLLECTION")
                .font(.portalSectionLabel)
                .tracking(2)
                .foregroundColor(.portalMutedForeground)
            ForEach(viewModel.collectionItems) { item in
                switch item {
                case .spot(let spot):
                    NavigationLink(value: spot) {
                        CollectionSpotRowCard(
                            spot: spot,
                            isSaved: viewModel.savedSpotIds.contains(spot.id),
                            saveCount: max(spot.saveCount, viewModel.savedSpotIds.contains(spot.id) ? 1 : 0),
                            onSaveToggle: {
                                guard let token = authManager.token else { return }
                                Task { await viewModel.toggleSpotSave(spotId: spot.id, token: token) }
                            }
                        )
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if viewModel.collection?.owned == true {
                            Button(role: .destructive) {
                                Task { await viewModel.removeItem(itemId: spot.id, token: authManager.token) }
                            } label: { Label("Remove", systemImage: "trash") }
                        }
                    }
                case .event(let event):
                    NavigationLink(value: event) {
                        CollectionEventRowCard(event: event)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if viewModel.collection?.owned == true {
                            Button(role: .destructive) {
                                Task { await viewModel.removeItem(itemId: event.id, token: authManager.token) }
                            } label: { Label("Remove", systemImage: "trash") }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Spot row card in collection (thumbnail, neighborhood, discover-category tags only, mutuals, save)
private struct CollectionSpotRowCard: View {
    let spot: PortalSpotItem
    let isSaved: Bool
    let saveCount: Int
    let onSaveToggle: () -> Void

    private let thumbAspect: CGFloat = 3/4
    private let thumbHeight: CGFloat = 88

    /// Tags that match discover filter categories only
    private var discoverTags: [String] {
        spot.tags.filter { DiscoverCategory(rawValue: $0.lowercased()) != nil }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            thumbnail
                .frame(width: thumbHeight * (3/4), height: thumbHeight)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))

            VStack(alignment: .leading, spacing: 6) {
                Text(spot.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.portalForeground)
                HStack(spacing: 6) {
                    Image(systemName: "mappin")
                        .font(.system(size: 10))
                    Text(spot.neighborhood)
                        .font(.system(size: 11))
                }
                .foregroundColor(.portalMutedForeground)
                if !discoverTags.isEmpty {
                    discoverTagPills
                }
                HStack(spacing: 6) {
                    mutualsAvatarStack
                    mutualsText
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Spacer(minLength: 0)
            PortalSaveButton(isSaved: isSaved, count: saveCount, surface: .light, action: onSaveToggle)
        }
        .padding(12)
        .background(Color.portalCard)
        .clipShape(RoundedRectangle(cornerRadius: .portalRadius))
        .overlay(RoundedRectangle(cornerRadius: .portalRadius).stroke(Color.portalBorder, lineWidth: 1))
    }

    private var discoverTagPills: some View {
        HStack(spacing: 4) {
            ForEach(discoverTags, id: \.self) { tag in
                Text(DiscoverCategory(rawValue: tag.lowercased())?.label ?? tag.capitalized)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.categoryPillColor(for: tag).opacity(0.2))
                    .foregroundColor(.portalForeground)
                    .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))
            }
        }
    }

    private var thumbnail: some View {
        Group {
            if let urlString = spot.imageURL, !urlString.isEmpty, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Rectangle().fill(Color.portalMuted)
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.portalMuted)
                    .overlay(Image(systemName: "fork.knife").font(.caption).foregroundColor(.portalMutedForeground))
            }
        }
    }

    private var mutualsAvatarStack: some View {
        let friends = Array(spot.friendsWhoSaved.prefix(3))
        return HStack(spacing: -8) {
            ForEach(Array(friends.enumerated()), id: \.offset) { _, f in
                Circle()
                    .fill(Color.portalSecondary)
                    .frame(width: 22, height: 22)
                    .overlay(Text(f.initials).font(.system(size: 9, weight: .semibold)).foregroundColor(.portalForeground))
                    .overlay(Circle().stroke(Color.portalBackground, lineWidth: 1))
            }
        }
    }

    @ViewBuilder
    private var mutualsText: some View {
        if spot.friendsWhoSaved.isEmpty {
            Text("0 saved")
                .font(.system(size: 11))
                .foregroundColor(.portalMutedForeground)
        } else {
            let names = spot.friendsWhoSaved.prefix(2).map(\.name).joined(separator: ", ")
            let more = spot.friendsWhoSaved.count > 2 ? " + \(spot.friendsWhoSaved.count - 2) saved" : " saved"
            HStack(spacing: 0) {
                Text(names)
                    .font(.system(size: 11))
                    .fontWeight(.medium)
                    .foregroundColor(.portalForeground)
                Text(more)
                    .font(.system(size: 11))
                    .foregroundColor(.portalMutedForeground)
            }
        }
    }
}

// MARK: - Event row card in collection detail (compact: title, date, category)
private struct CollectionEventRowCard: View {
    let event: Event
    private let thumbHeight: CGFloat = 88
    private let thumbAspect: CGFloat = 3/4

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            eventThumbnail
                .frame(width: thumbHeight * (3/4), height: thumbHeight)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))
            VStack(alignment: .leading, spacing: 6) {
                Text(event.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.portalForeground)
                Text(event.startTime.formatted(date: .abbreviated, time: .shortened))
                    .font(.system(size: 11))
                    .foregroundColor(.portalMutedForeground)
                Text(event.category.displayName)
                    .font(.system(size: 10, weight: .medium))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.categoryPillColor(for: event.category.rawValue).opacity(0.2))
                    .foregroundColor(.portalForeground)
                    .clipShape(RoundedRectangle(cornerRadius: .portalRadiusSm))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(Color.portalCard)
        .clipShape(RoundedRectangle(cornerRadius: .portalRadius))
        .overlay(RoundedRectangle(cornerRadius: .portalRadius).stroke(Color.portalBorder, lineWidth: 1))
    }

    private var eventThumbnail: some View {
        Group {
            if let urlString = event.media.first?.url, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fill)
                    default:
                        Rectangle().fill(Color.portalMuted)
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.portalMuted)
                    .overlay(Image(systemName: "calendar").font(.caption).foregroundColor(.portalMutedForeground))
            }
        }
    }
}

private func collectionSpotCategoryLabel(_ raw: String) -> String {
    DiscoverCategory(rawValue: raw.lowercased())?.label ?? raw.capitalized
}

/// One item in a collection (spot or event) for ordered display.
enum CollectionRowItem: Identifiable {
    case spot(PortalSpotItem)
    case event(Event)
    var id: String {
        switch self {
        case .spot(let s): return s.id
        case .event(let e): return e.id
        }
    }
}

// MARK: - Collection Detail ViewModel
@MainActor
final class CollectionDetailViewModel: ObservableObject {
    @Published var collection: CollectionData?
    @Published var spotItems: [PortalSpotItem] = []
    @Published var savedSpotIds: Set<String> = []
    @Published var isLoading = false
    @Published var isSaved = false
    /// Ordered list of spots and events in the collection (from GET /collections/:id/items).
    @Published var collectionItems: [CollectionRowItem] = []

    private let collectionId: String
    private let initialName: String
    private let api = APIService.shared

    init(collectionId: String, initialName: String) {
        self.collectionId = collectionId
        self.initialName = initialName
    }

    func load(token: String?) async {
        guard let token = token, !token.isEmpty else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            async let collectionTask = api.getCollection(id: collectionId, token: token)
            async let savedSpotsTask = api.getSavedSpots(token: token)
            async let itemsTask = api.getCollectionItems(collectionId: collectionId, token: token)
            let (collectionResponse, savedSpotsResponse, itemsResponse) = try await (collectionTask, savedSpotsTask, itemsTask)
            collection = collectionResponse.data
            isSaved = false
            savedSpotIds = Set(savedSpotsResponse.data.map(\.id))
            collectionItems = itemsResponse.data.compactMap { entry -> CollectionRowItem? in
                if let payload = entry.spot {
                    let spot = Spot(
                        id: payload.id,
                        name: payload.name,
                        neighborhood: payload.neighborhood ?? payload.address,
                        description: payload.description,
                        imageUrl: payload.imageUrl,
                        location: CLLocationCoordinate2D(latitude: payload.latitude, longitude: payload.longitude),
                        tags: payload.tags ?? [],
                        owners: [SpotOwner(id: payload.ownerId, handle: payload.ownerHandle, initials: payload.ownerHandle.map { String($0.prefix(1)).uppercased() } ?? "?")],
                        saveCount: payload.saveCount
                    )
                    return .spot(PortalSpotItem(from: spot))
                }
                if let ev = entry.event {
                    return .event(ev)
                }
                return nil
            }
            spotItems = collectionItems.compactMap { if case .spot(let s) = $0 { return s }; return nil }
        } catch {
            collection = CollectionData(
                id: collectionId,
                name: initialName,
                description: nil,
                userId: nil,
                itemCount: nil,
                createdAt: nil,
                updatedAt: nil,
                visibility: nil,
                owned: nil,
                ownerHandle: nil,
                ownerInitials: nil,
                city: nil,
                saveCount: nil,
                coverImageURL: nil,
                previewSpotImageURLs: nil
            )
            collectionItems = []
            spotItems = []
        }
    }

    func toggleSave(token: String?) async {
        guard let token = token else { return }
        do {
            if isSaved {
                _ = try await api.unsaveCollection(collectionId: collectionId, token: token)
                isSaved = false
            } else {
                _ = try await api.saveCollection(collectionId: collectionId, token: token)
                isSaved = true
            }
        } catch { }
    }

    func toggleSpotSave(spotId: String, token: String) async {
        do {
            let response = try await api.toggleSaveSpot(spotId: spotId, token: token)
            if response.saved {
                savedSpotIds.insert(spotId)
            } else {
                savedSpotIds.remove(spotId)
            }
            if let idx = spotItems.firstIndex(where: { $0.id == spotId }) {
                var updated = spotItems[idx]
                updated.saveCount = response.saveCount
                spotItems[idx] = updated
            }
            if let idx = collectionItems.firstIndex(where: { if case .spot(let s) = $0 { return s.id == spotId }; return false }) {
                if case .spot(var s) = collectionItems[idx] {
                    s.saveCount = response.saveCount
                    collectionItems[idx] = .spot(s)
                }
            }
        } catch { }
    }

    /// Remove an item from the collection (owner only). Refreshes the list after success.
    func removeItem(itemId: String, token: String?) async {
        guard let token = token, !token.isEmpty else { return }
        do {
            _ = try await api.removeItemFromCollection(collectionId: collectionId, itemId: itemId, token: token)
            collectionItems.removeAll { item in
                switch item {
                case .spot(let s): return s.id == itemId
                case .event(let e): return e.id == itemId
                }
            }
            spotItems = collectionItems.compactMap { if case .spot(let s) = $0 { return s }; return nil }
        } catch { }
    }
}

@MainActor
class MyCollectionsViewModel: ObservableObject {
    @Published var collections: [CollectionData] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let api = APIService.shared

    func load(token: String) async {
        guard !token.isEmpty else { return }
        isLoading = true
        error = nil
        do {
            let response = try await api.getCollections(token: token)
            collections = response.data
        } catch let err {
            error = err
        }
        isLoading = false
    }
}

#Preview {
    ProfileView()
        .environmentObject(AuthManager())
}
